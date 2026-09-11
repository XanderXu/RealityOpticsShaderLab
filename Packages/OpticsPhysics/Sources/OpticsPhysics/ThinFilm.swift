import Foundation
import simd

/// Lossless exterior (1) / film (2) / substrate (3), with thicknesses in nm.
public struct ThinFilmConfig {
    public var n1: Float
    public var n2: Float
    public var n3: Float
    /// Standard deviation of the subpixel thickness distribution, in nm.
    public var sigmaD: Float

    public init(n1: Float = 1, n2: Float = 1.333, n3: Float = 1, sigmaD: Float = 15) {
        precondition(n1.isFinite && n2.isFinite && n3.isFinite && n1 > 0 && n2 > 0 && n3 > 0)
        precondition(sigmaD.isFinite && sigmaD >= 0)
        self.n1 = n1
        self.n2 = n2
        self.n3 = n3
        self.sigmaD = sigmaD
    }
}

/// Fresnel coefficients depend only on angle and indices; cache them per LUT column.
public struct ThinFilmAngles {
    let cos2: Float
    let sigmaD: Float
    private let r12s: Float
    private let r12p: Float
    private let r23s: Float
    private let r23p: Float
    private let interfaceReflectance: Float
    private let evanescent: EvanescentFilm?

    public init(cosTheta: Float, config: ThinFilmConfig) {
        precondition(cosTheta.isFinite)
        let c1 = Double(min(max(cosTheta, 0), 1))
        let n1 = Double(config.n1), n2 = Double(config.n2), n3 = Double(config.n3)
        let tangential = n1 * sqrt(max(0, 1 - c1 * c1))
        let c2sq = 1 - pow(tangential / n2, 2)
        let c3sq = 1 - pow(tangential / n3, 2)
        let c2 = sqrt(max(0, c2sq)), c3 = sqrt(max(0, c3sq))
        func ratio(_ a: Double, _ b: Double) -> Float {
            a + b > 0 ? Float((a - b) / (a + b)) : 0
        }
        cos2 = Float(c2)
        sigmaD = config.sigmaD
        r12s = ratio(n1 * c1, n2 * c2)
        r12p = ratio(n2 * c1, n1 * c2)
        r23s = ratio(n2 * c2, n3 * c3)
        r23p = ratio(n3 * c2, n2 * c3)
        let rs = ratio(n1 * c1, n3 * c3), rp = ratio(n3 * c1, n1 * c3)
        interfaceReflectance = n1 == n3 ? 0 : (c3sq < 0 ? 1 : 0.5 * (rs * rs + rp * rp))
        // A clamped real cosine loses the phase of total internal reflection.
        // Retain complex Fresnel amplitudes only for this uncommon path.
        evanescent = c2sq < 0 || c3sq < 0
            ? EvanescentFilm(n1: n1, n2: n2, n3: n3, c1: c1, c2sq: c2sq, c3sq: c3sq)
            : nil
    }

    /// Full Airy multiple-reflection sum, averaged over s/p polarization.
    func reflectance(d: Float, lambda: Float, n2: Float) -> Float {
        if d <= 0 { return interfaceReflectance }
        if let evanescent { return evanescent.reflectance(d: Double(d), lambda: Double(lambda)) }
        // |a + b exp(iδ)|² / |1 + ab exp(iδ)|², written with sin²(δ/2).
        // This needs one trig call and avoids subtracting nearly equal terms at d≈0.
        let phase = 2 * Float.pi * n2 * d * cos2 / lambda
        let sinHalf = sin(phase)
        let sinSquared = sinHalf * sinHalf
        func airy(_ a: Float, _ b: Float) -> Float {
            let interference = -4 * a * b * sinSquared
            let numerator = (a + b) * (a + b) + interference
            let denominator = (1 + a * b) * (1 + a * b) + interference
            return denominator > 0 ? min(max(numerator / denominator, 0), 1) : interfaceReflectance
        }
        return 0.5 * (airy(r12s, r23s) + airy(r12p, r23p))
    }
}

