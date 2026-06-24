/// A single timed event on a ``Sheet`` — a chord or a single note to play,
/// positioned on the timeline in seconds.
public struct SheetEvent: Hashable, Sendable {
    /// What to play at this position.
    public enum Payload: Hashable, Sendable {
        case chord(Chord)
        case note(Note)
    }

    /// Start time from the beginning of the sheet, in seconds.
    public var time: Double
    /// How long the event lasts, in seconds.
    public var duration: Double
    public var payload: Payload

    public init(time: Double, duration: Double, payload: Payload) {
        self.time = time
        self.duration = duration
        self.payload = payload
    }
}

// Encoded with a `chord` or `note` key (never both) so the JSON reads cleanly
// and stays hand-authorable, delegating to Chord/Note's own representations.
extension SheetEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case time, duration, chord, note
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        time = try c.decode(Double.self, forKey: .time)
        duration = try c.decode(Double.self, forKey: .duration)
        if let chord = try c.decodeIfPresent(Chord.self, forKey: .chord) {
            payload = .chord(chord)
        } else if let note = try c.decodeIfPresent(Note.self, forKey: .note) {
            payload = .note(note)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: c.codingPath,
                      debugDescription: "a sheet event needs either a \"chord\" or a \"note\"")
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(time, forKey: .time)
        try c.encode(duration, forKey: .duration)
        switch payload {
        case .chord(let chord): try c.encode(chord, forKey: .chord)
        case .note(let note): try c.encode(note, forKey: .note)
        }
    }
}
