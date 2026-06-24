import XCTest
@testable import WaveyEngine
import Foundation

final class InputCalibratorTests: XCTestCase {

    private var lcg: UInt64 = 0xC0FFEE

    /// Deterministic pseudo-noise frame in [-amp, amp].
    private func noise(amp: Float, count: Int = 1024) -> [Float] {
        (0..<count).map { _ in
            lcg = lcg &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int32(truncatingIfNeeded: lcg >> 33)) / Float(Int32.max) * amp
        }
    }

    private func sine(amp: Float, count: Int = 1024) -> [Float] {
        (0..<count).map { amp * Float(sin(2 * .pi * 220 * Double($0) / 44100)) }
    }

    private func calibrated() -> InputCalibrator {
        var cal = InputCalibrator(marginDB: 12)
        for _ in 0..<10 { cal.observeAmbient(noise(amp: 0.01)) }
        cal.finishCalibration()
        return cal
    }

    func testGateSitsAboveNoiseFloor() {
        let cal = calibrated()
        XCTAssertGreaterThan(cal.gateRMS, cal.noiseFloorRMS)
        XCTAssertGreaterThan(cal.noiseFloorRMS, 0)
    }

    func testLoudSignalPassesGate() {
        let cal = calibrated()
        XCTAssertTrue(cal.isAboveGate(sine(amp: 0.3)))
    }

    func testAmbientLevelIsGated() {
        let cal = calibrated()
        XCTAssertFalse(cal.isAboveGate(noise(amp: 0.01)))
    }
}
