import SwiftUI
import WidgetKit

struct QuotaEntry: TimelineEntry {
  let date: Date
  let reading: WidgetReading?
}

struct QuotaProvider: TimelineProvider {
  func placeholder(in context: Context) -> QuotaEntry {
    let now = Date()
    let snapshot = QuotaSnapshot(
      account: "preview", bucket: "preview", remaining: 84,
      reset: now.addingTimeInterval(5 * 86400 + 21600), received: now)
    let projection = Pacing.project(snapshot, history: [], now: now)!
    return QuotaEntry(
      date: now, reading: WidgetReading(projection: projection, snapshot: snapshot))
  }
  func getSnapshot(in context: Context, completion: @escaping (QuotaEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaEntry>) -> Void) {
    let now = Date()
    let reading = try? WidgetReadingStore.read()
    var dates = (0...60).map { now.addingTimeInterval(Double($0) * 60) }
    // Include exact expiry instants so an old grant is never displayed as a fresh one.
    if let reading {
      dates += [reading.bucketEnd, reading.weeklyEnd].filter {
        $0 > now
      }
    }
    let entries = Set(dates).sorted().map { QuotaEntry(date: $0, reading: reading) }
    completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(300))))
  }
  private func entry(at date: Date) -> QuotaEntry {
    QuotaEntry(date: date, reading: try? WidgetReadingStore.read())
  }
}

struct Speedometer: View {
  let value: Double?
  private var fraction: Double { min(1, max(0, (value ?? 0) / 100)) }
  var body: some View {
    GeometryReader { geometry in
      let radius = min(geometry.size.width / 2 - 10, geometry.size.height - 17)
      let center = CGPoint(x: geometry.size.width / 2, y: radius + 4)
      Canvas { context, _ in
        var arc = Path()
        arc.addArc(
          center: center, radius: radius, startAngle: .degrees(180),
          endAngle: .degrees(360), clockwise: false)
        context.stroke(
          arc, with: .color(.secondary.opacity(0.2)),
          style: StrokeStyle(lineWidth: 8, lineCap: .round))
        if value != nil {
          var fill = Path()
          fill.addArc(
            center: center, radius: radius, startAngle: .degrees(180),
            endAngle: .degrees(180 + 180 * fraction), clockwise: false)
          let color = Color(hue: fraction / 3, saturation: 0.7, brightness: 0.8)
          context.stroke(
            fill, with: .color(color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
          let angle = Double.pi * (1 + fraction)
          var needle = Path()
          needle.move(to: center)
          needle.addLine(
            to: CGPoint(
              x: center.x + cos(angle) * (radius - 12),
              y: center.y + sin(angle) * (radius - 12)))
          context.stroke(
            needle, with: .color(.primary), style: StrokeStyle(lineWidth: 2, lineCap: .round))
          context.fill(
            Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
            with: .color(.primary))
        }
      }
      HStack {
        Text("0")
        Spacer()
        Text("100")
      }.font(.system(size: 9)).foregroundStyle(.secondary)
        .position(x: center.x, y: center.y + 12)
    }.accessibilityHidden(true)
  }
}

struct QuotaWidgetView: View {
  let entry: QuotaEntry
  let weekly: Bool
  var body: some View {
    let value = entry.reading?.percent(weekly: weekly, at: entry.date)
    VStack(spacing: 4) {
      Text(weekly ? "Weekly quota" : "Today's quota").font(.caption.weight(.semibold))
      Speedometer(value: value).frame(height: 66)
      Text(value.map { "\(Pacing.whole($0))%" } ?? "—")
        .font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
      if let reading = entry.reading {
        Text(
          WidgetReading.countdown(
            until: weekly ? reading.weeklyEnd : reading.bucketEnd,
            at: entry.date, weekly: weekly)
        )
        .font(.system(size: 10)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        if entry.date.timeIntervalSince(reading.received) >= 600 || value == nil {
          Text(value == nil ? "Open Codex Pace to refresh" : "Older reading · tap to refresh").font(
            .system(size: 9)
          ).foregroundStyle(.secondary)
        }
      } else {
        Text("Open Codex Pace to connect").font(.system(size: 10)).foregroundStyle(.secondary)
      }
    }
    .containerBackground(.fill.tertiary, for: .widget)
    .widgetURL(URL(string: "codex-pace://open"))
    .accessibilityElement(children: .combine)
  }
}

struct DailyQuotaWidget: Widget {
  let kind = "CodexPaceDaily"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: QuotaProvider()) {
      QuotaWidgetView(entry: $0, weekly: false)
    }
    .configurationDisplayName("Daily Quota")
    .description("Your daily pacing quota and time until the next bucket reset.")
    .supportedFamilies([.systemSmall])
  }
}
struct WeeklyQuotaWidget: Widget {
  let kind = "CodexPaceWeekly"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: QuotaProvider()) {
      QuotaWidgetView(entry: $0, weekly: true)
    }
    .configurationDisplayName("Weekly Quota")
    .description("Your remaining weekly quota and time until the weekly reset.")
    .supportedFamilies([.systemSmall])
  }
}
@main
struct PaceWidgets: WidgetBundle {
  var body: some Widget {
    DailyQuotaWidget()
    WeeklyQuotaWidget()
  }
}
