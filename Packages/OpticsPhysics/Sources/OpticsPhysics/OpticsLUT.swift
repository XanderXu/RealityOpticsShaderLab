import Foundation

/// Immutable lookup identity. Only the soap LUT depends on an interactive value.
public enum OpticsLUT: Hashable, Sendable {
    case layered(LayeredFilm)
    case film(ior: Float)
    case grating, nacre, birefringence, morpho, newton

    public var width: Int { self == .birefringence ? 1024 : 256 }
    public var height: Int {
        switch self {
        case .birefringence: return 1
        case .grating: return 128
        case .newton: return 512
        default: return 256
        }
    }
    public var byteCount: Int { width * height * 8 }
    public var isVariable: Bool { if case .film = self { return true }; return false }

    /// Matches the 16-byte Metal OpticsParameters layout.
    public var gpuParameters: OpticsGPUParameters {
        switch self {
        case .layered(let model): return .init(kind: model.rawValue, thicknessMax: model.domainSpan)
        case .film(let ior): return .init(kind: 0, ior: ior, sigma: 15)
        case .morpho: return .init(kind: 0, ior: 1.56, sigma: 30)
        case .nacre: return .init(kind: 1, ior: 1.55, sigma: 45)
        case .grating: return .init(kind: 2)
        case .birefringence: return .init(kind: 3)
        case .newton: return .init(kind: 4, thicknessMax: LUTBuilder.newtonThicknessMax)
        }
    }

    /// Independent CPU reference / fallback. The GPU path uses the same sizes
    /// and texel-center convention; no resolution or wavelength reduction.
    public func referencePixels() -> [UInt16] {
        switch self {
        case .layered(let model): return model.pixels(preserveSignedRGB: model == .dichroic)
        case .film(let ior): return LUTBuilder.filmLUT(config: .init(n2: ior, sigmaD: 15))
        case .grating: return LUTBuilder.gratingLUT()
        case .nacre: return LUTBuilder.nacreLUT()
        case .birefringence: return LUTBuilder.birefringenceLUT()
        case .morpho: return LUTBuilder.filmLUT(config: .init(n2: 1.56, sigmaD: 30))
        case .newton: return LUTBuilder.newtonLUT()
        }
    }
}

public struct OpticsGPUParameters: Sendable {
    public var kind: UInt32
    public var ior: Float
    public var sigma: Float
    public var thicknessMax: Float

    public init(kind: UInt32, ior: Float = 1, sigma: Float = 0, thicknessMax: Float = 1200) {
        self.kind = kind
        self.ior = ior
        self.sigma = sigma
        self.thicknessMax = thicknessMax
    }
}
