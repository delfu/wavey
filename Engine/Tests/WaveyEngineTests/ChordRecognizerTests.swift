import XCTest
@testable import WaveyEngine
import Foundation

final class ChordRecognizerTests: XCTestCase {

    private let sr = 44100.0

    /// `seconds` of a chord built from pure sines at the given note frequencies.
    private func tone(_ frequencies: [Double], _ seconds: Double) -> [Float] {
        let count = Int(seconds * sr)
        var signal = [Float](repeating: 0, count: count)
        for f in frequencies {
            for i in 0..<count { signal[i] += Float(sin(2 * .pi * f * Double(i) / sr)) }
        }
        return signal
    }

    func testRecognizesProgression() {
        let recognizer = ChordRecognizer(sampleRate: sr)
        let signal = tone([261.63, 329.63, 392.00], 1.2)   // C major (C E G)
            + tone([392.00, 493.88, 587.33], 1.2)          // G major (G B D)
            + tone([440.00, 523.25, 659.25], 1.2)          // A minor (A C E)
        let chords = recognizer.recognize(signal).map(\.chord)
        XCTAssertEqual(chords, [
            Chord(root: .c, quality: .major),
            Chord(root: .g, quality: .major),
            Chord(root: .a, quality: .minor),
        ])
    }

    func testSingleSustainedChordIsOneSegment() {
        let recognizer = ChordRecognizer(sampleRate: sr)
        let result = recognizer.recognize(tone([261.63, 329.63, 392.00], 1.5))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.chord, Chord(root: .c, quality: .major))
        XCTAssertEqual(result.first?.start ?? -1, 0, accuracy: 0.1)
    }

    func testSilenceYieldsNoChords() {
        let recognizer = ChordRecognizer(sampleRate: sr)
        XCTAssertTrue(recognizer.recognize([Float](repeating: 0, count: Int(sr))).isEmpty)
    }

    func testSnapsSegmentStartsToBeats() {
        let recognizer = ChordRecognizer(sampleRate: sr)
        let signal = tone([261.63, 329.63, 392.00], 1.5)
        let beats = stride(from: 0.0, through: 1.5, by: 0.5).map { $0 }
        let result = recognizer.recognize(signal, snappingTo: beats)
        let start = try? XCTUnwrap(result.first?.start)
        // start should land exactly on one of the provided beats
        XCTAssertTrue(beats.contains { abs($0 - (start ?? -1)) < 1e-9 })
    }

    func testAbsorbsShortBlip() {
        let recognizer = ChordRecognizer(sampleRate: sr)
        let signal = tone([261.63, 329.63, 392.00], 1.0)   // C major
            + tone([369.99, 466.16, 554.37], 0.2)          // F# major — 0.2s blip
            + tone([261.63, 329.63, 392.00], 1.0)          // C major
        // the brief F# is shorter than minChordDuration → absorbed into its C neighbours.
        XCTAssertEqual(recognizer.recognize(signal).map(\.chord), [Chord(root: .c, quality: .major)])
    }

    func testEstimatesKeyFromPrimaryTriads() {
        var chroma = [Double](repeating: 0, count: 12)
        for triad in [[7, 11, 2], [0, 4, 7], [2, 6, 9]] {   // G, C, D = I/IV/V of G major
            for pc in triad { chroma[pc] += 1 }
        }
        let key = ChordRecognizer.estimateKey(chroma)
        XCTAssertEqual(key.root, .g)
        XCTAssertTrue(key.isMajor)
    }

    func testDiatonicChordsOfGMajor() {
        XCTAssertEqual(ChordRecognizer.diatonicChords(forKey: (.g, true)), [
            Chord(root: .g, quality: .major), Chord(root: .a, quality: .minor),
            Chord(root: .b, quality: .minor), Chord(root: .c, quality: .major),
            Chord(root: .d, quality: .major), Chord(root: .e, quality: .minor),
        ])
    }
}
