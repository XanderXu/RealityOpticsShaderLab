import Foundation

/// Reflection diffraction grating model (CD / DVD surface).
/// Grating equation: sin(thetaOut) - sin(thetaIn) = -m * lambda / d,
/// i.e. a wavelength lambda is redirected to view when d * (sinIn - sinOut) = m * lambda.
public enum DiffractionGrating {

    /// Wavelength (nm) diffracted into the given geometry, for diffraction order m.
    /// Returns nil when no visible wavelength satisfies the equation.
    @inlinable
    public static func wavelength(
        sinIn: Float,
        sinOut: Float,
        groovePeriodNm d: Float,
        order m: Int
    ) -> Float? {
        precondition(m != 0)
        let lambda = d * (sinIn - sinOut) / Float(m)
        guard lambda >= Spectrum.lambdaMin && lambda <= Spectrum.lambdaMax else { return nil }
        return lambda
    }

    /// Groove period (nm) for a density in lines/mm (CD: 625 lines/mm => 1600 nm).
    @inlinable
    public static func periodNm(linesPerMm: Float) -> Float {
        precondition(linesPerMm > 0)
        return 1_000_000.0 / linesPerMm
    }

    /// Reflectance spectrum (81 samples) diffracted toward the viewer.
    /// `sinIn`/`sinOut` are the components of light/view directions along the
    /// in-plane axis perpendicular to the grooves. Orders +/-1..maxOrder are summed,
    /// weighted by 1/m^2 (no true blaze model) and a smooth spectral band per order.
    public static func spectrum(
        sinIn: Float,
        sinOut: Float,
        linesPerMm: Float,
        maxOrder: Int = 2,
        bandWidthNm: Float = 24,
        into samples: inout [Float]
    ) {
        for i in 0..<samples.count { samples[i] = 0 }
        let d = periodNm(linesPerMm: linesPerMm)
        var weightSum: Float = 0
        for m in 1...maxOrder {
            for sign in [1, -1] {
                let order = m * sign
                guard let lambda = wavelength(sinIn: sinIn, sinOut: sinOut, groovePeriodNm: d, order: order) else { continue }
                let weight = 1.0 / Float(m * m)
                weightSum += weight
                let band = Spectrum.bandSamples(nm: lambda, width: bandWidthNm)
                for i in 0..<samples.count {
                    samples[i] += weight * band[i]
                }
            }
        }
        // Average over the visible orders so brightness stays continuous where
        // additional orders enter/leave the visible wavelength range.
        if weightSum > 1 {
            let inv = 1 / weightSum
            for i in 0..<samples.count { samples[i] *= inv }
        }
    }

    /// Convenience: linear sRGB color diffracted to the viewer.
    public static func rgb(
        sinIn: Float,
        sinOut: Float,
        linesPerMm: Float,
        maxOrder: Int = 2
    ) -> SIMD3<Float> {
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        spectrum(sinIn: sinIn, sinOut: sinOut, linesPerMm: linesPerMm, maxOrder: maxOrder, into: &samples)
        return Spectrum.rgb(samples: samples)
    }
}
