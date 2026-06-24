/// The quality of a chord — the interval pattern stacked on its root.
///
/// Raw values are stable, human-readable tags used in serialized sheets.
public enum ChordQuality: String, CaseIterable, Codable, Hashable, Sendable {
    case major = "maj"
    case minor = "min"
    case dominant7 = "dom7"
    case major7 = "maj7"
    case minor7 = "min7"
    case sus2
    case sus4
    case diminished = "dim"
    case augmented = "aug"

    /// Semitone offsets from the root that make up the chord.
    public var intervals: [Int] {
        switch self {
        case .major: [0, 4, 7]
        case .minor: [0, 3, 7]
        case .dominant7: [0, 4, 7, 10]
        case .major7: [0, 4, 7, 11]
        case .minor7: [0, 3, 7, 10]
        case .sus2: [0, 2, 7]
        case .sus4: [0, 5, 7]
        case .diminished: [0, 3, 6]
        case .augmented: [0, 4, 8]
        }
    }

    /// Symbol appended to the root to name the chord, e.g. "" (major), "m", "7".
    public var symbol: String {
        switch self {
        case .major: ""
        case .minor: "m"
        case .dominant7: "7"
        case .major7: "maj7"
        case .minor7: "m7"
        case .sus2: "sus2"
        case .sus4: "sus4"
        case .diminished: "dim"
        case .augmented: "aug"
        }
    }
}

/// A chord: a root pitch class and a quality, with an optional concrete voicing
/// (the actual notes as fingered, e.g. an open-position shape). The voicing does
/// not affect ``pitchClasses``.
public struct Chord: Hashable, Codable, Sendable, CustomStringConvertible {
    public var root: PitchClass
    public var quality: ChordQuality
    public var voicing: [Note]?

    public init(root: PitchClass, quality: ChordQuality, voicing: [Note]? = nil) {
        self.root = root
        self.quality = quality
        self.voicing = voicing
    }

    /// The set of pitch classes the chord contains (voicing-independent).
    public var pitchClasses: Set<PitchClass> {
        Set(quality.intervals.map { root.transposed(by: $0) })
    }

    /// Readable name, e.g. "C", "Am", "G7".
    public var description: String { "\(root.name)\(quality.symbol)" }
}
