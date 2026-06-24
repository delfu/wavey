import XCTest
@testable import WaveyEngine
import Foundation

final class TheoryTests: XCTestCase {

    // MARK: MIDI

    func testMidiNumbers() {
        XCTAssertEqual(Note(.c, 4).midiNumber, 60)
        XCTAssertEqual(Note(.a, 4).midiNumber, 69)
        XCTAssertEqual(Note(.e, 2).midiNumber, 40)
        XCTAssertEqual(Note(.e, 4).midiNumber, 64)
    }

    func testMidiRoundTrip() {
        for midi in 21...108 { // A0..C8
            XCTAssertEqual(Note(midiNumber: midi).midiNumber, midi)
        }
        XCTAssertEqual(Note(midiNumber: 69), Note(.a, 4))
        XCTAssertEqual(Note(midiNumber: 40), Note(.e, 2))
    }

    // MARK: Frequency

    func testFrequencies() {
        XCTAssertEqual(Note(.a, 4).frequency, 440.0, accuracy: 0.001)
        XCTAssertEqual(Note(.e, 2).frequency, 82.41, accuracy: 0.01)
        XCTAssertEqual(Note(.e, 4).frequency, 329.63, accuracy: 0.01)
    }

    func testNearestNoteRoundTrips() {
        let a4 = Note.nearest(toFrequency: 440.0)
        XCTAssertEqual(a4.note, Note(.a, 4))
        XCTAssertEqual(a4.cents, 0.0, accuracy: 0.01)

        let e2 = Note.nearest(toFrequency: 82.41)
        XCTAssertEqual(e2.note, Note(.e, 2))
        XCTAssertEqual(e2.cents, 0.0, accuracy: 0.5)

        let e4 = Note.nearest(toFrequency: 329.63)
        XCTAssertEqual(e4.note, Note(.e, 4))
        XCTAssertEqual(e4.cents, 0.0, accuracy: 0.5)
    }

    func testCentsSignAndMagnitude() {
        // ~+19.6 cents sharp of A4
        let sharp = Note.nearest(toFrequency: 445.0)
        XCTAssertEqual(sharp.note, Note(.a, 4))
        XCTAssertGreaterThan(sharp.cents, 0)
        XCTAssertEqual(sharp.cents, 19.56, accuracy: 0.5)

        // flat of A4
        let flat = Note.nearest(toFrequency: 435.0)
        XCTAssertEqual(flat.note, Note(.a, 4))
        XCTAssertLessThan(flat.cents, 0)

        // exactly +10 cents by construction
        let tenSharp = 440.0 * pow(2.0, 10.0 / 1200.0)
        XCTAssertEqual(Note.nearest(toFrequency: tenSharp).cents, 10.0, accuracy: 0.01)
    }

    // MARK: Chords

    func testChordPitchClasses() {
        XCTAssertEqual(Chord(root: .c, quality: .major).pitchClasses, [.c, .e, .g])
        XCTAssertEqual(Chord(root: .a, quality: .minor).pitchClasses, [.a, .c, .e])
        XCTAssertEqual(Chord(root: .g, quality: .dominant7).pitchClasses, [.g, .b, .d, .f])
        XCTAssertEqual(Chord(root: .d, quality: .sus4).pitchClasses, [.d, .g, .a])
        XCTAssertEqual(Chord(root: .c, quality: .diminished).pitchClasses, [.c, .dSharp, .fSharp])
    }

    func testChordNames() {
        XCTAssertEqual(Chord(root: .c, quality: .major).description, "C")
        XCTAssertEqual(Chord(root: .a, quality: .minor).description, "Am")
        XCTAssertEqual(Chord(root: .g, quality: .dominant7).description, "G7")
        XCTAssertEqual(Chord(root: .fSharp, quality: .minor7).description, "F#m7")
    }

    // MARK: Tuning

    func testStandardTuning() {
        let midis = StandardTuning.openStrings.map(\.midiNumber)
        XCTAssertEqual(midis, [40, 45, 50, 55, 59, 64])
        XCTAssertEqual(StandardTuning.openStrings.first?.frequency ?? 0, 82.41, accuracy: 0.01)
        XCTAssertEqual(StandardTuning.openStrings.last?.frequency ?? 0, 329.63, accuracy: 0.01)
    }

    // MARK: Transposition

    func testTransposeWraps() {
        XCTAssertEqual(PitchClass.b.transposed(by: 1), .c)
        XCTAssertEqual(PitchClass.c.transposed(by: -1), .b)
        XCTAssertEqual(PitchClass.c.transposed(by: 12), .c)
    }
}
