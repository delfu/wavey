import XCTest
@testable import WaveyEngine

final class FrameAccumulatorTests: XCTestCase {

    func testIrregularInputsProduceContiguousFrames() {
        var acc = FrameAccumulator(frameSize: 4)        // hop defaults to 4 (no overlap)
        let input: [Float] = (0..<16).map(Float.init)

        var out: [[Float]] = []
        out += acc.push(Array(input[0..<3]))            // 3
        out += acc.push(Array(input[3..<8]))            // 5
        out += acc.push(Array(input[8..<9]))            // 1
        out += acc.push(Array(input[9..<16]))           // 7

        XCTAssertEqual(out.count, 4)
        XCTAssertEqual(out[0], [0, 1, 2, 3])
        // No samples dropped or duplicated, original order preserved.
        XCTAssertEqual(out.flatMap { $0 }, input)
    }

    func testRemainderIsBufferedNotDropped() {
        var acc = FrameAccumulator(frameSize: 4)
        XCTAssertTrue(acc.push([1, 2, 3]).isEmpty)            // not enough yet
        XCTAssertEqual(acc.push([4, 5]), [[1, 2, 3, 4]])      // emits one; 5 retained
        XCTAssertEqual(acc.push([6, 7, 8]), [[5, 6, 7, 8]])   // continues from retained 5
    }

    func testOverlappingHop() {
        var acc = FrameAccumulator(frameSize: 4, hop: 2)
        let frames = acc.push((0..<8).map(Float.init))
        XCTAssertEqual(frames, [[0, 1, 2, 3], [2, 3, 4, 5], [4, 5, 6, 7]])
    }

    func testResetClearsBuffer() {
        var acc = FrameAccumulator(frameSize: 4)
        _ = acc.push([1, 2, 3])
        acc.reset()
        XCTAssertTrue(acc.push([9, 9, 9]).isEmpty)            // prior 1,2,3 gone
        XCTAssertEqual(acc.push([9]), [[9, 9, 9, 9]])
    }
}
