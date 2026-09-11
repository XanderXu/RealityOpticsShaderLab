import Foundation
import Metal

// Compiled with OpticsPhysics sources by verify_compute.py. This checks the same
// Metal kernel as the app against the independent CPU implementation, at full size.
@main
struct VerifyCompute {
    static func main() async throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw NSError(domain: "ComputeAudit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal unavailable"])
        }
        let source = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let options = MTLCompileOptions()
        options.mathMode = .fast
        let library = try await device.makeLibrary(source: source, options: options)
        let pipeline = try await device.makeComputePipelineState(function: library.makeFunction(name: "buildOpticsLUT")!)
        precondition(MemoryLayout<OpticsGPUParameters>.stride == 16)
        let weights = device.makeBuffer(bytes: Spectrum.packedHalfRGBWeights,
            length: Spectrum.packedHalfRGBWeights.count * 2, options: .storageModeShared)!
        let keys: [OpticsLUT] = [.film(ior: 1.333), .film(ior: 1.2), .film(ior: 1.45),
                                 .morpho, .nacre, .grating, .birefringence, .newton]
        // Odd dimensions exercise padded edge groups and the kernel's bounds check.
        let cases = keys.map { (key: $0, width: $0.width, height: $0.height) }
            + [(key: OpticsLUT.film(ior: 1.333), width: 257, height: 129)]
        var failed = false
        for (key, width, height) in cases {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                width: width, height: height, mipmapped: false)
            descriptor.storageMode = .shared
            descriptor.usage = [.shaderRead, .shaderWrite]
            let texture = device.makeTexture(descriptor: descriptor)!
            let command = queue.makeCommandBuffer()!
            let encoder = command.makeComputeCommandEncoder()!
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(texture, index: 0)
            encoder.setBuffer(weights, offset: 0, index: 0)
            var parameters = key.gpuParameters
            encoder.setBytes(&parameters, length: MemoryLayout<OpticsGPUParameters>.stride, index: 1)
            let w = pipeline.threadExecutionWidth
            let h = min(height, min(8, pipeline.maxTotalThreadsPerThreadgroup / w))
            encoder.dispatchThreadgroups(
                MTLSize(width: (width + w - 1) / w, height: (height + h - 1) / h, depth: 1),
                threadsPerThreadgroup: MTLSize(width: w, height: h, depth: 1))
            encoder.endEncoding()
            let gpuStart = ContinuousClock.now
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                command.addCompletedHandler {
                    if $0.status == .completed { continuation.resume() }
                    else { continuation.resume(throwing: $0.error!) }
                }
                command.commit()
            }
            let gpuTime = gpuStart.duration(to: .now)
            var raw = [UInt16](repeating: 0, count: width * height * 4)
            texture.getBytes(&raw, bytesPerRow: width * 8,
                from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            let cpuStart = ContinuousClock.now
            let cpu: [UInt16]
            if width == key.width && height == key.height {
                cpu = key.referencePixels()
            } else if case .film(let ior) = key {
                cpu = LUTBuilder.filmLUT(width: width, height: height, config: .init(n2: ior, sigmaD: 15))
            } else {
                fatalError("Missing reference for custom dimensions")
            }
            let cpuTime = cpuStart.duration(to: .now)
            var maxError: Float = 0, squared: Double = 0, count = 0
            for y in 0..<height {
                for x in 0..<width {
                    for c in 0..<4 {
                        let reference = Float(Float16(bitPattern: cpu[(y * width + x) * 4 + c]))
                        let actual = Float(Float16(bitPattern: raw[((height - 1 - y) * width + x) * 4 + c]))
                        guard actual.isFinite && actual >= 0 else { fatalError("Nonfinite/negative output: \(key)") }
                        if c == 3 { precondition(actual == 1); continue }
                        let error = abs(actual - reference)
                        maxError = max(maxError, error)
                        squared += Double(error * error)
                        count += 1
                    }
                }
            }
            let rmse = sqrt(squared / Double(count))
            let passed = maxError <= 0.003 && rmse <= 0.0002
            failed = failed || !passed
            print("\(passed ? "PASS" : "FAIL") \(key) \(width)x\(height): max=\(maxError), RMSE=\(rmse), CPU=\(cpuTime), GPU submission+wait=\(gpuTime)")
        }
        if failed { throw NSError(domain: "ComputeAudit", code: 2, userInfo: [NSLocalizedDescriptionKey: "GPU/CPU tolerance exceeded"]) }
        print("PASS all full-resolution LUTs and padded edge groups; half weights/storage, float optical arithmetic; verified vertical orientation")
    }
}
