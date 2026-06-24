import XCTest
@testable import WaveyEngine
import Foundation

final class SheetTests: XCTestCase {

    private func loadSample() throws -> Sheet {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "sample_sheet", withExtension: "json", subdirectory: "Resources")
                ?? Bundle.module.url(forResource: "sample_sheet", withExtension: "json"),
            "sample_sheet.json missing from test resources"
        )
        return try JSONDecoder().decode(Sheet.self, from: Data(contentsOf: url))
    }

    func testDecodeSample() throws {
        let sheet = try loadSample()
        XCTAssertEqual(sheet.title, "Sample Progression")
        XCTAssertEqual(sheet.bpm, 100, accuracy: 0.0001)
        XCTAssertEqual(sheet.duration, 8.0, accuracy: 0.0001)
        XCTAssertEqual(sheet.events.count, 5)

        XCTAssertEqual(sheet.events.first?.time, 0.0)
        XCTAssertEqual(sheet.events.first?.payload, .chord(Chord(root: .c, quality: .major)))

        XCTAssertEqual(sheet.events.last?.payload, .note(Note(.e, 4)))
        XCTAssertEqual(sheet.events.last?.duration, 0.5)
    }

    func testRoundTrip() throws {
        let sheet = try loadSample()
        let reencoded = try JSONEncoder().encode(sheet)
        let decoded = try JSONDecoder().decode(Sheet.self, from: reencoded)
        XCTAssertEqual(decoded, sheet)
    }

    func testEventAtBoundaries() throws {
        let sheet = try loadSample()
        XCTAssertEqual(sheet.event(at: 0.0)?.payload, .chord(Chord(root: .c, quality: .major)))
        XCTAssertEqual(sheet.event(at: 1.999)?.payload, .chord(Chord(root: .c, quality: .major)))
        XCTAssertEqual(sheet.event(at: 2.0)?.payload, .chord(Chord(root: .g, quality: .major)))   // start inclusive
        XCTAssertEqual(sheet.event(at: 5.9)?.payload, .chord(Chord(root: .a, quality: .minor)))
        XCTAssertEqual(sheet.event(at: 7.5)?.payload, .note(Note(.e, 4)))
        XCTAssertEqual(sheet.event(at: 7.99)?.payload, .note(Note(.e, 4)))
        XCTAssertNil(sheet.event(at: 8.0))    // end exclusive: the note ends at 8.0
        XCTAssertNil(sheet.event(at: 100.0))
    }

    func testNextEventAfter() throws {
        let sheet = try loadSample()
        XCTAssertEqual(sheet.nextEvent(after: -1.0)?.time, 0.0)
        XCTAssertEqual(sheet.nextEvent(after: 0.0)?.time, 2.0)   // strictly after
        XCTAssertEqual(sheet.nextEvent(after: 2.0)?.time, 4.0)
        XCTAssertEqual(sheet.nextEvent(after: 6.0)?.time, 7.5)
        XCTAssertNil(sheet.nextEvent(after: 7.5))
    }
}
