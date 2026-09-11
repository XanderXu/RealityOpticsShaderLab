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
        precondition(samples.count == Spectrum.sampleCount)
        precondition(maxOrder >= 0 && bandWidthNm.isFinite && bandWidthNm > 0)
        for i in samples.indices { samples[i] = 0 }
        guard maxOrder > 0 else { return }
        let d = periodNm(linesPerMm: linesPerMm)
        let delta = abs(sinIn - sinOut)
        let sigma = max(bandWidthNm * 0.4246609, 0.75)
        let inv2s2 = 1 / (2 * sigma * sigma)
        // For any nonzero signed angle difference, only one sign of m gives
        // a positive wavelength. Fold +/- orders together instead of allocating
        // a temporary spectrum for both. Normalize by ALL modeled orders.
        var totalWeight: Float = 0
        for m in 1...maxOrder { totalWeight += 1 / (Float(m) * Float(m)) }
        for m in 1...maxOrder {
            let lambda = d * delta / Float(m)
            let weight = 1 / (Float(m) * Float(m) * totalWeight)
            // Keep Gaussian tails as their centers cross 380/780 nm. Rejecting
            // a whole band at the boundary caused visible brightness jumps.
            for i in samples.indices {
                let dl = Spectrum.wavelength(i) - lambda
                samples[i] += weight * exp(-dl * dl * inv2s2)
            }
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
