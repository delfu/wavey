import XCTest
@testable import WaveyEngine
import Foundation

final class TunerTests: XCTestCase {

    private let tuner = Tuner()

    func testLowEInTune() {
        let r = tuner.reading(forFrequency: 82.41)
        XCTAssertEqual(r.string, Note(.e, 2))
        XCTAssertEqual(r.cents, 0, accuracy: 1)
        XCTAssertTrue(r.isInTune)
    }

    func testAllOpenStringsInTune() {
        for s in StandardTuning.openStrings {
            let r = tuner.reading(forFrequency: s.frequency)
            XCTAssertEqual(r.string, s)
            XCTAssertEqual(r.cents, 0, accuracy: 1e-6)
            XCTAssertTrue(r.isInTune)
        }
    }

    func testSharpAndFlatSignAndMagnitude() {
        let sharp = tuner.reading(forFrequency: 110.0 * pow(2.0, 20.0 / 1200.0))
        XCTAssertEqual(sharp.string, Note(.a, 2))
        XCTAssertEqual(sharp.cents, 20, accuracy: 0.5)
        XCTAssertFalse(sharp.isInTune)

        let flat = tuner.reading(forFrequency: 110.0 * pow(2.0, -20.0 / 1200.0))
        XCTAssertEqual(flat.string, Note(.a, 2))
        XCTAssertEqual(flat.cents, -20, accuracy: 0.5)
        XCTAssertFalse(flat.isInTune)
    }

    func testNearestStringPicksCloser() {
        XCTAssertEqual(tuner.reading(forFrequency: 150.0).string, Note(.d, 3)) // just above D3
        XCTAssertEqual(tuner.reading(forFrequency: 190.0).string, Note(.g, 3)) // just below G3
    }

    func testStringLockPreventsJump() {
        // 100 Hz sits between E2 and A2; nearest is A2...
        XCTAssertEqual(tuner.reading(forFrequency: 100.0).string, Note(.a, 2))
        // ...but locked to E2 it reports relative to E2 (sharp), no jump.
        let locked = tuner.reading(forFrequency: 100.0, lockedTo: Note(.e, 2))
        XCTAssertEqual(locked.string, Note(.e, 2))
        XCTAssertGreaterThan(locked.cents, 0)
        XCTAssertEqual(locked.cents, 1200 * log2(100.0 / 82.41), accuracy: 0.1)
    }

    func testCustomTolerance() {
        let plus3 = 110.0 * pow(2.0, 3.0 / 1200.0)
        XCTAssertFalse(Tuner(inTuneTolerance: 2).reading(forFrequency: plus3).isInTune) // outside ±2
        XCTAssertTrue(tuner.reading(forFrequency: plus3).isInTune)                       // inside default ±5
    }
}
