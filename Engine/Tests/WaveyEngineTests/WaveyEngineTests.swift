import XCTest
@testable import WaveyEngine

final class WaveyEngineTests: XCTestCase {
    /// Smoke test: the package compiles, links, and is reachable from tests.
    func testVersionIsSet() {
        XCTAssertFalse(WaveyEngine.version.isEmpty)
    }
}
