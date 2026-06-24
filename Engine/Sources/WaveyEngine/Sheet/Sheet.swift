/// A playable chart: ordered timed events plus tempo and length metadata.
///
/// Events are kept in ascending `time` order. One JSON format is shared by
/// hand-authored sheets and pipeline-generated ones.
public struct Sheet: Hashable, Codable, Sendable {
    public var title: String
    /// Tempo in beats per minute. Event times are in seconds; bpm lets UIs derive beats.
    public var bpm: Double
    /// Total length in seconds (may extend past the last event for trailing space).
    public var duration: Double
    public var events: [SheetEvent]

    public init(title: String, bpm: Double, duration: Double, events: [SheetEvent]) {
        self.title = title
        self.bpm = bpm
        self.duration = duration
        self.events = events
    }
}

public extension Sheet {
    /// The event active at `time` — start inclusive, end exclusive — or nil.
    func event(at time: Double) -> SheetEvent? {
        events.first { time >= $0.time && time < $0.time + $0.duration }
    }

    /// The first event that starts strictly after `time`, or nil.
    func nextEvent(after time: Double) -> SheetEvent? {
        events.first { $0.time > time }
    }
}
