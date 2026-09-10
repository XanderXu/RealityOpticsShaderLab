import Foundation

/// Builds the two physics lookup textures as RGBA16F byte buffers,
/// ready to upload through RealityKit's LowLevelTexture.
public enum LUTBuilder {

    // MARK: - Axis conventions

    /// Film LUT: U axis = cos(view, normal) in [0,1]; V axis = thickness in [0, thicknessMax] nm.
    public static let filmThicknessMax: Float = 1200

    public static func filmThickness(v: Float) -> Float { v * filmThicknessMax }
    public static func filmV(thickness: Float) -> Float { thickness / filmThicknessMax }

    /// Grating LUT: U axis = (sinIn - sinOut + 2) / 4; V axis = groove density in [300, 2000] lines/mm.
    public static let gratingMinLpm: Float = 300
    public static let gratingMaxLpm: Float = 2000

    public static func gratingLinesPerMm(v: Float) -> Float {
        gratingMinLpm + v * (gratingMaxLpm - gratingMinLpm)
    }
    public static func gratingV(linesPerMm: Float) -> Float {
        (linesPerMm - gratingMinLpm) / (gratingMaxLpm - gratingMinLpm)
    }

    // MARK: - Film LUT

    /// RGBA16F texture, row-major from v=0 (bottom) upward.
    public static func filmLUT(
        width: Int = 256,
        height: Int = 256,
        config: ThinFilmConfig = ThinFilmConfig()
    ) -> [UInt16] {
        var out = [UInt16](repeating: 0, count: width * height * 4)
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        for y in 0..<height {
            let v = (Float(y) + 0.5) / Float(height)
            let d = filmThickness(v: v)
            for x in 0..<width {
                let u = (Float(x) + 0.5) / Float(width)
                let cosTheta = u // axis U == cos view angle, clamped inside ThinFilmAngles
                let a = ThinFilmAngles(cosTheta: cosTheta, config: config)
                ThinFilm.reflectanceSpectrum(d: d, angles: a, n2: config.n2, into: &samples)
                let rgb = Spectrum.rgb(samples: samples)
                let base = (y * width + x) * 4
                out[base + 0] = floatToHalf(clampForTexture(rgb.x))
                out[base + 1] = floatToHalf(clampForTexture(rgb.y))
                out[base + 2] = floatToHalf(clampForTexture(rgb.z))
                out[base + 3] = 0x3C00 // 1.0
            }
        }
        return out
    }

    // MARK: - Grating LUT

    /// Mother-of-pearl: averages three commensurate platelet film layers
    /// (golden-ratio thickness offsets) with a large thickness variance
    /// (platelet orientation spread), then desaturates toward soft pastels.
    public static func nacreLUT(
        width: Int = 256,
        height: Int = 256,
        config: ThinFilmConfig = ThinFilmConfig(n2: 1.55, sigmaD: 45)
    ) -> [UInt16] {
        var out = [UInt16](repeating: 0, count: width * height * 4)
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        var layer = [Float](repeating: 0, count: Spectrum.sampleCount)
        for y in 0..<height {
            let v = (Float(y) + 0.5) / Float(height)
            let d = filmThickness(v: v)
            for x in 0..<width {
                let u = (Float(x) + 0.5) / Float(width)
                let angles = ThinFilmAngles(cosTheta: u, config: config)
                var acc = SIMD3<Float>(0, 0, 0)
                for (i, scale) in [Float(1.0), 1.618, 0.618].enumerated() {
                    let dd = max(d * scale + Float(i) * 80, 0)
                    ThinFilm.reflectanceSpectrum(d: dd, angles: angles, n2: config.n2, into: &layer)
                    acc += Spectrum.rgb(samples: layer) / 3.0
                }
                let rgb = desaturate(acc, amount: 0.45)
                let base = (y * width + x) * 4
                out[base + 0] = floatToHalf(clampForTexture(rgb.x))
                out[base + 1] = floatToHalf(clampForTexture(rgb.y))
                out[base + 2] = floatToHalf(clampForTexture(rgb.z))
                out[base + 3] = 0x3C00
            }
        }
        return out
    }

    /// Linear-light luma mix toward gray.
    static func desaturate(_ c: SIMD3<Float>, amount: Float) -> SIMD3<Float> {
        let luma = c.x * 0.2126 + c.y * 0.7152 + c.z * 0.0722
        let gray = SIMD3<Float>(repeating: luma)
        return c * (1 - amount) + gray * amount
    }

