import XCTest
@testable import WaveyEngine
import Foundation

final class IngestionPipelineTests: XCTestCase {

    private let sr = 44100.0

    private func tone(_ frequencies: [Double], _ seconds: Double) -> [Float] {
        let count = Int(seconds * sr)
        var signal = [Float](repeating: 0, count: count)
        for f in frequencies {
            for i in 0..<count { signal[i] += Float(sin(2 * .pi * f * Double(i) / sr)) }
        }
        return signal
    }

    func testMakesChordSheetFromGuitarAudio() {
        let pipeline = IngestionPipeline(sampleRate: sr)
        let signal = tone([261.63, 329.63, 392.00], 1.2)   // C major
            + tone([392.00, 493.88, 587.33], 1.2)          // G major
            + tone([440.00, 523.25, 659.25], 1.2)          // A minor

        var stages: [IngestionPipeline.Stage] = []
        let sheet = pipeline.makeSheet(from: signal, title: "Test Song") { stages.append($0) }

        let chords = sheet.events.compactMap { event -> Chord? in
            if case .chord(let chord) = event.payload { return chord }
            return nil
        }
        XCTAssertEqual(chords, [
            Chord(root: .c, quality: .major),
            Chord(root: .g, quality: .major),
            Chord(root: .a, quality: .minor),
        ])
        XCTAssertEqual(sheet.title, "Test Song")
        XCTAssertEqual(sheet.duration, 3.6, accuracy: 0.1)
        XCTAssertEqual(stages, [.separating, .beats, .chords, .done])
    }

    func testPassthroughSeparatorReturnsInput() {
        let samples: [Float] = [1, 2, 3, 4]
        XCTAssertEqual(PassthroughSeparator().separate(samples, sampleRate: sr), samples)
    }
}
