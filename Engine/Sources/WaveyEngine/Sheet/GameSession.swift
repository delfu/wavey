/// Walks a ``Sheet`` from live detection verdicts: advances to the next event on
/// a correct attempt, flags a wrong one, and reports progress. Pure logic — no
/// audio, no UI. The app feeds it `DetectionEvent.result` and sets the live
/// detector's target to `currentEvent`.
public struct GameSession {
    public let sheet: Sheet
    /// Cursor into `sheet.events`; equals `events.count` when finished.
    public private(set) var index: Int = 0
    /// True if the most recent attempt was the wrong note/chord.
    public private(set) var lastWasWrong = false
    public private(set) var isFinished: Bool

    private var previous: MatchResult = .silence

    public init(sheet: Sheet) {
        self.sheet = sheet
        self.isFinished = sheet.events.isEmpty
    }

    /// The event the player should be attempting now (nil once finished).
    public var currentEvent: SheetEvent? {
        index < sheet.events.count ? sheet.events[index] : nil
    }

    /// The events still ahead of the cursor.
    public var upcomingEvents: ArraySlice<SheetEvent> {
        sheet.events[min(index + 1, sheet.events.count)...]
    }

    /// Fraction of the sheet completed, 0...1.
    public var progress: Double {
        sheet.events.isEmpty ? 1 : Double(index) / Double(sheet.events.count)
    }

    /// Consume one detection verdict. Advances on the rising edge of `.match`
    /// (so holding a correct chord advances exactly once), flags on `.wrong`.
    public mutating func consume(_ result: MatchResult) {
        guard !isFinished else { return }
        defer { previous = result }
        switch result {
        case .match:
            guard previous != .match else { return }   // one advance per attempt
            index += 1
            lastWasWrong = false
            if index >= sheet.events.count { isFinished = true }
        case .wrong:
            lastWasWrong = true
        case .silence:
            break
        }
    }
}
