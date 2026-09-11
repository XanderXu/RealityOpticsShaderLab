import XCTest
import simd
@testable import OpticsPhysics

final class SpectrumTests: XCTestCase {

    func testReflectAllIsWhiteUnderD65() {
        let white = Spectrum.rgb(samples: [Float](repeating: 1, count: Spectrum.sampleCount))
        XCTAssertEqual(white.x, 1, accuracy: 0.01)
        XCTAssertEqual(white.y, 1, accuracy: 0.01)
        XCTAssertEqual(white.z, 1, accuracy: 0.01)
    }

    func testAbsorbAllIsBlack() {
        let black = Spectrum.rgb(samples: [Float](repeating: 0, count: Spectrum.sampleCount))
        XCTAssertEqual(black.x, 0, accuracy: 1e-5)
        XCTAssertEqual(black.y, 0, accuracy: 1e-5)
        XCTAssertEqual(black.z, 0, accuracy: 1e-5)
    }

    func testMonochromatic550IsGreenDominant() {
        let green = Spectrum.rgb(samples: Spectrum.bandSamples(nm: 550, width: 10))
        XCTAssertGreaterThan(green.y, green.x, "green channel should dominate a 550 nm light")
        XCTAssertGreaterThan(green.y, green.z)
        XCTAssertGreaterThan(green.y, 0.1)
    }

    func testMonochromatic450IsBlueDominant() {
        let blue = Spectrum.rgb(samples: Spectrum.bandSamples(nm: 450, width: 10))
        XCTAssertGreaterThan(blue.z, blue.x)
        XCTAssertGreaterThan(blue.z, blue.y)
    }

    func testMonochromatic650IsRedDominant() {
        let red = Spectrum.rgb(samples: Spectrum.bandSamples(nm: 650, width: 10))
        XCTAssertGreaterThan(red.x, red.y)
        XCTAssertGreaterThan(red.x, red.z)
    }
}

final class ThinFilmTests: XCTestCase {

    let config = ThinFilmConfig()

    func testZeroThicknessReflectsLikePlainInterface() {
        // With d = 0 the film disappears; reflectance is the plain 1->3 interface (air/air => ~0)
        let angles = ThinFilmAngles(cosTheta: 1, config: config)
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        ThinFilm.reflectanceSpectrum(d: 0, angles: angles, n2: config.n2, into: &samples)
        let avg = samples.reduce(0, +) / Float(samples.count)
        XCTAssertLessThan(avg, 0.02, "a vanished film between equal media should not reflect")
    }

    func testReflectanceEnergyBounded() {
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        let angles = ThinFilmAngles(cosTheta: 0.5, config: config)
        for d in stride(from: Float(0), through: 1200, by: 137) {
            ThinFilm.reflectanceSpectrum(d: d, angles: angles, n2: config.n2, into: &samples)
            for r in samples {
                XCTAssertGreaterThanOrEqual(r, -1e-4)
                XCTAssertLessThanOrEqual(r, 1.0 + 1e-3, "reflectance must stay within [0,1]")
            }
        }
    }

    func testGrazingAngleReflectsMoreThanNormal() {
        // Fresnel: a soap film is more reflective at grazing angles
        let normal = ThinFilm.rgb(d: 400, cosTheta: 0.95, config: config)
        let grazing = ThinFilm.rgb(d: 400, cosTheta: 0.15, config: config)
        let sum: (SIMD3<Float>) -> Float = { $0.x + $0.y + $0.z }
        XCTAssertGreaterThan(sum(grazing), sum(normal) * 1.5)
    }

    func testThicknessSweepsThroughHues() {
        // Colors should vary (and cycle) as thickness grows: compare several thicknesses
        let c100 = ThinFilm.rgb(d: 100, cosTheta: 0.6, config: config)
        let c400 = ThinFilm.rgb(d: 400, cosTheta: 0.6, config: config)
        let c800 = ThinFilm.rgb(d: 800, cosTheta: 0.6, config: config)
        let d1 = simd_distance(c100, c400)
        let d2 = simd_distance(c400, c800)
        XCTAssertGreaterThan(d1, 0.02, "different thicknesses should produce different colors")
        XCTAssertGreaterThan(d2, 0.02)
    }
}

final class DiffractionGratingTests: XCTestCase {

    func testGratingEquationKnownPoint() {
        // d = 1600 nm, sinIn - sinOut = 0.3, m = 1 -> lambda = 480 nm
        let lambda = DiffractionGrating.wavelength(sinIn: 0.4, sinOut: 0.1, groovePeriodNm: 1600, order: 1)
        XCTAssertEqual(lambda ?? -1, 480, accuracy: 0.5)
        // m = -1 -> 480 nm on the mirrored side
        let lambdaM = DiffractionGrating.wavelength(sinIn: 0.1, sinOut: 0.4, groovePeriodNm: 1600, order: -1)
        XCTAssertEqual(lambdaM ?? -1, 480, accuracy: 0.5)
    }

