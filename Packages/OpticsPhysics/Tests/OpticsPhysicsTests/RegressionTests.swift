import XCTest
import simd
@testable import OpticsPhysics

final class SpectralReferenceTests: XCTestCase {
    func testOfficialCIESamplesAndD65Chromaticity() {
        XCTAssertEqual(Spectrum.d65[Spectrum.index(of: 560)], 100, accuracy: 0.0001)
        XCTAssertEqual(Spectrum.d65[Spectrum.index(of: 450)], 117.008, accuracy: 0.001)
        XCTAssertEqual(Spectrum.cmfY[Spectrum.index(of: 555)], 1, accuracy: 0.00001)
        var xyz = SIMD3<Float>(repeating: 0)
        for i in 0..<Spectrum.sampleCount {
            xyz += SIMD3(Spectrum.cmfX[i], Spectrum.cmfY[i], Spectrum.cmfZ[i]) * Spectrum.d65[i]
        }
        let sum = xyz.x + xyz.y + xyz.z
        // The old per-RGB-channel white correction passed a white-output test
        // even though its embedded illuminant had the wrong chromaticity.
        XCTAssertEqual(xyz.x / sum, 0.3127, accuracy: 0.0002)
        XCTAssertEqual(xyz.y / sum, 0.3290, accuracy: 0.0002)
    }

    func testNearestWavelengthIndex() {
        XCTAssertEqual(Spectrum.wavelength(Spectrum.index(of: 553)), 555)
        XCTAssertEqual(Spectrum.wavelength(Spectrum.index(of: 552)), 550)
        XCTAssertEqual(Spectrum.index(of: 200), 0)
        XCTAssertEqual(Spectrum.index(of: 900), Spectrum.sampleCount - 1)
    }

    func testRGBIntegrationIsLinear() {
        let a = Spectrum.bandSamples(nm: 460, width: 30)
        let b = Spectrum.bandSamples(nm: 620, width: 40)
        let mix = zip(a, b).map { 0.3 * $0 + 0.7 * $1 }
        let expected = 0.3 * Spectrum.rgb(samples: a) + 0.7 * Spectrum.rgb(samples: b)
        XCTAssertLessThan(simd_distance(Spectrum.rgb(samples: mix), expected), 0.00001)
    }
}

final class FilmReferenceTests: XCTestCase {
    private func reflectance(_ d: Float, cosTheta: Float = 1, config: ThinFilmConfig) -> [Float] {
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        ThinFilm.reflectanceSpectrum(d: d, angles: ThinFilmAngles(cosTheta: cosTheta, config: config), n2: config.n2, into: &samples)
        return samples
    }

    func testQuarterWaveAndHalfWaveSlab() {
        let config = ThinFilmConfig(n2: 1.5, sigmaD: 0)
        let green = Spectrum.index(of: 550)
        let quarter = reflectance(550 / (4 * 1.5), config: config)[green]
        XCTAssertEqual(quarter, 0.147928994, accuracy: 0.00001)
        XCTAssertEqual(reflectance(550 / (2 * 1.5), config: config)[green], 0, accuracy: 0.000001)
    }

    func testVanishingFilmIsExteriorSubstrateInterface() {
        let config = ThinFilmConfig(n2: 1.7, n3: 1.33, sigmaD: 0)
        let expected = pow((1 - Float(1.33)) / (1 + Float(1.33)), 2)
        for value in reflectance(0, config: config) {
            XCTAssertEqual(value, expected, accuracy: 0.000001)
        }
    }

    func testIdenticalMediaAreInvisibleIncludingGrazing() {
        let config = ThinFilmConfig(n1: 1.5, n2: 1.5, n3: 1.5, sigmaD: 0)
        for angle: Float in [0, 0.0001, 0.5, 1] {
            for value in reflectance(550, cosTheta: angle, config: config) {
                XCTAssertEqual(value, 0, accuracy: 0.000001)
            }
        }
    }

    func testFrustratedTotalInternalReflection() {
        let config = ThinFilmConfig(n1: 1.5, n2: 1, n3: 1.5, sigmaD: 0)
        let green = Spectrum.index(of: 550)
        let thin = reflectance(50, cosTheta: 0.5, config: config)[green]
        let thick = reflectance(5000, cosTheta: 0.5, config: config)[green]
        XCTAssertGreaterThan(thin, 0.05)
        XCTAssertLessThan(thin, 0.9)
        XCTAssertEqual(thick, 1, accuracy: 0.00001)
        XCTAssertEqual(reflectance(0, cosTheta: 0.5, config: config)[green], 0)
    }

    func testLosslessTotalReflectionIntoSubstrate() {
        let config = ThinFilmConfig(n1: 1.5, n2: 1.7, n3: 1, sigmaD: 0)
        for d: Float in [10, 300, 1200] {
            for value in reflectance(d, cosTheta: 0.5, config: config) {
                XCTAssertEqual(value, 1, accuracy: 0.00001)
            }
        }
    }

