import XCTest
@testable import WaveyEngine

final class GameSessionTests: XCTestCase {

    private func sheet(_ count: Int) -> Sheet {
        let chords: [Chord] = [
            Chord(root: .c, quality: .major),
            Chord(root: .g, quality: .major),
            Chord(root: .a, quality: .minor),
        ]
        let events = (0..<count).map { i in
            SheetEvent(time: Double(i) * 2, duration: 2, payload: .chord(chords[i % chords.count]))
        }
        return Sheet(title: "test", bpm: 120, duration: Double(count) * 2, events: events)
    }

    func testWalksToEndOnCorrectSequence() {
        var s = GameSession(sheet: sheet(3))
        for _ in 0..<3 {
            s.consume(.match)     // advance
            s.consume(.silence)   // release before the next attempt (resets the edge)
        }
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.index, 3)
        XCTAssertEqual(s.progress, 1, accuracy: 1e-9)
    }

    func testHeldMatchAdvancesOnce() {
        var s = GameSession(sheet: sheet(3))
        s.consume(.match)
        s.consume(.match)   // still held → no second advance
        s.consume(.match)
        XCTAssertEqual(s.index, 1)
    }

    func testWrongFlagsWithoutAdvancing() {
        var s = GameSession(sheet: sheet(3))
        s.consume(.wrong)
        XCTAssertEqual(s.index, 0)
        XCTAssertTrue(s.lastWasWrong)
        s.consume(.match)             // recover
        XCTAssertEqual(s.index, 1)
        XCTAssertFalse(s.lastWasWrong)
    }

    func testCurrentAndUpcoming() {
        let full = sheet(3)
        let s = GameSession(sheet: full)
        XCTAssertEqual(s.currentEvent, full.events[0])
        XCTAssertEqual(Array(s.upcomingEvents), Array(full.events[1...]))
    }

    func testIgnoresVerdictsAfterFinished() {
        var s = GameSession(sheet: sheet(1))
        s.consume(.match)             // advance to 1 → finished
        XCTAssertTrue(s.isFinished)
        s.consume(.match)             // ignored
        XCTAssertEqual(s.index, 1)
    }

    func testEmptySheetIsFinished() {
        let s = GameSession(sheet: sheet(0))
        XCTAssertTrue(s.isFinished)
        XCTAssertNil(s.currentEvent)
        XCTAssertEqual(s.progress, 1, accuracy: 1e-9)
    }
}
