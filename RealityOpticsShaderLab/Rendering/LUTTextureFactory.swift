import RealityKit
import Metal
import OpticsPhysics

/// One immutable RGBA16F lookup, produced on the GPU and shared by material instances.
@MainActor
final class LUTTexture {
    let lowLevelTexture: LowLevelTexture
    let resource: TextureResource
    let width: Int
    let height: Int

    init(width: Int, height: Int) throws {
        var descriptor = LowLevelTexture.Descriptor()
        descriptor.textureType = .type2D
        descriptor.arrayLength = 1
        descriptor.width = width
        descriptor.height = height
        descriptor.depth = 1
        descriptor.mipmapLevelCount = 1
        descriptor.pixelFormat = .rgba16Float
        descriptor.textureUsage = [.shaderRead, .shaderWrite]
        self.lowLevelTexture = try LowLevelTexture(descriptor: descriptor)
        self.width = width
        self.height = height
        self.resource = try TextureResource(from: lowLevelTexture)
    }
}

/// A single device/queue/pipeline for all LUTs. No CPU readback during normal use.
@MainActor
final class LUTRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let spectralConstants: MTLBuffer
    private let weights: MTLBuffer
    private let pipeline: MTLComputePipelineState?

    init() async throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let weights = device.makeBuffer(bytes: Spectrum.packedHalfRGBWeights,
                length: Spectrum.packedHalfRGBWeights.count * 2, options: .storageModeShared),
              let spectralConstants = device.makeBuffer(bytes: SpatialLookup.gpuSpectralConstants,
                length: SpatialLookup.gpuSpectralConstants.count * MemoryLayout<SIMD4<Float>>.stride,
                options: .storageModeShared) else {
            throw Self.failure("Metal unavailable")
        }
        self.device = device
        self.queue = queue
        self.weights = weights
        self.spectralConstants = spectralConstants
        if let function = device.makeDefaultLibrary()?.makeFunction(name: "buildOpticsLUT") {
            do {
                // Pipeline compilation may be slow on its first use; don't block UI.
                self.pipeline = try await withCheckedThrowingContinuation { continuation in
                    device.makeComputePipelineState(function: function) { state, error in
                        if let state { continuation.resume(returning: state) }
                        else { continuation.resume(throwing: error ?? Self.failure("Compute pipeline unavailable")) }
                    }
                }
            } catch {
                print("OPTICS_PERF CPU fallback: \(error.localizedDescription)")
                self.pipeline = nil
            }
        } else {
            print("OPTICS_PERF CPU fallback: buildOpticsLUT missing")
            self.pipeline = nil
        }
    }

    func make(_ key: OpticsLUT) async throws -> LUTTexture {
        let start = ContinuousClock.now
        let result = try LUTTexture(width: key.width, height: key.height)
        if let pipeline {
            guard let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder() else {
                throw Self.failure("Could not encode LUT compute")
            }
            command.label = "Optics LUT \(key)"
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(result.lowLevelTexture.replace(using: command), index: 0)
            encoder.setBuffer(weights, offset: 0, index: 0)
            encoder.setBuffer(spectralConstants, offset: 0, index: 2)
            var parameters = key.gpuParameters
            encoder.setBytes(&parameters, length: MemoryLayout<OpticsGPUParameters>.stride, index: 1)
            let w = pipeline.threadExecutionWidth
            let h = min(key.height, min(8, pipeline.maxTotalThreadsPerThreadgroup / w))
            // Some simulator devices don't support non-uniform dispatchThreads.
            // Round up to complete groups; the kernel rejects out-of-bounds threads.
            encoder.dispatchThreadgroups(
                MTLSize(width: (key.width + w - 1) / w, height: (key.height + h - 1) / h, depth: 1),
                threadsPerThreadgroup: MTLSize(width: w, height: h, depth: 1))
            encoder.endEncoding()
            try await Self.complete(command)
            print("OPTICS_PERF LUT GPU \(key): \(start.duration(to: .now))")
        } else {
            let pixels = await Task.detached(priority: .userInitiated) { key.referencePixels() }.value
            try await upload(pixels, into: result)
            print("OPTICS_PERF LUT CPU \(key): \(start.duration(to: .now))")
        }
        return result
    }

    private func upload(_ pixels: [UInt16], into target: LUTTexture) async throws {
        let row = target.width * 4
        let height = target.height
        let flipped = await Task.detached(priority: .userInitiated) {
            var result = [UInt16](repeating: 0, count: pixels.count)
            for y in 0..<height {
                result.replaceSubrange(y * row..<(y + 1) * row,
                    with: pixels[(height - 1 - y) * row..<(height - y) * row])
            }
            return result
        }.value
        guard let command = queue.makeCommandBuffer(),
              let staging = device.makeBuffer(bytes: flipped, length: flipped.count * 2, options: .storageModeShared),
              let blit = command.makeBlitCommandEncoder() else { throw Self.failure("Could not encode LUT upload") }
        blit.copy(from: staging, sourceOffset: 0, sourceBytesPerRow: target.width * 8,
            sourceBytesPerImage: target.width * target.height * 8,
            sourceSize: MTLSize(width: target.width, height: target.height, depth: 1),
            to: target.lowLevelTexture.replace(using: command), destinationSlice: 0, destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blit.endEncoding()
        try await Self.complete(command)
    }

    private static func complete(_ command: MTLCommandBuffer) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            command.addCompletedHandler { completed in
                if completed.status == .completed { continuation.resume() }
                else { continuation.resume(throwing: completed.error ?? failure("GPU LUT generation failed")) }
            }
            command.commit()
        }
    }

    nonisolated private static func failure(_ message: String) -> NSError {
        NSError(domain: "OpticsLUT", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
