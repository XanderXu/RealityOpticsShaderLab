import XCTest
@testable import OpticsPhysics

final class SpatialLookupTests: XCTestCase {
    func testRainbowAnglesAndReversedSecondaryOrder() {
        let red = SpatialLookup.rainbowAngle(wavelength: 650, order: 1) * 180 / .pi
        let blue = SpatialLookup.rainbowAngle(wavelength: 450, order: 1) * 180 / .pi
        let secondaryRed = SpatialLookup.rainbowAngle(wavelength: 650, order: 2) * 180 / .pi
        let secondaryBlue = SpatialLookup.rainbowAngle(wavelength: 450, order: 2) * 180 / .pi
        XCTAssertTrue((41...43).contains(red))
        XCTAssertTrue((49...53).contains(secondaryRed))
        XCTAssertGreaterThan(red, blue)
        XCTAssertLessThan(secondaryRed, secondaryBlue)
    }
    func testRainbowLocalizedAroundAntisolarRings() {
        let lut = SpatialLookup.rainbow
        let peak = SpatialLookup.rainbowAngle(wavelength: 550, order: 1) / .pi
        XCTAssertGreaterThan(lut.spectrum(u: peak, v: 0.1, wavelength: 550), 0.99)
        XCTAssertLessThan(lut.spectrum(u: 0.5, v: 0.1, wavelength: 550), 0.0001)
    }
    func testAtmosphereVacuumAndNight() {
        let lut = SpatialLookup.atmosphere
        for wavelength: Float in [380, 550, 780] {
            XCTAssertEqual(lut.spectrum(u: 1, v: 0, wavelength: wavelength), 0)
            XCTAssertLessThan(lut.spectrum(u: 0, v: 1, wavelength: wavelength), 0.0001)
        }
        XCTAssertGreaterThan(lut.spectrum(u: 1, v: 0.1, wavelength: 450),
                             lut.spectrum(u: 1, v: 0.1, wavelength: 650))
        XCTAssertLessThan(lut.spectrum(u: 0.5, v: 0.1, wavelength: 450),
                          lut.spectrum(u: 0.5, v: 0.1, wavelength: 650))
    }
    func testAtlasesHaveDistinctViewsAndFiniteColors() {
        for model in [SpatialLookup.views, .nebula] {
            let colors = [(0,0),(1,0),(0,1),(1,1)].map { tile in
                model.color(u: (0.31 + Float(tile.0)) * 0.5, v: (0.61 + Float(tile.1)) * 0.5)
            }
            for i in 1..<4 { XCTAssertNotEqual(colors[0], colors[i]) }
            for color in colors { for c in 0..<3 { XCTAssertTrue(color[c].isFinite && color[c] >= 0) } }
        }
    }
    func testEnvironmentLongitudeSeamIsContinuous() {
        for v: Float in [0.1, 0.5, 0.9] {
            let a = SpatialLookup.environment.color(u: 0, v: v)
            let b = SpatialLookup.environment.color(u: 1, v: v)
            for c in 0..<3 { XCTAssertEqual(a[c], b[c], accuracy: 0.0001) }
        }
    }
    func testOptimizedSpectralPixelsMatchIndependentFormula() {
        for model in [SpatialLookup.rainbow, .atmosphere] {
            let pixels = model.pixels()
            let rows = [0, model.height / 2, model.height - 1]
            let columns = [0, 220, 238, 280, 300, model.width - 1].filter { $0 < model.width }
            for y in rows { for x in columns {
                let u = (Float(x)+0.5)/Float(model.width), v = (Float(y)+0.5)/Float(model.height)
                let reference = Spectrum.rgb(samples: (0..<Spectrum.sampleCount).map {
                    model.spectrum(u: u, v: v, wavelength: Spectrum.lambdaMin + Float($0) * Spectrum.step)
                })
                for c in 0..<3 {
                    let actual = Float(Float16(bitPattern: pixels[(y*model.width+x)*4+c]))
                    XCTAssertEqual(actual, max(0,min(4,reference[c])), accuracy: 0.001)
                }
            } }
        }
    }

}