    /// Axis helper for LUTs indexed by a phase in [0, 2π].
    public static func birefringenceDelta(u: Float) -> Float { u * 2 * .pi }
    public static func birefringenceU(delta: Float) -> Float { delta / (2 * .pi) }

    /// Photoelasticity: transmission through crossed polarizers for a
    /// retarder of phase delta (radians, referenced to 550 nm):
    /// T(lambda) = sin^2(delta * lambdaRef / (2 lambda)).
    /// U axis = delta / 2pi in [0, 1]; V is unused (8 rows).
    public static func birefringenceLUT(width: Int = 512) -> [UInt16] {
        let height = 8
        var out = [UInt16](repeating: 0, count: width * height * 4)
        let lambdaRef: Float = 550
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        for x in 0..<width {
            let u = (Float(x) + 0.5) / Float(width)
            let delta = birefringenceDelta(u: u)
            for i in 0..<Spectrum.sampleCount {
                let lambda = Spectrum.wavelength(i)
                let t = sin(delta * lambdaRef / (2 * lambda))
                samples[i] = t * t
            }
            let rgb = Spectrum.rgb(samples: samples)
            for y in 0..<height {
                let base = (y * width + x) * 4
                out[base + 0] = floatToHalf(clampForTexture(rgb.x))
                out[base + 1] = floatToHalf(clampForTexture(rgb.y))
                out[base + 2] = floatToHalf(clampForTexture(rgb.z))
                out[base + 3] = 0x3C00
            }
        }
        return out
    }

    /// RGBA16F texture, row-major from v=0 (bottom) upward.
    public static func gratingLUT(
        width: Int = 256,
        height: Int = 128,
        maxOrder: Int = 2
    ) -> [UInt16] {
        var out = [UInt16](repeating: 0, count: width * height * 4)
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        for y in 0..<height {
            let v = (Float(y) + 0.5) / Float(height)
            let lpm = gratingLinesPerMm(v: v)
            for x in 0..<width {
                let u = (Float(x) + 0.5) / Float(width)
                let delta = (u * 4 - 2) // sinIn - sinOut
                DiffractionGrating.spectrum(
                    sinIn: max(delta, 0), sinOut: max(-delta, 0),
                    linesPerMm: lpm, maxOrder: maxOrder, into: &samples
                )
                let rgb = Spectrum.rgb(samples: samples)
                let base = (y * width + x) * 4
                out[base + 0] = floatToHalf(clampForTexture(rgb.x))
                out[base + 1] = floatToHalf(clampForTexture(rgb.y))
                out[base + 2] = floatToHalf(clampForTexture(rgb.z))
                out[base + 3] = 0x3C00 // 1.0
            }
        }
        return out
    }

    // MARK: - Helpers

    /// Keep small positive HDR headroom, drop negative lobes from the CMF matrix.
    @inlinable
    static func clampForTexture(_ x: Float) -> Float {
        min(max(x, 0), 4)
    }

    /// IEEE 754 binary16 conversion (round to nearest even).
    public static func floatToHalf(_ value: Float) -> UInt16 {
        var f = value
        let bits = withUnsafeBytes(of: &f) { $0.load(as: UInt32.self) }
        let sign = UInt16((bits >> 16) & 0x8000)
        let exponent = Int((bits >> 23) & 0xFF) - 127 + 15
        var mantissa = bits & 0x007F_FFFF

        if ((bits >> 23) & 0xFF) == 0xFF {
            // Inf / NaN
            return sign | 0x7C00 | (mantissa != 0 ? 1 : 0)
        }
        if exponent >= 0x1F {
            return sign | 0x7C00 // overflow -> inf
        }
        if exponent <= 0 {
            // Subnormal or zero
            if exponent < -10 { return sign }
            mantissa |= 0x0080_0000
            var half: UInt32 = 0
            let shift = UInt32(14 - exponent)
            half = mantissa >> shift
            // round to nearest even
            let roundBit = (mantissa >> (shift - 1)) & 1
            let sticky = (mantissa & ((1 << (shift - 1)) - 1)) != 0
            if roundBit == 1 && (sticky || half & 1 == 1) { half += 1 }
            return sign | UInt16(half)
        }
        var half = UInt32(exponent) << 10 | (mantissa >> 13)
        let roundBit = (mantissa >> 12) & 1
        let sticky = (mantissa & 0xFFF) != 0
        if roundBit == 1 && (sticky || half & 1 == 1) {
            half += 1
            if half & 0x7C00 == 0x7C00 { half = UInt32(exponent) << 10 | 0x3FF }
        }
        return sign | UInt16(half)
    }
}
