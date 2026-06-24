import Foundation

/// Verifies a stream of detected pitches against an EXPECTED note — the single-
/// note half of the live-detection idea (we never ask "what note is this?",
/// only "is this the note we're waiting for?"). Requires the verdict to hold for
/// a few frames before reporting it, to avoid flicker.
///
/// Stateful and single-threaded by design.
public struct NoteVerifier {
    /// How many cents the detected pitch may deviate from the expected note.
    public var toleranceCents: Double
    /// If true, any octave of the expected pitch class counts (open-string
    /// tuning vs. fretted positions); if false the octave must match exactly.
    public var octaveTolerant: Bool
    /// Consecutive frames a verdict must hold before it's reported.
    public var framesToConfirm: Int

    private var candidate: MatchResult = .silence
    private var streak = 0
    private var confirmed: MatchResult = .silence

    public init(toleranceCents: Double = 50, octaveTolerant: Bool = true, framesToConfirm: Int = 3) {
        self.toleranceCents = toleranceCents
        self.octaveTolerant = octaveTolerant
        self.framesToConfirm = framesToConfirm
    }

    /// Feed the expected note and this frame's detected pitch (nil = no pitch).
    public mutating func verify(expected: Note, pitch: PitchResult?) -> MatchResult {
        let instantaneous: MatchResult
        if let pitch {
            instantaneous = matches(expected: expected, frequency: pitch.frequency) ? .match : .wrong
        } else {
            instantaneous = .silence
        }

        if instantaneous == candidate {
            streak += 1
        } else {
            candidate = instantaneous
            streak = 1
        }
        if streak >= framesToConfirm {
            confirmed = candidate
        }
        return confirmed
    }

    public mutating func reset() {
        candidate = .silence
        streak = 0
        confirmed = .silence
    }

    /// Is `frequency` within tolerance of the expected note (octave-folded if tolerant)?
    private func matches(expected: Note, frequency: Double) -> Bool {
        let detectedMidi = 69.0 + 12.0 * log2(frequency / 440.0)
        var diffSemitones = detectedMidi - Double(expected.midiNumber)
        if octaveTolerant {
            diffSemitones = diffSemitones.truncatingRemainder(dividingBy: 12)
            if diffSemitones > 6 { diffSemitones -= 12 }
            if diffSemitones < -6 { diffSemitones += 12 }
        }
        return abs(diffSemitones * 100) <= toleranceCents
    }
}