    func testOutOfRangeGivesNoColor() {
        XCTAssertNil(DiffractionGrating.wavelength(sinIn: 0.4, sinOut: 0.1, groovePeriodNm: 1000, order: 2))
        XCTAssertNil(DiffractionGrating.wavelength(sinIn: 0, sinOut: 0, groovePeriodNm: 1600, order: 1))
    }

    func testPeriodFromDensity() {
        // CD: 625 lines/mm -> 1600 nm
        XCTAssertEqual(DiffractionGrating.periodNm(linesPerMm: 625), 1600, accuracy: 0.01)
    }

    func testSpectrumPeaksNearPredictedWavelength() {
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        DiffractionGrating.spectrum(sinIn: 0.4, sinOut: 0.1, linesPerMm: 625, into: &samples)
        let peakIndex = samples.enumerated().max { $0.element < $1.element }!.offset
        XCTAssertEqual(Spectrum.wavelength(peakIndex), 480, accuracy: 20)
    }
}

final class BirefringenceTests: XCTestCase {

    func testPiRetardanceTransmitsGreen() {
        // delta = pi -> 550 nm fully transmitted through crossed polarizers
        var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
        let delta: Float = .pi
        for i in 0..<Spectrum.sampleCount {
            let lambda = Spectrum.wavelength(i)
            let t = sin(delta * 550 / (2 * lambda))
            samples[i] = t * t
        }
        let rgb = Spectrum.rgb(samples: samples)
        XCTAssertGreaterThan(rgb.y, 0.15, "550nm should pass at pi retardance")
    }

    func testTwoPiRetardanceExtinctAtReference() {
        // delta = 2pi -> 550 nm extinct; total luminance below the pi case
        func integrate(_ delta: Float) -> Float {
            var samples = [Float](repeating: 0, count: Spectrum.sampleCount)
            for i in 0..<Spectrum.sampleCount {
                let lambda = Spectrum.wavelength(i)
                let t = sin(delta * 550 / (2 * lambda))
                samples[i] = t * t
            }
            return Spectrum.rgb(samples: samples).y
        }
        XCTAssertLessThan(integrate(2 * .pi), integrate(.pi) * 0.6,
                          "2pi retardance should be darker than pi at 550nm")
    }

    func testBirefringenceLUTNonBlack() {
        let lut = LUTBuilder.birefringenceLUT(width: 64)
        XCTAssertEqual(lut.count, 64 * 4)
        var hasColor = false
        for t in 0..<64 where lut[t * 4 + 1] != 0 { hasColor = true }
        XCTAssertTrue(hasColor)
    }
}

final class LUTBuilderTests: XCTestCase {

    func testHalfConversion() {
        XCTAssertEqual(LUTBuilder.floatToHalf(0), 0)
        XCTAssertEqual(LUTBuilder.floatToHalf(1), 0x3C00)
        XCTAssertEqual(LUTBuilder.floatToHalf(-1), 0xBC00)
        XCTAssertEqual(LUTBuilder.floatToHalf(0.5), 0x3800)
        XCTAssertEqual(LUTBuilder.floatToHalf(2), 0x4000)
        // large values clamp toward inf bit pattern, not garbage
        let big = LUTBuilder.floatToHalf(1e9)
        XCTAssertEqual(big & 0x7C00, 0x7C00)
    }

    func testFilmLUTSizeAndNonTrivial() {
        let lut = LUTBuilder.filmLUT(width: 16, height: 16)
        XCTAssertEqual(lut.count, 16 * 16 * 4)
        // find at least one texel with a strong color
        var maxLuma: Float = 0
        for t in 0..<(16 * 16) {
            // luma in half space approximated by G channel bit pattern for 1.0..: just check nonzero bytes exist
            if lut[t * 4 + 1] != 0 { maxLuma = 1 }
        }
        XCTAssertEqual(maxLuma, 1, "LUT must contain non-black texels")
    }

    func testFilmLUTGrazingBrighterThanNormal() {
        // compare column extremes of a small LUT at mid thickness
        let w = 8, h = 8
        let lut = LUTBuilder.filmLUT(width: w, height: h)
        func green(atX x: Int, y: Int) -> UInt16 { lut[(y * w + x) * 4 + 1] }
        let row = h / 2
        XCTAssertGreaterThan(green(atX: 0, y: row), green(atX: w - 1, y: row),
                            "U=0 (grazing, cos~0) should be brighter than U=1 (normal incidence)")
    }
}
