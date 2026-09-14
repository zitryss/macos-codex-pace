import Foundation

public struct QuotaSnapshot: Codable, Equatable, Sendable {
  public var account: String
  public var bucket: String
  public var remaining: Double
  public var reset: Date
  public var received: Date
  public var requested: Date
  public var resetCredits: Int?
  public var shortLimitReached: Bool
  public var start: Date { reset.addingTimeInterval(-604800) }
  public var identity: String { "\(account)|\(bucket)|\(reset.timeIntervalSince1970)" }
  public init(
    account: String, bucket: String, remaining: Double, reset: Date, received: Date,
    requested: Date? = nil, resetCredits: Int? = nil, shortLimitReached: Bool = false
  ) {
    self.account = account
    self.bucket = bucket
    self.remaining = remaining
    self.reset = reset
    self.received = received
    self.requested = requested ?? received
    self.resetCredits = resetCredits
    self.shortLimitReached = shortLimitReached
  }
  public func index(at date: Date) -> Int? {
    guard date >= start, date < reset else { return nil }
    return Int(date.timeIntervalSince(start) / 86400)
  }
  public func boundary(_ index: Int) -> Date { start.addingTimeInterval(Double(index) * 86400) }
}

public struct BucketPlan: Sendable {
  public var index: Int
  public var plan: Double
  public var used: Double?
  public var sampled: Bool
  public var estimated: Bool
}

public struct PaceProjection: Sendable {
  public var available: Double
  public var dailyPercent: Double?
  public var weeklyPercent: Double
  public var index: Int
  public var end: Date
  public var records: [BucketPlan]
  public var standardPlan: Bool
  public var correction: Bool
  public var daysLeft: Int { 6 - index }
}

public enum Pacing {
  public static let base = 100.0 / 7
  public static func whole(_ value: Double?) -> String {
    guard let value, value.isFinite, value >= 0, value < Double(Int.max) else { return "—" }
    return String(Int(floor(value + 1e-9)))
  }
  public static func project(_ snapshot: QuotaSnapshot, history: [QuotaSnapshot], now: Date)
    -> PaceProjection?
  {
    guard let active = snapshot.index(at: now) else { return nil }
    let samples = history.filter {
      $0.identity == snapshot.identity && $0.received <= snapshot.received && $0.received <= now
    }.sorted { $0.received < $1.received }
    // A bounded local sample is useful evidence, but never an exact provider boundary measurement.
    func opening(_ index: Int) -> QuotaSnapshot? {
      let boundary = snapshot.boundary(index)
      return samples.first {
        $0.requested >= boundary && $0.received >= $0.requested
          && $0.received.timeIntervalSince(boundary) <= 60
      }
    }
    var records = (0..<7).map { i -> BucketPlan in
      let open = opening(i)
      let reserve = Double(6 - i) * base
      let close = i == active ? snapshot : opening(i + 1)
      let used = open.flatMap { o in close.map { o.remaining - $0.remaining } }
      return BucketPlan(
        index: i, plan: open.map { max(0, $0.remaining - reserve) } ?? base,
        used: i <= active ? used : nil, sampled: open != nil, estimated: true)
    }
    let available = max(0, snapshot.remaining - Double(6 - active) * base)
    let standard = !records[active].sampled
    if standard { records[active].used = max(0, base - available) }
    let known = records.prefix(active).compactMap(\.used)
    let residual = 100 - snapshot.remaining - known.reduce(0, +) - (records[active].used ?? 0)
    let missing = (0..<active).filter { records[$0].used == nil }
    let correction = zip(samples, samples.dropFirst()).contains { $1.remaining > $0.remaining }
    if !correction, residual >= -1e-9, known.allSatisfy({ $0 >= 0 }),
      (records[active].used ?? 0) >= 0, !missing.isEmpty
    {
      for i in missing { records[i].used = max(0, residual) / Double(missing.count) }
    }
    let plan = records[active].plan
    return PaceProjection(
      available: available, dailyPercent: plan > 0 ? 100 * available / plan : nil,
      weeklyPercent: snapshot.remaining, index: active, end: snapshot.boundary(active + 1),
      records: records, standardPlan: standard, correction: correction)
  }
}

public struct CalendarDay: Identifiable, Sendable {
  public let date: Date
  public let number: Int
  public let inMonth: Bool
  public let inWeek: Bool
  public let inBucket: Bool
  public let today: Bool
  public let records: [BucketPlan]
  public var id: Date { date }
}

public enum PaceCalendar {
  public static func days(
    snapshot: QuotaSnapshot, projection: PaceProjection?, now: Date,
    calendar input: Calendar = .current
  ) -> [CalendarDay] {
    var calendar = input
    calendar.firstWeekday = 2
    guard let month = calendar.dateInterval(of: .month, for: now) else { return [] }
    let earliest = min(month.start, calendar.startOfDay(for: snapshot.start))
    let latest = max(month.end.addingTimeInterval(-1), snapshot.reset.addingTimeInterval(-0.001))
    guard let first = calendar.dateInterval(of: .weekOfYear, for: earliest)?.start,
      let last = calendar.dateInterval(of: .weekOfYear, for: latest)?.end
    else { return [] }
    var result: [CalendarDay] = []
    var day = first
    while day < last, result.count < 56 {
      guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
      func overlaps(_ start: Date, _ end: Date) -> Bool { max(day, start) < min(next, end) }
      let bucket = projection.map { overlaps(snapshot.boundary($0.index), $0.end) } ?? false
      let entries = (projection?.records ?? []).filter {
        calendar.isDate(snapshot.boundary($0.index), inSameDayAs: day)
      }
      result.append(
        CalendarDay(
          date: day, number: calendar.component(.day, from: day),
          inMonth: day >= month.start && day < month.end,
          inWeek: overlaps(snapshot.start, snapshot.reset), inBucket: bucket,
          today: calendar.isDate(day, inSameDayAs: now), records: entries))
      day = next
    }
    return result
  }
}
