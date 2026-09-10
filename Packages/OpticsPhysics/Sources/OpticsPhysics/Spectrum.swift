import Foundation
import simd

/// Spectral sampling machinery: CIE 1931 2° color matching functions,
/// D65 illuminant, and conversion of a spectral power distribution to linear sRGB.
public enum Spectrum {

    public static let lambdaMin: Float = 380
    public static let lambdaMax: Float = 780
    public static let step: Float = 5
    public static let sampleCount = 81

    /// CIE 1931 2° standard observer, 380..780 nm in 5 nm steps.
    static let cmfX: [Float] = [
        0.0014, 0.0022, 0.0042, 0.0076, 0.0143, 0.0232, 0.0435, 0.0776, 0.1344, 0.2148,
        0.2839, 0.3285, 0.3483, 0.3481, 0.3362, 0.3187, 0.2908, 0.2511, 0.1954, 0.1421,
        0.0956, 0.0580, 0.0320, 0.0147, 0.0049, 0.0024, 0.0093, 0.0291, 0.0633, 0.1096,
        0.1655, 0.2257, 0.2904, 0.3597, 0.4334, 0.5121, 0.5945, 0.6784, 0.7621, 0.8425,
        0.9163, 0.9786, 1.0263, 1.0567, 1.0622, 1.0456, 1.0026, 0.9384, 0.8544, 0.7514,
        0.6424, 0.5419, 0.4479, 0.3608, 0.2835, 0.2187, 0.1649, 0.1212, 0.0874, 0.0636,
        0.0468, 0.0329, 0.0227, 0.0158, 0.0114, 0.0081, 0.0058, 0.0041, 0.0029, 0.0020,
        0.0014, 0.0010, 0.0007, 0.0005, 0.0003, 0.0002, 0.0002, 0.0001, 0.0001, 0.0001,
        0.0000,
    ]

    static let cmfY: [Float] = [
        0.0000, 0.0001, 0.0001, 0.0002, 0.0004, 0.0006, 0.0012, 0.0022, 0.0040, 0.0073,
        0.0116, 0.0168, 0.0230, 0.0298, 0.0380, 0.0480, 0.0600, 0.0739, 0.0910, 0.1126,
        0.1390, 0.1693, 0.2080, 0.2586, 0.3230, 0.4073, 0.5030, 0.6082, 0.7100, 0.7932,
        0.8620, 0.9149, 0.9540, 0.9803, 0.9950, 0.9980, 0.9950, 0.9786, 0.9520, 0.9154,
        0.8700, 0.8163, 0.7570, 0.6949, 0.6310, 0.5668, 0.5030, 0.4412, 0.3810, 0.3210,
        0.2650, 0.2170, 0.1750, 0.1382, 0.1070, 0.0816, 0.0610, 0.0446, 0.0320, 0.0232,
        0.0170, 0.0119, 0.0082, 0.0057, 0.0041, 0.0029, 0.0021, 0.0015, 0.0010, 0.0007,
        0.0005, 0.0004, 0.0002, 0.0002, 0.0001, 0.0001, 0.0001, 0.0000, 0.0000, 0.0000,
        0.0000,
    ]

    static let cmfZ: [Float] = [
        0.0065, 0.0105, 0.0201, 0.0362, 0.0679, 0.1102, 0.2074, 0.3713, 0.6456, 1.0391,
        1.3856, 1.6230, 1.7471, 1.7826, 1.7721, 1.7441, 1.6692, 1.5281, 1.2876, 1.0419,
        0.8130, 0.6162, 0.4652, 0.3533, 0.2720, 0.2123, 0.1582, 0.1117, 0.0782, 0.0573,
        0.0422, 0.0298, 0.0203, 0.0134, 0.0087, 0.0058, 0.0039, 0.0027, 0.0021, 0.0018,
        0.0017, 0.0014, 0.0011, 0.0010, 0.0008, 0.0006, 0.0003, 0.0002, 0.0002, 0.0001,
        0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000,
        0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000,
        0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000, 0.0000,
        0.0000,
    ]

