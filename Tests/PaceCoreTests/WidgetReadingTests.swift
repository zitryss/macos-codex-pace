import XCTest

@testable import PaceCore

final class WidgetReadingTests: XCTestCase {
  func testExportMatchesPacingAndExpiresAtEachBoundary() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let snapshot = QuotaSnapshot(
      account: "private", bucket: "codex", remaining: 90,
      reset: now.addingTimeInterval(5 * 86400 + 3600), received: now)
    let projection = try XCTUnwrap(Pacing.project(snapshot, history: [], now: now))
    let reading = WidgetReading(projection: projection, snapshot: snapshot)
    XCTAssertEqual(reading.percent(weekly: false, at: now), projection.dailyPercent)
    XCTAssertGreaterThan(try XCTUnwrap(reading.dailyPercent), 100)
    XCTAssertEqual(reading.percent(weekly: true, at: now), 90)
    XCTAssertNil(reading.percent(weekly: false, at: reading.bucketEnd))
    XCTAssertEqual(reading.percent(weekly: true, at: reading.bucketEnd), 90)
    XCTAssertNil(reading.percent(weekly: true, at: reading.weeklyEnd))
    XCTAssertNil(reading.percent(weekly: false, at: now.addingTimeInterval(-1)))
    let json = String(decoding: try JSONEncoder().encode(reading), as: UTF8.self)
    XCTAssertFalse(json.contains("private"))
    XCTAssertFalse(json.contains("codex"))
  }
  func testCountdownUsesElapsedTimeAndHandlesExpiry() {
    let now = Date()
    XCTAssertEqual(
      WidgetReading.countdown(until: now.addingTimeInterval(86400), at: now, weekly: false),
      "24h 0m until reset")
    XCTAssertEqual(
      WidgetReading.countdown(until: now.addingTimeInterval(90060), at: now, weekly: true),
      "1d 1h 1m until reset")
    XCTAssertEqual(
      WidgetReading.countdown(until: now.addingTimeInterval(15), at: now, weekly: false),
      "<1m until reset")
    XCTAssertEqual(WidgetReading.countdown(until: now, at: now, weekly: false), "Reset reached")
  }
  func testStoreRoundTripAndInvalidation() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("snapshot.json")
    let now = Date()
    let snapshot = QuotaSnapshot(
      account: "a", bucket: "b", remaining: 84,
      reset: now.addingTimeInterval(604000), received: now)
    let reading = WidgetReading(
      projection: try XCTUnwrap(Pacing.project(snapshot, history: [], now: now)), snapshot: snapshot
    )
    try WidgetReadingStore.write(reading, to: url)
    XCTAssertEqual(try WidgetReadingStore.read(from: url), reading)
    try WidgetReadingStore.write(nil, to: url)
    XCTAssertNil(try WidgetReadingStore.read(from: url))
    try Data("invalid".utf8).write(to: url)
    XCTAssertThrowsError(try WidgetReadingStore.read(from: url))
  }
}