/// Complex arithmetic is used only when a refracted wave is evanescent.
private struct FilmComplex {
    var re: Double
    var im: Double = 0
    var norm: Double { re * re + im * im }
    static func + (a: Self, b: Self) -> Self { Self(re: a.re + b.re, im: a.im + b.im) }
    static func - (a: Self, b: Self) -> Self { Self(re: a.re - b.re, im: a.im - b.im) }
    static func * (a: Self, b: Self) -> Self {
        Self(re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re)
    }
    static func / (a: Self, b: Self) -> Self {
        Self(re: (a.re * b.re + a.im * b.im) / b.norm,
             im: (a.im * b.re - a.re * b.im) / b.norm)
    }
    static func * (a: Double, b: Self) -> Self { Self(re: a * b.re, im: a * b.im) }
}

private struct EvanescentFilm {
    let n2: Double
    let c2: FilmComplex
    let rs: (FilmComplex, FilmComplex)
    let rp: (FilmComplex, FilmComplex)

    init(n1: Double, n2: Double, n3: Double, c1: Double, c2sq: Double, c3sq: Double) {
        func cosine(_ square: Double) -> FilmComplex {
            square >= 0 ? FilmComplex(re: sqrt(square)) : FilmComplex(re: 0, im: sqrt(-square))
        }
        let c1 = FilmComplex(re: c1), c2 = cosine(c2sq), c3 = cosine(c3sq)
        func fresnel(_ a: FilmComplex, _ b: FilmComplex) -> FilmComplex { (a - b) / (a + b) }
        self.n2 = n2
        self.c2 = c2
        rs = (fresnel(n1 * c1, n2 * c2), fresnel(n2 * c2, n3 * c3))
        rp = (fresnel(n2 * c1, n1 * c2), fresnel(n3 * c2, n2 * c3))
    }

    func reflectance(d: Double, lambda: Double) -> Float {
        let phase = 4 * Double.pi * n2 * d / lambda
        let attenuation = exp(-phase * c2.im)
        let e = FilmComplex(re: attenuation * cos(phase * c2.re), im: attenuation * sin(phase * c2.re))
        func airy(_ pair: (FilmComplex, FilmComplex)) -> Double {
            let (a, b) = pair
            let denominator = FilmComplex(re: 1) + a * b * e
            return denominator.norm > 0 ? ((a + b * e) / denominator).norm : 1
        }
        return Float(min(max(0.5 * (airy(rs) + airy(rp)), 0), 1))
    }
}

public enum ThinFilm {
    // Five-point Gauss–Hermite quadrature for a standard normal distribution.
    private static let offsets: [Float] = [-2.856970, -1.355626, 0, 1.355626, 2.856970]
    private static let weights: [Float] = [0.011257411, 0.222075922, 0.533333333, 0.222075922, 0.011257411]

    public static func reflectanceSpectrum(d: Float, angles: ThinFilmAngles, n2: Float, into samples: inout [Float]) {
        precondition(samples.count == Spectrum.sampleCount)
        precondition(d.isFinite && n2.isFinite && n2 > 0)
        if angles.sigmaD == 0 {
            for i in 0..<Spectrum.sampleCount {
                samples[i] = angles.reflectance(d: d, lambda: Spectrum.wavelength(i), n2: n2)
            }
            return
        }
        for i in 0..<Spectrum.sampleCount {
            let lambda = Spectrum.wavelength(i)
            var sum: Float = 0
            for k in offsets.indices {
                let thickness = max(d + offsets[k] * angles.sigmaD, 0)
                sum += weights[k] * angles.reflectance(d: thickness, lambda: lambda, n2: n2)
            }
            samples[i] = sum
        }
    }

    public static func rgb(d: Float, cosTheta: Float, config: ThinFilmConfig) -> SIMD3<Float> {
        let angles = ThinFilmAngles(cosTheta: cosTheta, config: config)
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        reflectanceSpectrum(d: d, angles: angles, n2: config.n2, into: &samples)
        return Spectrum.rgb(samples: samples)
    }
}