    /// D65 relative spectral power distribution, 380..780 nm in 5 nm steps
    /// (peak-normalized at 560 nm; values follow the CIE 15 table).
    static let d65: [Float] = [
        49.9755, 52.3118, 54.6940, 58.0296, 63.5910, 71.0440, 82.7549, 87.1204, 93.4316, 97.9136,
        101.2991, 104.8584, 105.8229, 105.0295, 104.3895, 104.7312, 105.2533, 105.7214, 105.3264, 103.4631,
        101.9152, 99.1872, 96.1633, 95.6259, 96.6188, 98.6261, 100.4648, 101.9142, 102.0982, 101.5788,
        101.1941, 101.9086, 103.2891, 103.0208, 101.0953, 97.5904, 94.1094, 90.8963, 89.4923, 89.8018,
        87.4293, 85.8500, 84.6250, 83.0450, 80.9200, 79.9200, 77.9800, 76.3000, 74.7000, 73.8000,
        72.5700, 71.0000, 69.6600, 68.3400, 67.1100, 65.8600, 64.8500, 63.7600, 62.6200, 61.5400,
        60.5000, 59.4700, 58.4600, 57.4900, 56.5000, 55.5800, 54.6600, 53.7900, 52.9000, 52.0900,
        51.3000, 50.5300, 49.8000, 49.1100, 48.4500, 47.8200, 47.2100, 46.6300, 46.0600, 45.5200,
        45.0000,
    ]

    /// Normalization: Y tristimulus value of the D65 illuminant itself,
    /// so a perfectly reflecting surface integrates to (1, 1, 1).
    static let d65YNorm: Float = {
        var sum: Float = 0
        for i in 0..<sampleCount {
            sum += d65[i] * cmfY[i]
        }
        return sum
    }()

    /// XYZ (D65) to linear sRGB.
    static let xyzToLinearRGB = simd_float3x3(
        SIMD3( 3.2406, -0.9689,  0.0557),
        SIMD3(-1.5372,  1.8758, -0.2040),
        SIMD3(-0.4986,  0.0415,  1.0570)
    )

    /// Tristimulus of the illuminant itself, in linear sRGB coordinates.
    /// Used to normalize the pipeline so a flat reflectance maps exactly to white,
    /// absorbing small deviations of the embedded CMF/D65 tables.
    static let whiteLinearRGB: SIMD3<Float> = {
        var X: Float = 0, Y: Float = 0, Z: Float = 0
        for i in 0..<sampleCount {
            X += d65[i] * cmfX[i]
            Y += d65[i] * cmfY[i]
            Z += d65[i] * cmfZ[i]
        }
        return (xyzToLinearRGB * SIMD3(X, Y, Z)) / d65YNorm
    }()

    /// Integrate a reflectance spectrum (sampled every 5 nm from 380 to 780)
    /// against the D65 illuminant and the CIE observer, returning linear sRGB.
    /// Values may slightly exceed [0,1] where the spectrum is spiky; callers clamp as needed.
    public static func rgb(samples: [Float]) -> SIMD3<Float> {
        precondition(samples.count == sampleCount)
        var X: Float = 0, Y: Float = 0, Z: Float = 0
        for i in 0..<sampleCount {
            let s = samples[i] * d65[i]
            X += s * cmfX[i]
            Y += s * cmfY[i]
            Z += s * cmfZ[i]
        }
        let scale = 1.0 / d65YNorm
        let lin = xyzToLinearRGB * SIMD3(X, Y, Z) * scale
        return lin / whiteLinearRGB
    }

    /// Wavelength (nm) of sample index i.
    @inlinable
    public static func wavelength(_ i: Int) -> Float {
        lambdaMin + Float(i) * step
    }

    /// Sample index closest to a wavelength; out-of-range wavelengths clamp to the ends.
    @inlinable
    public static func index(of nm: Float) -> Int {
        min(max(Int((nm - lambdaMin) / step), 0), sampleCount - 1)
    }

    /// Reflectance spectrum of a narrow Gaussian band around `nm` (FWHM-like width in nm),
    /// normalized to peak 1. Used to turn single-wavelength predictions into sampleable spectra.
    public static func bandSamples(nm: Float, width: Float) -> [Float] {
        var out = [Float](repeating: 0, count: sampleCount)
        let sigma = max(width * 0.4247, 0.75) // FWHM -> sigma, with a floor
        let inv2s2 = 1.0 / (2.0 * sigma * sigma)
        for i in 0..<sampleCount {
            let dl = wavelength(i) - nm
            out[i] = exp(-dl * dl * inv2s2)
        }
        return out
    }
}
