import RealityKit
import Metal
import OpticsPhysics

/// Owns one LowLevelTexture-backed TextureResource that can be refilled on the CPU,
/// so physics-generated LUTs can hot-swap without rebuilding materials.
@MainActor
final class LUTTexture {

    let lowLevelTexture: LowLevelTexture
    let resource: TextureResource
    let width: Int
    let height: Int

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

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
        descriptor.swizzle = .init(red: .red, green: .green, blue: .blue, alpha: .alpha)

        self.lowLevelTexture = try LowLevelTexture(descriptor: descriptor)
        self.width = width
        self.height = height
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            throw NSError(domain: "RealityOpticsShaderLab", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Metal unavailable"])
        }
        self.device = device
        self.commandQueue = commandQueue
        self.resource = try TextureResource(from: lowLevelTexture)
    }

    /// Replace the contents with new RGBA16F halves (width*height*4 entries).
    /// Uses the documented `replace(using:)` + blit-encoder path: writing the
    /// underlying MTLTexture directly from the CPU can deadlock against
    /// RealityKit's in-flight frames on the simulator.
    /// Row order is flipped here: MaterialX samples textures bottom-up while
    /// the byte buffer is written top-down, so V axes read as authored.
    func upload(halves: [UInt16]) throws {
        precondition(halves.count == width * height * 4)
        var flipped = [UInt16](repeating: 0, count: halves.count)
        let rowLen = width * 4
        for y in 0..<height {
            flipped.replaceSubrange(
                y * rowLen..<((y + 1) * rowLen),
                with: halves[(height - 1 - y) * rowLen..<(height - y) * rowLen]
            )
        }
        let byteCount = flipped.count * MemoryLayout<UInt16>.stride
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let staging = device.makeBuffer(bytes: flipped, length: byteCount, options: .storageModeShared),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw NSError(domain: "RealityOpticsShaderLab", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not encode LUT upload"])
        }
        let texture = lowLevelTexture.replace(using: commandBuffer)
        blit.copy(
            from: staging,
            sourceOffset: 0,
            sourceBytesPerRow: width * 8,
            sourceBytesPerImage: width * height * 8,
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else {
            throw commandBuffer.error ?? NSError(domain: "RealityOpticsShaderLab", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "GPU LUT upload failed"])
        }
    }
}

/// Builds physics LUTs off the main actor (pure CPU work) and hands bytes back.
enum LUTFactory {

    nonisolated static func makeFilmLUT(ior: Float) -> [UInt16] {
        let config = ThinFilmConfig(n1: 1.0, n2: ior, n3: 1.0, sigmaD: 15)
        return LUTBuilder.filmLUT(width: 256, height: 256, config: config)
    }

    nonisolated static func makeGratingLUT() -> [UInt16] {
        return LUTBuilder.gratingLUT(width: 256, height: 128, maxOrder: 2)
    }

    nonisolated static func makeNacreLUT() -> [UInt16] {
        return LUTBuilder.nacreLUT(width: 256, height: 256)
    }

    nonisolated static func makeBirefringenceLUT() -> [UInt16] {
        return LUTBuilder.birefringenceLUT(width: 1024)
    }

    nonisolated static func makeNewtonLUT() -> [UInt16] {
        LUTBuilder.newtonLUT(width: 256, height: 512)
    }

    nonisolated static func makeMorphoLUT() -> [UInt16] {
        // Chitin (n≈1.56), moderate ridge spread: wide-angle blue film.
        let config = ThinFilmConfig(n2: 1.56, sigmaD: 30)
        return LUTBuilder.filmLUT(width: 256, height: 256, config: config)
    }
}
