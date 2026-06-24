import XCTest
@testable import WaveyEngine
import Foundation

final class PitchDetectorTests: XCTestCase {

    private let sr = 44100.0

    private func cents(_ detected: Double, _ expected: Double) -> Double {
        1200 * log2(detected / expected)
    }

    private func sine(_ f: Double, n: Int = 4096, amp: Float = 0.8) -> [Float] {
        (0..<n).map { amp * Float(sin(2 * .pi * f * Double($0) / sr)) }
    }

    func testDetectsA440() throws {
        let r = try XCTUnwrap(PitchDetector(sampleRate: sr).detect(sine(440)))
        XCTAssertEqual(cents(r.frequency, 440), 0, accuracy: 8)
        XCTAssertGreaterThan(r.confidence, 0.9)
    }

    func testSinesAcrossGuitarRange() throws {
        let det = PitchDetector(sampleRate: sr)
        // E2 up through A5 — the bulk of guitar range.
        for f in [82.41, 110.0, 146.83, 196.0, 246.94, 329.63, 440.0, 659.25, 880.0] {
            let r = try XCTUnwrap(det.detect(sine(f)), "no pitch at \(f) Hz")
            XCTAssertEqual(cents(r.frequency, f), 0, accuracy: 10, "off at \(f) Hz")
        }
    }

    func testSawtoothDetectsFundamental() throws {
        let det = PitchDetector(sampleRate: sr)
        for f in [110.0, 196.0] {
            // Naive ramp — harmonic-rich; the fundamental must win (no octave error).
            let saw = (0..<4096).map { i -> Float in
                let p = Double(i) / sr * f
                return Float(2 * (p - (p + 0.5).rounded(.down)))
            }
            let r = try XCTUnwrap(det.detect(saw))
            XCTAssertEqual(cents(r.frequency, f), 0, accuracy: 12, "octave error at \(f) Hz")
        }
    }

    func testSynthesizedGuitarTones() throws {
        // Plucked-string-like tones (fundamental + decaying harmonics + amplitude
        // decay). Real recordings aren't available in this environment; these
        // stand in for the Fixtures/ single-note clips called for by the issue.
        let det = PitchDetector(sampleRate: sr)
        let notes: [(String, Double)] = [
            ("E2", 82.41), ("A2", 110.0), ("D3", 146.83),
            ("G3", 196.0), ("B3", 246.94), ("E4", 329.63),
        ]
        for (name, f) in notes {
            let n = 4096
            var sig = [Float](repeating: 0, count: n)
            for i in 0..<n {
                let t = Double(i) / sr
                let env = exp(-3.0 * t)
                var s = 0.0
                for h in 1...6 { s += (1.0 / Double(h)) * sin(2 * .pi * f * Double(h) * t) }
                sig[i] = Float(0.8 * env * s)
            }
            let r = try XCTUnwrap(det.detect(sig), "no pitch for \(name)")
            XCTAssertEqual(cents(r.frequency, f), 0, accuracy: 15, "wrong pitch for \(name)")
        }
    }

    func testSilenceReturnsNil() {
        XCTAssertNil(PitchDetector(sampleRate: sr).detect([Float](repeating: 0, count: 4096)))
    }

    func testTooQuietReturnsNil() {
        // Below the RMS gate — should be treated as silence.
        XCTAssertNil(PitchDetector(sampleRate: sr).detect(sine(220, amp: 1e-4)))
    }

    func testNoiseIsNotConfident() {
        var state: UInt64 = 0x1234_5678
        let noise = (0..<4096).map { _ -> Float in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int32(truncatingIfNeeded: state >> 33)) / Float(Int32.max)
        }
        if let r = PitchDetector(sampleRate: sr).detect(noise) {
            XCTAssertLessThan(r.confidence, 0.9, "broadband noise should not read as a confident pitch")
        }
    }
}
