import XCTest

@testable import PaceCore

final class ConnectionTests: XCTestCase {
  func testLiveReadOnlyConnectionWhenRequested() throws {
    guard ProcessInfo.processInfo.environment["CODEX_PACE_LIVE_TEST"] == "1" else {
      throw XCTSkip("Opt-in live read-only connection check")
    }
    let path = try XCTUnwrap(CodexClient.executable())
    let options = try CodexClient.collect(path: path)
    XCTAssertFalse(options.isEmpty)
    XCTAssertTrue(options.allSatisfy { (0...100).contains($0.snapshot.remaining) })
    XCTAssertTrue(options.allSatisfy { $0.snapshot.reset > $0.snapshot.received })
  }
}
