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

public struct PaceProjection: Sendable {
  public var available: Double
  public var dailyPercent: Double?
  public var weeklyPercent: Double
  public var end: Date
  public var standardPlan: Bool
  public var correction: Bool
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
    let boundary = snapshot.boundary(active)
    let opening = samples.first {
      $0.requested >= boundary && $0.received >= $0.requested
        && $0.received.timeIntervalSince(boundary) <= 60
    }
    let reserve = Double(6 - active) * base
    let available = max(0, snapshot.remaining - reserve)
    let allocation = opening.map { max(0, $0.remaining - reserve) } ?? base
    let correction = zip(samples, samples.dropFirst()).contains { $1.remaining > $0.remaining }
    return PaceProjection(
      available: available, dailyPercent: allocation > 0 ? 100 * available / allocation : nil,
      weeklyPercent: snapshot.remaining, end: snapshot.boundary(active + 1),
      standardPlan: opening == nil, correction: correction)
  }
}
