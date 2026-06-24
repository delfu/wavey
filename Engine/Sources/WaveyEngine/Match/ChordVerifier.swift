/// Verifies a stream of chroma frames against an EXPECTED chord — the chord half
/// of the verify-don't-recognize idea (we never ask "what chord is this?", only
/// "is this the chord we're waiting for?"). Scores cosine similarity to the
/// chord's pitch-class template, with frame stability. Partial voicings (a
/// muted/missing string) lower the score but won't necessarily fail the match.
///
/// Stateful and single-threaded by design.
public struct ChordVerifier {
    /// Minimum cosine similarity (0...1) to the chord template to count as a match.
    public var matchThreshold: Double
    /// Consecutive frames a verdict must hold before it's reported.
    public var framesToConfirm: Int

    private var candidate: MatchResult = .silence
    private var streak = 0
    private var confirmed: MatchResult = .silence

    public init(matchThreshold: Double = 0.7, framesToConfirm: Int = 3) {
        self.matchThreshold = matchThreshold
        self.framesToConfirm = framesToConfirm
    }

    /// Feed the expected chord and this frame's normalized chroma (nil = silence).
    public mutating func verify(expected: Chord, chroma: [Float]?) -> MatchResult {
        let instantaneous: MatchResult
        if let chroma {
            instantaneous = similarity(chroma: chroma, chord: expected) >= matchThreshold ? .match : .wrong
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

    /// Cosine similarity between the chroma and the chord's binary pitch-class template.
    private func similarity(chroma: [Float], chord: Chord) -> Double {
        var template = [Double](repeating: 0, count: 12)
        for pitchClass in chord.pitchClasses { template[pitchClass.rawValue] = 1 }

        var dot = 0.0, chromaNorm = 0.0, templateNorm = 0.0
        for i in 0..<min(12, chroma.count) {
            let c = Double(chroma[i])
            dot += c * template[i]
            chromaNorm += c * c
            templateNorm += template[i] * template[i]
        }
        guard chromaNorm > 0, templateNorm > 0 else { return 0 }
        return dot / (chromaNorm.squareRoot() * templateNorm.squareRoot())
    }
}
