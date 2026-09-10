import Foundation
import simd

/// Parameters of a three-medium thin film: exterior (1) / film (2) / substrate (3).
/// A soap bubble is air / soap solution / air; an oil slick on water is air / oil / water.
public struct ThinFilmConfig {
    public var n1: Float = 1.0      // exterior index (air)
    public var n2: Float = 1.333    // film index (soap solution)
    public var n3: Float = 1.0      // substrate index (air => free-standing film)
    /// Standard deviation (nm) of film thickness across one LUT texel / pixel,
    /// used to anti-alias the interference fringes (Belcour & Barla 2017 idea).
    public var sigmaD: Float = 15

    public init(n1: Float = 1.0, n2: Float = 1.333, n3: Float = 1.0, sigmaD: Float = 15) {
        self.n1 = n1
        self.n2 = n2
        self.n3 = n3
        self.sigmaD = sigmaD
    }
}

/// Angle-dependent part of the thin-film solution: computed once per view angle,
/// then evaluated cheaply for every (thickness, wavelength) pair.
public struct ThinFilmAngles {
    let cos1: Float      // cos of incidence angle in medium 1
    let cos2: Float      // cos of refraction angle inside the film
    let r12s: Float      // amplitude reflectance, medium1->film, s polarization
    let r12p: Float      // ... p polarization
    let r23s: Float      // amplitude reflectance, film->medium3, s polarization
    let r23p: Float      // ... p polarization
    let sigmaD: Float

    public init(cosTheta: Float, config: ThinFilmConfig) {
        let c1 = min(max(cosTheta, 0.0), 0.9999)
        let s1 = sqrt(1 - c1 * c1)
        let sin2 = config.n1 / config.n2 * s1
        let c2 = sqrt(max(0, 1 - sin2 * sin2))
        cos1 = c1
        cos2 = c2
        sigmaD = config.sigmaD

        // Snell for the film->substrate interface
        let sin3 = config.n2 / config.n3 * sin2
        let c3 = sqrt(max(0, 1 - sin3 * sin3))

        // Fresnel amplitude coefficients (signed; signs encode the pi phase flips)
        r12s = (config.n1 * c1 - config.n2 * c2) / (config.n1 * c1 + config.n2 * c2)
        r12p = (config.n2 * c1 - config.n1 * c2) / (config.n2 * c1 + config.n1 * c2)
        r23s = (config.n2 * c2 - config.n3 * c3) / (config.n2 * c2 + config.n3 * c3)
        r23p = (config.n3 * c2 - config.n2 * c3) / (config.n3 * c2 + config.n2 * c3)
    }

    /// Reflectance [0,1] of the film at one wavelength.
    /// `d` in nm, `lambda` in nm. Airy summation with the two dominant beams,
    /// averaged over s/p polarization.
    func reflectance(d: Float, lambda: Float, n2: Float) -> Float {
        // Optical path difference phase: delta = 4*pi*n2*d*cos(theta2)/lambda
        let delta = 4.0 * Float.pi * n2 * d * cos2 / lambda
        let c = cos(delta)
        let s = sin(delta)

        var rs: Float = 0
        var rp: Float = 0
        // |(r12 + r23 e^{-i delta}) / (1 + r12 r23 e^{-i delta})|^2, expanded to real arithmetic
        do {
            let a = r12s, b = r23s
            let nRe = a + b * c
            let nIm = -b * s
            let dRe = 1 + a * b * c
            let dIm = a * b * s
            let n2 = nRe * nRe + nIm * nIm
            let d2 = dRe * dRe + dIm * dIm
            rs = d2 > 0 ? n2 / d2 : 0
        }
        do {
            let a = r12p, b = r23p
            let nRe = a + b * c
            let nIm = -b * s
            let dRe = 1 + a * b * c
            let dIm = a * b * s
            let n2 = nRe * nRe + nIm * nIm
            let d2 = dRe * dRe + dIm * dIm
            rp = d2 > 0 ? n2 / d2 : 0
        }
        return 0.5 * (rs + rp)
    }
}

public enum ThinFilm {

    /// Fill `samples` (81 entries, 380..780 nm) with the reflectance spectrum of the film
    /// for thickness `d` nm viewed at `angles`. Averages over a Gaussian thickness
    /// distribution with the configured sigma to smooth pixel-scale fringe aliasing.
    public static func reflectanceSpectrum(
        d: Float,
        angles: ThinFilmAngles,
        n2: Float,
        into samples: inout [Float]
    ) {
        let sigma = angles.sigmaD
        // 5-node Gaussian quadrature offsets/weights (half-width 2 sigma)
        let offsets: [Float] = [-2.0, -1.0, 0.0, 1.0, 2.0]
        let weights: [Float] = [0.0703, 0.2417, 0.3760, 0.2417, 0.0703]
        for i in 0..<Spectrum.sampleCount {
            let lambda = Spectrum.wavelength(i)
            var acc: Float = 0
            var wsum: Float = 0
            for k in 0..<offsets.count {
                let dd = max(d + offsets[k] * sigma, 0)
                acc += weights[k] * angles.reflectance(d: dd, lambda: lambda, n2: n2)
                wsum += weights[k]
            }
            samples[i] = acc / wsum
        }
    }

    /// Convenience: linear sRGB color of the film at (thickness, cosTheta).
    public static func rgb(d: Float, cosTheta: Float, config: ThinFilmConfig) -> SIMD3<Float> {
        let angles = ThinFilmAngles(cosTheta: cosTheta, config: config)
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        reflectanceSpectrum(d: d, angles: angles, n2: config.n2, into: &samples)
        return Spectrum.rgb(samples: samples)
    }
}
