import XCTest
@testable import OpticsPhysics

final class LayeredFilmTests: XCTestCase {
    func testZeroThicknessCollapsesToBareSubstrate() {
        for (model, n, k) in [(LayeredFilm.oil, 1.333, 0.0), (.coating, 1.52, 0), (.titanium, 2.7, 3.3)] {
            let expected = ((n-1)*(n-1)+k*k)/((n+1)*(n+1)+k*k)
            for lambda in [380.0, 550, 780] {
                XCTAssertEqual(model.reflectance(cosTheta: 1, design: 0, wavelength: lambda), expected, accuracy: 1e-12)
            }
        }
    }

    func testQuarterWaveAntireflectionMinimum() {
        let n = 1.38, substrate = 1.52, wavelength = 550.0
        let d = wavelength / (4*n)
        let expected = pow((n*n-substrate)/(n*n+substrate), 2)
        let coated = LayeredFilm.coating.reflectance(cosTheta: 1, design: d, wavelength: wavelength)
        let bare = LayeredFilm.coating.reflectance(cosTheta: 1, design: 0, wavelength: wavelength)
        XCTAssertEqual(coated, expected, accuracy: 1e-12)
        XCTAssertLessThan(coated, bare)
        XCTAssertLessThan(coated, LayeredFilm.coating.reflectance(cosTheta: 1, design: d, wavelength: 400))
    }

    func testSixLayerBraggCenterMatchesClosedForm() {
        // Three H/L quarter-wave pairs transform substrate admittance exactly.
        let admittance = 1.52 * pow(2.1/1.45, 6)
        let expected = pow((1-admittance)/(1+admittance), 2)
        XCTAssertEqual(LayeredFilm.dichroic.reflectance(cosTheta: 1, design: 540, wavelength: 540), expected, accuracy: 1e-12)
        XCTAssertGreaterThan(expected, 0.7)
    }

    func testOilMatchesIndependentThreeMediumAirySolver() {
        let config = ThinFilmConfig(n1: 1, n2: 1.47, n3: 1.333, sigmaD: 0)
        for cosine: Float in [0.02, 0.3, 0.8, 1] {
            let angles = ThinFilmAngles(cosTheta: cosine, config: config)
            for thickness: Float in [0, 70, 380, 1000] {
                var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
                ThinFilm.reflectanceSpectrum(d: thickness, angles: angles, n2: 1.47, into: &samples)
                for i in samples.indices {
                    XCTAssertEqual(LayeredFilm.oil.reflectance(cosTheta: Double(cosine), design: Double(thickness), wavelength: Double(Spectrum.wavelength(i))), Double(samples[i]), accuracy: 0.00001)
                }
            }
        }
    }

    func testPassiveStacksStayFiniteAtGrazingAndAcrossDomains() {
        for model in LayeredFilm.allCases {
            for cosine in [0.0, 0.0001, 0.1, 0.5, 1.0] {
                for fraction in [0.0, 0.1, 0.5, 1.0] {
                    let design = Double(model.domainMinimum) + fraction * Double(model.domainSpan)
                    for lambda in stride(from: 380.0, through: 780, by: 10) {
                        let r = model.reflectance(cosTheta: cosine, design: design, wavelength: lambda)
                        XCTAssertTrue(r.isFinite && r >= 0 && r <= 1)
                    }
                }
            }
        }
    }
    func testSignedLookupComplementMatchesIndependentTransmissionIntegration() {
        let width = 32, height = 24
        let reflected = LayeredFilm.dichroic.pixels(width: width, height: height, preserveSignedRGB: true)
        let transmitted = LayeredFilm.dichroicTransmission.pixels(width: width, height: height)
        let white = Spectrum.rgb(samples: [Float](repeating: 1, count: Spectrum.sampleCount))
        for pixel in 0..<(width * height) {
            for c in 0..<3 {
                let r = Float(Float16(bitPattern: reflected[pixel*4+c]))
                let t = Float(Float16(bitPattern: transmitted[pixel*4+c]))
                XCTAssertEqual(max(white[c]-r, 0), t, accuracy: 0.001)
            }
        }
    }

    func testGamutClippingMustFollowComplement() {
        let rSpectrum = Spectrum.bandSamples(nm: 450, width: 15)
        let reflected = Spectrum.rgb(samples: rSpectrum)
        let transmitted = Spectrum.rgb(samples: rSpectrum.map { 1-$0 })
        let white = Spectrum.rgb(samples: [Float](repeating: 1, count: Spectrum.sampleCount))
        XCTAssertLessThan(reflected.y, 0)
        XCTAssertEqual(white.y-reflected.y, transmitted.y, accuracy: 0.000001)
        XCTAssertGreaterThan(transmitted.y, white.y)
    }

}
