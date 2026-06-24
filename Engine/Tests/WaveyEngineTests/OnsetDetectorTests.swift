import XCTest
@testable import WaveyEngine
import Foundation

final class OnsetDetectorTests: XCTestCase {

    func testNoOnsetOnSilence() {
        var d = OnsetDetector()
        let zero = [Float](repeating: 0, count: 8)
        var onsets = 0
        for i in 0..<10 where d.process(magnitudes: zero, time: Double(i) * 0.02) { onsets += 1 }
        XCTAssertEqual(onsets, 0)
    }

    func testDetectsSuddenJump() {
        var d = OnsetDetector(minInterOnset: 0)
        let low = [Float](repeating: 1, count: 8)
        let high = [Float](repeating: 100, count: 8)
        _ = d.process(magnitudes: low, time: 0.00)
        _ = d.process(magnitudes: low, time: 0.02)
        XCTAssertTrue(d.process(magnitudes: high, time: 0.04))
    }

    func testSustainedToneHasNoRepeatOnset() {
        var d = OnsetDetector(minInterOnset: 0)
        let low = [Float](repeating: 1, count: 8)
        let high = [Float](repeating: 100, count: 8)
        _ = d.process(magnitudes: low, time: 0)
        XCTAssertTrue(d.process(magnitudes: high, time: 0.02))     // the attack
        var after = 0
        for i in 2..<12 where d.process(magnitudes: high, time: Double(i) * 0.02) { after += 1 }
        XCTAssertEqual(after, 0)
    }

    func testDebounceSuppressesCloseOnset() {
        var d = OnsetDetector(minInterOnset: 0.1)
        let low = [Float](repeating: 1, count: 8)
        let high = [Float](repeating: 100, count: 8)
        let higher = [Float](repeating: 200, count: 8)
        _ = d.process(magnitudes: low, time: 0)
        XCTAssertTrue(d.process(magnitudes: high, time: 0.02))      // onset
        _ = d.process(magnitudes: low, time: 0.03)
        XCTAssertFalse(d.process(magnitudes: higher, time: 0.05))   // within 0.1s debounce
    }

    func testCountsStrums() {
        let sr = 44100.0, n = 2048, hop = 1024
        let fft = FFT(size: n)!
        let total = Int(1.6 * sr)
        var signal = [Float](repeating: 0, count: total)
        for pluckTime in [0.0, 0.4, 0.8, 1.2] {            // four plucked 196 Hz tones
            let start = Int(pluckTime * sr)
            for i in 0..<Int(0.35 * sr) where start + i < total {
                let t = Double(i) / sr
                signal[start + i] += Float(exp(-6 * t) * sin(2 * .pi * 196 * t))
            }
        }
        var d = OnsetDetector(minInterOnset: 0.1)
        var onsets = 0, pos = 0
        while pos + n <= total {
            let mags = fft.magnitudeSpectrum(Window.hann.applied(to: Array(signal[pos..<pos + n])))
            if d.process(magnitudes: mags, time: Double(pos) / sr) { onsets += 1 }
            pos += hop
        }
        XCTAssertGreaterThanOrEqual(onsets, 3)
        XCTAssertLessThanOrEqual(onsets, 5)
    }
}