    func testFastAiryMatchesIndependentComplexExpansion() {
        for n2: Float in [1.2, 1.333, 1.56] {
            for c1: Float in [0.02, 0.3, 0.8, 1] {
                let c2 = sqrt(1 - (1 - c1 * c1) / (n2 * n2))
                let rs = (c1 - n2 * c2) / (c1 + n2 * c2)
                let rp = (n2 * c1 - c2) / (n2 * c1 + c2)
                for d: Float in [0.01, 90, 216, 800] {
                    let actual = reflectance(d, cosTheta: c1, config: ThinFilmConfig(n2: n2, sigmaD: 0))
                    for i in actual.indices {
                        let phase = 4 * Double.pi * Double(n2 * d * c2) / Double(Spectrum.wavelength(i))
                        func reference(_ r: Float) -> Double {
                            let a = Double(r), b = -Double(r)
                            let nr = a + b * cos(phase), ni = b * sin(phase)
                            let dr = 1 + a * b * cos(phase), di = a * b * sin(phase)
                            return (nr * nr + ni * ni) / (dr * dr + di * di)
                        }
                        XCTAssertEqual(actual[i], Float(0.5 * (reference(rs) + reference(rp))), accuracy: 0.0001)
                    }
                }
            }
        }
    }

    func testNewtonAirGapHasDifferentOpticalPeriodFromSoap() {
        let air = ThinFilmConfig(n1: 1.52, n2: 1, n3: 1.52, sigmaD: 0)
        let soap = ThinFilmConfig(n2: 1.333, sigmaD: 0)
        let index = Spectrum.index(of: 550)
        XCTAssertEqual(reflectance(275, config: air)[index], 0, accuracy: 0.000001)
        XCTAssertGreaterThan(reflectance(275, config: soap)[index], 0.03)
        XCTAssertEqual(reflectance(0, config: air)[index], 0)
    }
}

final class GratingContinuityTests: XCTestCase {
    func testSpectralBandsCrossVisibleLimitsContinuously() {
        for boundary: Float in [380, 780, 760, 1560] {
            let below = DiffractionGrating.rgb(sinIn: (boundary - 0.01) / 1600, sinOut: 0, linesPerMm: 625)
            let above = DiffractionGrating.rgb(sinIn: (boundary + 0.01) / 1600, sinOut: 0, linesPerMm: 625)
            XCTAssertLessThan(simd_distance(below, above), 0.001)
        }
    }

    func testMirroredOrdersHaveEqualSpectraAndBoundedEnergy() {
        var positive = [Float](repeating: 0, count: Spectrum.sampleCount)
        var negative = positive
        for delta: Float in [0, 0.3, 0.7, 1] {
            DiffractionGrating.spectrum(sinIn: delta, sinOut: 0, linesPerMm: 625, into: &positive)
            DiffractionGrating.spectrum(sinIn: -delta, sinOut: 0, linesPerMm: 625, into: &negative)
            XCTAssertEqual(positive, negative)
            XCTAssertTrue(positive.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 })
        }
        DiffractionGrating.spectrum(sinIn: 0.5, sinOut: 0, linesPerMm: 625, maxOrder: 0, into: &positive)
        XCTAssertTrue(positive.allSatisfy { $0 == 0 })
    }
}

final class LookupRegressionTests: XCTestCase {
    func testHalfConversionCoversEveryFiniteHalfAndOverflowRounding() {
        for bits in UInt16.min...UInt16.max {
            let half = Float16(bitPattern: bits)
            if !half.isNaN { XCTAssertEqual(LUTBuilder.floatToHalf(Float(half)), bits) }
        }
        XCTAssertEqual(LUTBuilder.floatToHalf(65520), 0x7C00)
        XCTAssertEqual(LUTBuilder.floatToHalf(-65520), 0xFC00)
        XCTAssertEqual(LUTBuilder.floatToHalf(1 + 1.0 / 2048), 0x3C00)
    }

    func testWhiteLightRetardanceDoesNotRepeatEveryReferenceCycle() {
        let width = 1024
        let lut = LUTBuilder.birefringenceLUT(width: width)
        func sample(_ delta: Float) -> SIMD3<Float> {
            let x = Int(LUTBuilder.birefringenceU(delta: delta) * Float(width))
            return SIMD3(Float(Float16(bitPattern: lut[x * 4])), Float(Float16(bitPattern: lut[x * 4 + 1])), Float(Float16(bitPattern: lut[x * 4 + 2])))
        }
        XCTAssertGreaterThan(simd_distance(sample(.pi), sample(3 * .pi)), 0.1)
        XCTAssertEqual(LUTBuilder.birefringenceU(delta: 40 * .pi), 1, accuracy: 0.00001)
    }

    func testAllLookupBuildersProduceFiniteNonnegativeRGBA() {
        let tables = [LUTBuilder.filmLUT(width: 16, height: 16), LUTBuilder.nacreLUT(width: 16, height: 16), LUTBuilder.gratingLUT(width: 16, height: 16), LUTBuilder.birefringenceLUT(width: 64), LUTBuilder.newtonLUT(width: 16, height: 16)]
        for table in tables {
            for (index, bits) in table.enumerated() {
                let value = Float(Float16(bitPattern: bits))
                XCTAssertTrue(value.isFinite && value >= 0)
                if index % 4 == 3 { XCTAssertEqual(value, 1) }
            }
        }
    }
}
