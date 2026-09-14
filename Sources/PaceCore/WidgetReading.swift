import Darwin
import Foundation

/// A minimal export: widgets never need account identifiers, history, or Codex credentials.
public struct WidgetReading: Codable, Equatable, Sendable {
  public let dailyPercent: Double?
  public let weeklyPercent: Double
  public let bucketEnd: Date
  public let weeklyEnd: Date
  public let received: Date

  public init(projection: PaceProjection, snapshot: QuotaSnapshot) {
    dailyPercent = projection.dailyPercent
    weeklyPercent = projection.weeklyPercent
    bucketEnd = projection.end
    weeklyEnd = snapshot.reset
    received = snapshot.received
  }

  public func percent(weekly: Bool, at date: Date) -> Double? {
    let end = weekly ? weeklyEnd : bucketEnd
    guard date >= received, date < end, weeklyEnd >= bucketEnd,
      weeklyPercent.isFinite, (0...100).contains(weeklyPercent)
    else { return nil }
    let value = weekly ? weeklyPercent : dailyPercent
    guard let value, value.isFinite, value >= 0 else { return nil }
    return value
  }

  public static func countdown(until end: Date, at date: Date, weekly: Bool) -> String {
    let seconds = end.timeIntervalSince(date)
    guard seconds.isFinite, seconds > 0 else { return "Reset reached" }
    let minutes = Int(min(seconds / 60, 10080))
    if minutes == 0 { return "<1m until reset" }
    if weekly && minutes >= 1440 {
      return "\(minutes / 1440)d \(minutes % 1440 / 60)h \(minutes % 60)m until reset"
    }
    return "\(minutes / 60)h \(minutes % 60)m until reset"
  }
}

public enum WidgetReadingStore {
  public static func fileURL() throws -> URL {
    // A widget's Foundation home is its sandbox. Resolve the user's real home for the
    // narrowly entitled, read-only export directory shared with the ad-hoc-signed host app.
    guard let home = getpwuid(getuid())?.pointee.pw_dir else {
      throw CocoaError(.fileReadNoSuchFile)
    }
    return URL(fileURLWithPath: String(cString: home), isDirectory: true)
      .appendingPathComponent("Library/Application Support/Codex Pace/Widgets/snapshot.json")
  }
  public static func write(_ reading: WidgetReading?, to url: URL? = nil) throws {
    let target = try url ?? fileURL()
    try FileManager.default.createDirectory(
      at: target.deletingLastPathComponent(),
      withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try JSONEncoder().encode(reading).write(to: target, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
  }
  public static func read(from url: URL? = nil) throws -> WidgetReading? {
    let target = try url ?? fileURL()
    let data = try Data(contentsOf: target)
    guard data.count <= 16384 else { throw CocoaError(.fileReadCorruptFile) }
    return try JSONDecoder().decode(WidgetReading?.self, from: data)
  }
}
