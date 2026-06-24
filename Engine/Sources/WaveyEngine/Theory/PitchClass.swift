/// One of the twelve pitch classes in 12-tone equal temperament, with C = 0.
///
/// Raw values are MIDI semitone offsets within an octave, so MIDI and frequency
/// math stay trivial. Spelled with sharps only — enharmonic flats are out of
/// scope for v1.
public enum PitchClass: Int, CaseIterable, Codable, Hashable, Sendable {
    case c = 0
    case cSharp
    case d
    case dSharp
    case e
    case f
    case fSharp
    case g
    case gSharp
    case a
    case aSharp
    case b

    /// Display name, e.g. "C", "C#".
    public var name: String {
        switch self {
        case .c: "C"
        case .cSharp: "C#"
        case .d: "D"
        case .dSharp: "D#"
        case .e: "E"
        case .f: "F"
        case .fSharp: "F#"
        case .g: "G"
        case .gSharp: "G#"
        case .a: "A"
        case .aSharp: "A#"
        case .b: "B"
        }
    }

    /// This pitch class shifted by a number of semitones, wrapping within the octave.
    public func transposed(by semitones: Int) -> PitchClass {
        PitchClass(rawValue: ((rawValue + semitones) % 12 + 12) % 12)!
    }
}

public extension PitchClass {
    /// Inverse of ``name`` — e.g. "C#" → `.cSharp`. Returns nil for unknown names.
    init?(name: String) {
        guard let match = Self.allCases.first(where: { $0.name == name }) else { return nil }
        self = match
    }
}

// Serialized as the note name ("C", "F#") so sheets stay hand-authorable.
extension PitchClass {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        guard let pitchClass = PitchClass(name: name) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "unknown pitch class \"\(name)\""
            )
        }
        self = pitchClass
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}
