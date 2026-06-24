import Foundation

/// A specific pitch: a ``PitchClass`` in a given octave, in scientific pitch
/// notation — middle C is C4 (MIDI 60) and A4 is 440 Hz.
public struct Note: Hashable, Codable, Sendable {
    public var pitchClass: PitchClass
    public var octave: Int

    public init(_ pitchClass: PitchClass, _ octave: Int) {
        self.pitchClass = pitchClass
        self.octave = octave
    }
}

public extension Note {
    /// MIDI note number (C4 = 60, A4 = 69).
    var midiNumber: Int { (octave + 1) * 12 + pitchClass.rawValue }

    /// Build a note from a MIDI note number.
    init(midiNumber: Int) {
        let pc = ((midiNumber % 12) + 12) % 12
        let octave = (midiNumber - pc) / 12 - 1
        self.init(PitchClass(rawValue: pc)!, octave)
    }

    /// Fundamental frequency in Hz (12-TET, A4 = 440 Hz).
    var frequency: Double {
        440.0 * pow(2.0, Double(midiNumber - 69) / 12.0)
    }

    /// Name in scientific pitch notation, e.g. "A4", "E2".
    var name: String { "\(pitchClass.name)\(octave)" }

    /// The note closest to a frequency plus the signed deviation in cents
    /// (positive means the frequency is sharp of the returned note).
    static func nearest(toFrequency frequency: Double) -> (note: Note, cents: Double) {
        precondition(frequency > 0, "frequency must be positive")
        let midiExact = 69.0 + 12.0 * log2(frequency / 440.0)
        let nearestMidi = Int(midiExact.rounded())
        let cents = (midiExact - Double(nearestMidi)) * 100.0
        return (Note(midiNumber: nearestMidi), cents)
    }
}
