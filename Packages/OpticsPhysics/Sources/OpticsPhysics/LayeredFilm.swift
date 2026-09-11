import Foundation

/// Fixed demonstration stacks. Optical constants are nondispersive approximations,
/// including the representative titanium n+ik; these are not measured color charts.
public enum LayeredFilm: UInt32, CaseIterable, Sendable {
    case oil = 5, titanium = 6, coating = 7, dichroic = 8, dichroicTransmission = 9

    public var domainMinimum: Float { self == .dichroic || self == .dichroicTransmission ? 400 : 0 }
    public var domainSpan: Float {
        switch self {
        case .oil: return 1000
        default: return 300
        }
    }

    /// Independent Double-precision complex-amplitude reference. The design
    /// parameter is thickness (nm), or central wavelength for the six-layer filter.
    public func reflectance(cosTheta: Double, design: Double, wavelength: Double) -> Double {
        precondition(cosTheta.isFinite && design.isFinite && wavelength > 0)
        let cosine = min(max(cosTheta, 0.000001), 1)
        let sinSquared = 1 - cosine * cosine
        let indices: [ComplexIndex]
        let thickness: [Double]
        switch self {
        case .oil:
            indices = [.init(1), .init(1.47), .init(1.333)]
            thickness = [max(0, design)]
        case .titanium:
            indices = [.init(1), .init(2.4), .init(2.7, 3.3)]
            thickness = [max(0, design)]
        case .coating:
            indices = [.init(1), .init(1.38), .init(1.52)]
            thickness = [max(0, design)]
        case .dichroic, .dichroicTransmission:
            indices = [.init(1), .init(2.1), .init(1.45), .init(2.1), .init(1.45), .init(2.1), .init(1.45), .init(1.52)]
            thickness = (1...6).map { max(0, design) / (4 * indices[$0].re) }
        }
        let q = indices.map { ($0 * $0 - ComplexIndex(sinSquared)).squareRoot }
        func polarization(_ p: Bool) -> Double {
            let admittance = zip(indices, q).map { p ? $0 * $0 / $1 : $1 }
            func interface(_ i: Int) -> ComplexIndex {
                (admittance[i] - admittance[i+1]) / (admittance[i] + admittance[i+1])
            }
            var r = interface(thickness.count)
            for i in stride(from: thickness.count - 1, through: 0, by: -1) {
                let phase = q[i+1] * ComplexIndex(4 * .pi * thickness[i] / wavelength)
                let attenuation = exp(-phase.im)
                let propagation = ComplexIndex(attenuation * cos(phase.re), attenuation * sin(phase.re))
                let a = interface(i)
                let b = r * propagation
                r = (a + b) / (ComplexIndex(1) + a * b)
            }
            return r.norm
        }
        return min(max((polarization(false) + polarization(true)) * 0.5, 0), 1)
    }

    public func pixels(width: Int = 256, height: Int = 256, preserveSignedRGB: Bool = false) -> [UInt16] {
        precondition(width > 0 && height > 0)
        var pixels = [UInt16](repeating: 0, count: width * height * 4)
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        for y in 0..<height {
            let design = Double(domainMinimum + (Float(y) + 0.5) / Float(height) * domainSpan)
            for x in 0..<width {
                let c = (Double(x) + 0.5) / Double(width)
                for i in samples.indices {
                    let r = reflectance(cosTheta: c, design: design, wavelength: Double(Spectrum.wavelength(i)))
                    samples[i] = Float(self == .dichroicTransmission ? 1 - r : r)
                }
                let rgb = Spectrum.rgb(samples: samples)
                let index = (y * width + x) * 4
                for channel in 0..<3 { pixels[index+channel] = Float16(preserveSignedRGB ? rgb[channel] : min(max(rgb[channel], 0), 4)).bitPattern }
                pixels[index+3] = Float16(1).bitPattern
            }
        }
        return pixels
    }
}

private struct ComplexIndex {
    var re: Double
    var im: Double
    init(_ re: Double, _ im: Double = 0) { self.re = re; self.im = im }
    var norm: Double { re * re + im * im }
    var squareRoot: Self {
        let length = sqrt(norm)
        return Self(sqrt(max(0, (length + re) / 2)), (im < 0 ? -1 : 1) * sqrt(max(0, (length - re) / 2)))
    }
    static func + (a: Self, b: Self) -> Self { .init(a.re+b.re, a.im+b.im) }
    static func - (a: Self, b: Self) -> Self { .init(a.re-b.re, a.im-b.im) }
    static func * (a: Self, b: Self) -> Self { .init(a.re*b.re-a.im*b.im, a.re*b.im+a.im*b.re) }
    static func / (a: Self, b: Self) -> Self { .init((a.re*b.re+a.im*b.im)/b.norm, (a.im*b.re-a.re*b.im)/b.norm) }
}
