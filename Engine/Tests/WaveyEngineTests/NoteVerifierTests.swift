import XCTest
@testable import WaveyEngine

final class NoteVerifierTests: XCTestCase {

    private func pitch(_ f: Double) -> PitchResult { PitchResult(frequency: f, confidence: 0.99) }

    func testMatchesCorrectNote() {
        var v = NoteVerifier(framesToConfirm: 2)
        _ = v.verify(expected: Note(.a, 4), pitch: pitch(440))
        XCTAssertEqual(v.verify(expected: Note(.a, 4), pitch: pitch(440)), MatchResult.match)
    }

    func testSemitoneOffIsWrong() {
        var v = NoteVerifier(framesToConfirm: 2)
        _ = v.verify(expected: Note(.a, 4), pitch: pitch(466.16))   // A#4
        XCTAssertEqual(v.verify(expected: Note(.a, 4), pitch: pitch(466.16)), MatchResult.wrong)
    }

    func testOctaveTolerantMatchesOtherOctave() {
        var v = NoteVerifier(octaveTolerant: true, framesToConfirm: 2)
        _ = v.verify(expected: Note(.a, 4), pitch: pitch(220))      // A3
        XCTAssertEqual(v.verify(expected: Note(.a, 4), pitch: pitch(220)), MatchResult.match)
    }

    func testOctaveStrictRejectsOtherOctave() {
        var v = NoteVerifier(octaveTolerant: false, framesToConfirm: 2)
        _ = v.verify(expected: Note(.a, 4), pitch: pitch(220))
        XCTAssertEqual(v.verify(expected: Note(.a, 4), pitch: pitch(220)), MatchResult.wrong)
    }

    func testSilenceWhenNoPitch() {
        var v = NoteVerifier(framesToConfirm: 2)
        _ = v.verify(expected: Note(.a, 4), pitch: nil)
        XCTAssertEqual(v.verify(expected: Note(.a, 4), pitch: nil), MatchResult.silence)
    }

    func testRequiresStabilityBeforeConfirming() {
        var v = NoteVerifier(framesToConfirm: 3)
        XCTAssertEqual(v.verify(expected: Note(.a, 4), pitch: pitch(440)), MatchResult.silence) // 1
        XCTAssertEqual(v.verify(expected: Note(.a, 4), pitch: pitch(440)), MatchResult.silence) // 2
        XCTAssertEqual(v.verify(expected: Note(.a, 4), pitch: pitch(440)), MatchResult.match)   // 3 confirms
    }
}
