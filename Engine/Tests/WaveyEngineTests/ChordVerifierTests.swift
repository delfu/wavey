import XCTest
@testable import WaveyEngine
import Foundation

final class ChordVerifierTests: XCTestCase {

    private let sr = 44100.0
    private let n = 4096

    /// Chroma for a chord built from pure sines at the given note frequencies.
    private func chroma(_ frequencies: [Double]) -> [Float] {
        var signal = [Float](repeating: 0, count: n)
        for f in frequencies {
            for i in 0..<n { signal[i] += Float(sin(2 * .pi * f * Double(i) / sr)) }
        }
        let mags = FFT(size: n)!.magnitudeSpectrum(Window.hann.applied(to: signal))
        return Chromagram(sampleRate: sr, fftSize: n).chroma(fromMagnitudes: mags)
    }

    // (chord, its note frequencies)
    private let openChords: [(Chord, [Double])] = [
        (Chord(root: .c, quality: .major), [261.63, 329.63, 392.00]), // C E G
        (Chord(root: .g, quality: .major), [392.00, 493.88, 587.33]), // G B D
        (Chord(root: .d, quality: .major), [293.66, 369.99, 440.00]), // D F# A
        (Chord(root: .e, quality: .minor), [329.63, 392.00, 493.88]), // E G B
        (Chord(root: .a, quality: .minor), [440.00, 523.25, 659.25]), // A C E
    ]

    func testEachOpenChordMatchesItself() {
        for (chord, freqs) in openChords {
            var v = ChordVerifier(framesToConfirm: 1)
            XCTAssertEqual(v.verify(expected: chord, chroma: chroma(freqs)), MatchResult.match, "\(chord) should match itself")
        }
    }

    func testWrongChordIsWrong() {
        var v = ChordVerifier(framesToConfirm: 1)
        let cMajor = chroma([261.63, 329.63, 392.00])  // C E G
        // Expecting D major (D F# A) — no shared tones with C major.
        XCTAssertEqual(v.verify(expected: Chord(root: .d, quality: .major), chroma: cMajor), MatchResult.wrong)
    }

    func testSilenceWhenNoChroma() {
        var v = ChordVerifier(framesToConfirm: 2)
        _ = v.verify(expected: Chord(root: .c, quality: .major), chroma: nil)
        XCTAssertEqual(v.verify(expected: Chord(root: .c, quality: .major), chroma: nil), MatchResult.silence)
    }

    func testRequiresStabilityBeforeConfirming() {
        var v = ChordVerifier(framesToConfirm: 3)
        let cMajor = chroma([261.63, 329.63, 392.00])
        let expected = Chord(root: .c, quality: .major)
        XCTAssertEqual(v.verify(expected: expected, chroma: cMajor), MatchResult.silence) // 1
        XCTAssertEqual(v.verify(expected: expected, chroma: cMajor), MatchResult.silence) // 2
        XCTAssertEqual(v.verify(expected: expected, chroma: cMajor), MatchResult.match)   // 3 confirms
    }
}
