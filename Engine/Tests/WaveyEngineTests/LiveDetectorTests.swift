import XCTest
@testable import WaveyEngine
import Foundation

final class LiveDetectorTests: XCTestCase {

    private let sr = 44100.0
    private let n = 4096
    private let hop = 2048

    private func tone(_ frequencies: [Double], seconds: Double) -> [Float] {
        let count = Int(seconds * sr)
        var signal = [Float](repeating: 0, count: count)
        for f in frequencies {
            for i in 0..<count { signal[i] += Float(sin(2 * .pi * f * Double(i) / sr)) }
        }
        return signal
    }

    /// Feed a whole section through the detector and return the final verdict.
    private func feed(_ detector: LiveDetector, _ signal: [Float], from start: Double) -> MatchResult {
        var pos = 0, time = start
        var last = MatchResult.silence
        while pos + n <= signal.count {
            last = detector.process(Array(signal[pos..<pos + n]), at: time).result
            pos += hop
            time += Double(hop) / sr
        }
        return last
    }

    func testCorrectThenWrongThenSilence() {
        let detector = LiveDetector(sampleRate: sr, frameSize: n)
        detector.target = .chord(Chord(root: .c, quality: .major))

        let cMajor = tone([261.63, 329.63, 392.00], seconds: 0.6)   // expected
        let dMajor = tone([293.66, 369.99, 440.00], seconds: 0.6)   // wrong
        let silence = [Float](repeating: 0, count: Int(0.4 * sr))

        XCTAssertEqual(feed(detector, cMajor, from: 0), MatchResult.match)
        XCTAssertEqual(feed(detector, dMajor, from: 1), MatchResult.wrong)
        XCTAssertEqual(feed(detector, silence, from: 2), MatchResult.silence)
    }

    func testNoTargetReportsSilence() {
        let detector = LiveDetector(sampleRate: sr, frameSize: n)   // target nil
        let event = detector.process(tone([440], seconds: 0.1), at: 0)
        XCTAssertEqual(event.result, MatchResult.silence)
    }

    func testNoteTargetMatchesPlayedNote() {
        let detector = LiveDetector(sampleRate: sr, frameSize: n)
        detector.target = .note(Note(.a, 4))
        XCTAssertEqual(feed(detector, tone([440], seconds: 0.5), from: 0), MatchResult.match)
        detector.reset()
        XCTAssertEqual(feed(detector, tone([466.16], seconds: 0.5), from: 1), MatchResult.wrong) // A#4
    }
}
