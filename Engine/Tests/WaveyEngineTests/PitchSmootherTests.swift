import XCTest
@testable import WaveyEngine

final class PitchSmootherTests: XCTestCase {

    private func p(_ frequency: Double, _ confidence: Double) -> PitchResult {
        PitchResult(frequency: frequency, confidence: confidence)
    }

    func testRejectsLowConfidence() {
        var s = PitchSmoother(minConfidence: 0.9)
        XCTAssertNil(s.update(p(440, 0.5)))
        XCTAssertNil(s.update(nil))
    }

    func testFirstConfidentFrameSetsValue() {
        var s = PitchSmoother()
        XCTAssertEqual(s.update(p(440, 0.99)) ?? 0, 440, accuracy: 1e-9)
    }

    func testSmoothsSmallChanges() {
        var s = PitchSmoother(minConfidence: 0.9, smoothing: 0.2, snapCents: 80)
        _ = s.update(p(440, 0.99))                         // value = 440
        let v = s.update(p(450, 0.99)) ?? 0                 // ~39 cents away, < snap
        XCTAssertEqual(v, 442, accuracy: 0.001)             // 440 + 0.2 * (450 - 440)
    }

    func testSnapsOnLargeJump() {
        var s = PitchSmoother(snapCents: 80)
        _ = s.update(p(440, 0.99))                          // A4
        XCTAssertEqual(s.update(p(330, 0.99)) ?? 0, 330, accuracy: 1e-9) // ~500 cents -> snap
    }

    func testHoldsThenClears() {
        var s = PitchSmoother(minConfidence: 0.9, holdFrames: 2)
        _ = s.update(p(440, 0.99))
        XCTAssertEqual(s.update(nil) ?? 0, 440, accuracy: 1e-9) // hold 1
        XCTAssertEqual(s.update(nil) ?? 0, 440, accuracy: 1e-9) // hold 2
        XCTAssertNil(s.update(nil))                             // exceeded hold -> clear
    }

    func testLowConfidenceFrameCountsAsEmpty() {
        var s = PitchSmoother(minConfidence: 0.9, holdFrames: 1)
        _ = s.update(p(440, 0.99))
        XCTAssertEqual(s.update(p(440, 0.3)) ?? 0, 440, accuracy: 1e-9) // held
        XCTAssertNil(s.update(p(440, 0.3)))                             // exceeded hold
    }
}
