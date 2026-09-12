import Foundation
import simd

/// Immutable procedural assets and angular optical tables. No camera is baked in.
public enum SpatialLookup: UInt32, CaseIterable, Sendable {
    case environment = 10, views, nebula, rainbow, atmosphere

    public var width: Int {
        switch self { case .views, .nebula: return 512; case .rainbow: return 1024; default: return 256 }
    }
    public var height: Int {
        switch self { case .environment: return 128; case .views, .nebula: return 512; case .rainbow: return 64; case .atmosphere: return 256 }
    }
    /// Stationary deviation of a water droplet with one or two internal reflections.
    public static func rainbowAngle(wavelength: Float, order: Int) -> Float {
        let micron = wavelength * 0.001
        let n: Float = 1.322 + 0.003 / (micron * micron)
        let k = Float(order)
        let incidence = acos(sqrt((n * n - 1) / (k * (k + 2))))
        let refraction = asin(sin(incidence) / n)
        let deviation = k * .pi + 2 * incidence - 2 * (k + 1) * refraction
        return abs(.pi - deviation)
    }
    /// Wavelength-only terms are computed once, shared by all LUT texels.
    /// Float4 layout matches Metal buffer(2): primary angle, secondary angle,
    /// Rayleigh coefficient, reserved. Keep optical constants at float32.
    public static let gpuSpectralConstants: [SIMD4<Float>] = (0..<Spectrum.sampleCount).map { index in
        let wavelength = Spectrum.lambdaMin + Float(index) * Spectrum.step
        return SIMD4(rainbowAngle(wavelength: wavelength, order: 1),
                     rainbowAngle(wavelength: wavelength, order: 2),
                     0.06 * pow(550 / wavelength, 4), 0)
    }

    public func spectrum(u: Float, v: Float, wavelength: Float) -> Float {
        if self == .rainbow {
            let angle = u * .pi
            let sigma = (0.2 + 1.2 * v) * .pi / 180
            let primary = (angle - Self.rainbowAngle(wavelength: wavelength, order: 1)) / sigma
            let secondary = (angle - Self.rainbowAngle(wavelength: wavelength, order: 2)) / (sigma * 1.3)
            return exp(-0.5 * primary * primary) + 0.38 * exp(-0.5 * secondary * secondary)
        }
        let mu = 2 * u - 1
        let beta = 0.06 * pow(550 / wavelength, 4)
        let sunPath = 1 / (0.04 + max(mu, 0))
        return (1 - exp(-beta * v * 10)) * exp(-beta * sunPath) * exp(min(mu, 0) * 16)
    }
    /// CPU fallback. Procedural patterns intentionally use smooth functions, not
    /// unstable sine hashes, so half-precision storage preserves atlas seams.
    public func color(u: Float, v: Float) -> SIMD3<Float> {
        func palette(_ t: Float) -> SIMD3<Float> {
            SIMD3(0.52 + 0.48 * cos(t), 0.52 + 0.48 * cos(t + 2.1), 0.52 + 0.48 * cos(t + 4.2))
        }
        if self == .environment {
            let a = 2 * Float.pi * u
            let bands = pow(0.5 + 0.5 * cos(6 * a + 2 * sin(v * 8)), 12)
            let lights = pow(0.5 + 0.5 * cos(3 * a - 1), 40) * exp(-pow((v - 0.7) * 7, 2))
            return SIMD3(repeating: 0.03 + 1.8 * lights + 0.8 * pow(bands, 3)) + palette(a + v * 5) * (0.06 + 0.4 * bands)
        }
        let tx = min(Int(u * 2), 1), ty = min(Int(v * 2), 1)
        let tile = Float(tx + 2 * ty)
        let x = (u * 2 - Float(tx)) * 2 - 1
        let y = (v * 2 - Float(ty)) * 2 - 1
        if self == .views {
            let r = sqrt(x*x + y*y)
            let angle = atan2(y, x)
            let pattern: Float
            switch Int(tile) {
            case 0: pattern = cos(r * 18)
            case 1: pattern = cos(5 * angle + r * 9)
            case 2: pattern = cos(x * 13) * cos(y * 13)
            default: pattern = cos(8 * angle - r * 14)
            }
            return palette(tile * 1.5 + r * 3) * (0.18 + 0.82 * pow(0.5 + 0.5 * pattern, 2))
        }
        let warp = sin(x * 4 + tile) + cos(y * 5 - tile)
        let field = sin(x * 6 + warp + tile * 2) * cos(y * 7 - warp)
        let fine = sin(x * 19 + y * 11 + tile) * cos(y * 23 - x * 9)
        let cloud = pow(max(0, 0.38 + 0.42 * field + 0.20 * fine), 3)
        let stars = pow(max(0, sin(x * 49 + tile) * cos(y * 53 - tile)), 70)
        let t = 0.5 + 0.5 * sin(tile * 1.6 + field * 2 + x)
        let tint = SIMD3<Float>(0.12, 0.04, 0.65) * (1-t) + SIMD3<Float>(0.7, 0.03, 0.24) * t
            + SIMD3<Float>(0.03, 0.22, 0.22) * max(field, 0)
        return tint * cloud + SIMD3(repeating: stars * 0.8)
    }
    public func pixels() -> [UInt16] {
        var result = [UInt16](repeating: 0, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            let u = (Float(x) + 0.5) / Float(width), v = (Float(y) + 0.5) / Float(height)
            var rgb = SIMD3<Float>(repeating: 0)
            if self == .rainbow {
                let angle = u * Float.pi
                let inverseSigma = 1 / ((0.2 + 1.2 * v) * Float.pi / 180)
                for i in 0..<Spectrum.sampleCount {
                    let constants = Self.gpuSpectralConstants[i]
                    let a = (angle - constants.x) * inverseSigma
                    let b = (angle - constants.y) * (inverseSigma / 1.3)
                    let value = exp(-0.5 * a * a) + 0.38 * exp(-0.5 * b * b)
                    rgb += Spectrum.rgbWeights[i] * value
                }
            } else if self == .atmosphere {
                let mu = 2 * u - 1
                let sunPath = 1 / (0.04 + max(mu, 0))
                let day = exp(min(mu, 0) * 16)
                let depth = v * 10
                for i in 0..<Spectrum.sampleCount {
                    let beta = Self.gpuSpectralConstants[i].z
                    let value = (1 - exp(-beta * depth)) * exp(-beta * sunPath) * day
                    rgb += Spectrum.rgbWeights[i] * value
                }
            } else { rgb = color(u: u, v: v) }
            for c in 0..<3 { result[(y * width + x) * 4 + c] = Float16(max(0, min(4, rgb[c]))).bitPattern }
            result[(y * width + x) * 4 + 3] = Float16(1).bitPattern
        } }
        return result
    }
}
