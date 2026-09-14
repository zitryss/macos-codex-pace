import XCTest

@testable import PaceCore

final class PacingTests: XCTestCase {
  let start = Date(timeIntervalSince1970: 1_789_205_160)
  func snapshot(_ remaining: Double, at offset: Double, account: String = "a") -> QuotaSnapshot {
    QuotaSnapshot(
      account: account, bucket: "codex", remaining: remaining,
      reset: start.addingTimeInterval(604800), received: start.addingTimeInterval(offset))
  }
  func testFallbackPrecisionAndCarryover() {
    for (remaining, available, daily, used) in [
      (86.0, "14", 102.0, "0"), (90, "18", 130, "0"), (80, "8", 60, "5"),
    ] {
      let s = snapshot(remaining, at: 87000)
      let p = Pacing.project(s, history: [s], now: s.received)!
      XCTAssertEqual(Pacing.whole(p.available), available)
      XCTAssertEqual(p.dailyPercent!, daily, accuracy: 1e-8)
      XCTAssertEqual(Pacing.whole(p.records[1].used), used)
      XCTAssertTrue(p.standardPlan)
      XCTAssertEqual(p.records.compactMap(\.used).reduce(0, +), 100 - remaining, accuracy: 1e-8)
    }
  }
  func testNearBoundarySamplingImprovesWithoutExactTimestamp() {
    let opening = snapshot(90, at: 86405)
    let current = snapshot(86, at: 88000)
    let p = Pacing.project(current, history: [opening, current], now: current.received)!
    XCTAssertFalse(p.standardPlan)
    XCTAssertEqual(p.records[1].used, 4)
    XCTAssertEqual(p.records[1].plan, 130.0 / 7, accuracy: 1e-8)
    XCTAssertEqual(
      Pacing.project(opening, history: [opening], now: opening.received)!.dailyPercent, 100)
    XCTAssertTrue(p.records[1].estimated)
  }
  func testNoLateOpeningAndAccountIsolation() {
    let late = snapshot(90, at: 86461)
    let current = snapshot(86, at: 88000)
    XCTAssertTrue(
      Pacing.project(current, history: [late, current], now: current.received)!.standardPlan)
    let other = snapshot(90, at: 86405, account: "other")
    XCTAssertTrue(
      Pacing.project(current, history: [other, current], now: current.received)!.standardPlan)
  }
  func testBoundariesAndExpiry() {
    let s = snapshot(100, at: 0)
    XCTAssertEqual(s.index(at: start), 0)
    XCTAssertEqual(s.index(at: start.addingTimeInterval(86400)), 1)
    XCTAssertEqual(s.index(at: s.reset.addingTimeInterval(-0.1)), 6)
    XCTAssertNil(s.index(at: s.reset))
    XCTAssertNil(Pacing.project(s, history: [], now: s.reset))
    XCTAssertEqual(Pacing.whole(100.0 / 7 * 7), "100")
    XCTAssertEqual(Pacing.whole(-1), "—")
  }
  func testCalendarOverlapAndMidnight() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    let begin = calendar.date(
      from: DateComponents(year: 2026, month: 9, day: 12, hour: 10, minute: 26))!
    let s = QuotaSnapshot(
      account: "a", bucket: "codex", remaining: 86, reset: begin.addingTimeInterval(604800),
      received: begin.addingTimeInterval(90000))
    let p = Pacing.project(s, history: [], now: s.received)
    let days = PaceCalendar.days(snapshot: s, projection: p, now: s.received, calendar: calendar)
    XCTAssertEqual(days.filter(\.inWeek).map(\.number), Array(12...19))
    XCTAssertEqual(days.filter(\.inBucket).map(\.number), [13, 14])
    XCTAssertEqual(days.flatMap(\.records).count, 7)
    XCTAssertEqual(days.filter(\.today).count, 1)
    let midnight = calendar.startOfDay(for: begin)
    let m = QuotaSnapshot(
      account: "a", bucket: "codex", remaining: 100, reset: midnight.addingTimeInterval(604800),
      received: midnight)
    XCTAssertEqual(
      PaceCalendar.days(snapshot: m, projection: nil, now: midnight, calendar: calendar).filter(
        \.inWeek
      ).count, 7)
  }
  func testCorrectionDoesNotInventHistoricalUsage() {
    let before = snapshot(80, at: 170000)
    let now = snapshot(90, at: 175000)
    let p = Pacing.project(now, history: [before, now], now: now.received)!
    XCTAssertTrue(p.correction)
    XCTAssertNil(p.records[0].used)
  }
  func testParseRequiresExplicitQuotaChoiceAndValidData() throws {
    let received = Date()
    let reset = received.addingTimeInterval(604000).timeIntervalSince1970
    let window: [String: Any] = ["windowDurationMins": 10080, "usedPercent": 14, "resetsAt": reset]
    let result: [String: Any] = [
      "accountId": "secret-id",
      "rateLimitsByLimitId": ["codex": ["secondary": window], "other": ["primary": window]],
      "rateLimitResetCredits": ["availableCount": 2],
    ]
    let options = try CodexClient.parse(
      account: ["type": "chatgpt"], result: result, requested: received, received: received)
    XCTAssertEqual(options.count, 2)
    XCTAssertEqual(options[0].snapshot.remaining, 86)
    XCTAssertEqual(options[0].snapshot.resetCredits, 2)
    XCTAssertNotEqual(options[0].snapshot.account, "secret-id")
    XCTAssertThrowsError(
      try CodexClient.parse(
        account: ["type": "apiKey"], result: result, requested: received, received: received))
    XCTAssertThrowsError(
      try CodexClient.parse(
        account: ["type": "chatgpt"], result: [:], requested: received, received: received))
  }
}
