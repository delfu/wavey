import XCTest
@testable import WaveyEngine
import Foundation

final class BeatTrackerTests: XCTestCase {

    private let sr = 44100.0

    /// A click track: short decaying 1.5 kHz blips at the given tempo.
    private func clickTrack(bpm: Double, seconds: Double) -> [Float] {
        var signal = [Float](repeating: 0, count: Int(seconds * sr))
        let interval = 60.0 / bpm
        var t = 0.0
        while t < seconds {
            let start = Int(t * sr)
            for i in 0..<Int(0.02 * sr) where start + i < signal.count {
                let env = exp(-40.0 * Double(i) / sr)
                signal[start + i] += Float(env * sin(2 * .pi * 1500 * Double(i) / sr))
            }
            t += interval
        }
        return signal
    }

    private func medianSpacing(_ beats: [Double]) -> Double {
        let spacings = zip(beats.dropFirst(), beats).map { $0 - $1 }.sorted()
        return spacings.isEmpty ? 0 : spacings[spacings.count / 2]
    }

    func testDetects100BPM() {
        let result = BeatTracker(sampleRate: sr).analyze(clickTrack(bpm: 100, seconds: 6))
        XCTAssertEqual(result.bpm, 100, accuracy: 8)
        XCTAssertEqual(medianSpacing(result.beats), 0.6, accuracy: 0.08)   // 60/100
    }

    func testDetects144BPM() {
        let result = BeatTracker(sampleRate: sr).analyze(clickTrack(bpm: 144, seconds: 6))
        XCTAssertEqual(result.bpm, 144, accuracy: 8)
    }

    func testBeatsSpanTheClip() {
        let result = BeatTracker(sampleRate: sr).analyze(clickTrack(bpm: 120, seconds: 8))
        // ~16 beats over 8 s at 120 BPM; allow generous tolerance.
        XCTAssertGreaterThanOrEqual(result.beats.count, 12)
    }

    func testSilenceDoesNotCrash() {
        let result = BeatTracker(sampleRate: sr).analyze([Float](repeating: 0, count: Int(2 * sr)))
        XCTAssertFalse(result.bpm.isNaN)   // flat envelope → no real tempo, but must stay finite
    }
}
