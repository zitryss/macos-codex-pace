import AppKit
import SwiftUI

#if canImport(PaceCore)
  import PaceCore
#endif

@MainActor
final class PaceModel: ObservableObject {
  @Published var snapshot: QuotaSnapshot?
  @Published var options: [QuotaOption] = []
  @Published var history: [QuotaSnapshot] = []
  @Published var now = Date()
  @Published var refreshing = false
  @Published var error: String?
  @Published var storageError: String?
  @Published var selected: String {
    didSet { UserDefaults.standard.set(selected, forKey: "quotaBucket") }
  }
  @Published var customPath: String {
    didSet { UserDefaults.standard.set(customPath, forKey: "codexPath") }
  }
  private var timer: Timer?
  private var nextRefresh = Date.distantPast
  private var failures = 0
  private var lastIndex: Int?
  private var wakeObserver: NSObjectProtocol?
  private let stateURL: URL
  let preview: Bool

  var projection: PaceProjection? {
    snapshot.flatMap { Pacing.project($0, history: history, now: now) }
  }
  var stale: Bool {
    snapshot.map { now.timeIntervalSince($0.received) >= 600 || now < $0.received } ?? false
  }
  var age: String {
    guard let date = snapshot?.received else { return "Not yet updated" }
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 { return "Updated \(seconds)s ago" }
    if seconds < 3600 { return "Updated \(seconds / 60)m ago" }
    return "Updated \(seconds / 3600)h ago"
  }
  var weeklyCountdown: String {
    guard let reset = snapshot?.reset else { return "—" }
    let minutes = max(0, Int(reset.timeIntervalSince(now) / 60))
    if minutes == 0 { return "<1m" }
    if minutes < 60 { return "\(minutes)m" }
    if minutes < 1440 { return "\(minutes / 60)h \(minutes % 60)m" }
    return "\(minutes / 1440)d \((minutes % 1440) / 60)h \(minutes % 60)m"
  }
  var countdown: String {
    guard let end = projection?.end else { return "—" }
    let minutes = max(0, Int(end.timeIntervalSince(now) / 60))
    return minutes == 0 ? "<1m" : "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
  }

  init() {
    selected = UserDefaults.standard.string(forKey: "quotaBucket") ?? ""
    customPath = UserDefaults.standard.string(forKey: "codexPath") ?? ""
    preview = ProcessInfo.processInfo.arguments.contains("--preview")
    stateURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Codex Pace/history.json")
    if preview {
      let reset = Calendar.current.date(byAdding: .day, value: 5, to: now)!
      snapshot = QuotaSnapshot(
        account: "preview", bucket: "Preview", remaining: 86, reset: reset, received: now,
        resetCredits: 2)
      history = [snapshot!]
    } else {
      if FileManager.default.fileExists(atPath: stateURL.path) {
        do {
          history = try JSONDecoder().decode([QuotaSnapshot].self, from: Data(contentsOf: stateURL))
          history = history.filter {
            $0.remaining.isFinite && (0...100).contains($0.remaining)
              && $0.received.timeIntervalSince1970.isFinite
              && $0.reset.timeIntervalSince1970.isFinite
          }
          // Do not show persisted account data as current until a fresh account check succeeds.
        } catch { storageError = "Saved history could not be read. New readings will still work." }
      }
      timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
        Task { @MainActor in self?.tick() }
      }
      wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.refresh() }
      }
      refresh()
    }
  }
  func tick() {
    now = Date()
    let index = snapshot?.index(at: now)
    let boundaryChanged = lastIndex != index && snapshot != nil
    lastIndex = index
    if now >= nextRefresh || (boundaryChanged && failures == 0) { refresh() }
  }
  func refreshIfStale() {
    if snapshot == nil || now.timeIntervalSince(snapshot!.received) >= 300 { refresh() }
  }
  func choose(_ bucket: String) {
    selected = bucket
    guard let option = options.first(where: { $0.id == bucket }) else { return }
    accept(option.snapshot)
  }
  func refresh() {
    guard !refreshing, !preview else { return }
    guard let path = CodexClient.executable(custom: customPath) else {
      error = "Codex CLI not found. Install Codex or choose its executable in Settings."
      nextRefresh = Date().addingTimeInterval(300)
      return
    }
    refreshing = true
    Task {
      do {
        let fetched = try await Task.detached(priority: .utility) {
          try CodexClient.collect(path: path)
        }.value
        options = fetched
        failures = 0
        error = nil
        if selected.isEmpty && fetched.count == 1 { selected = fetched[0].id }
        if let chosen = fetched.first(where: { $0.id == selected }) {
          accept(chosen.snapshot)
        } else {
          snapshot = nil
          if !selected.isEmpty {
            error = "The selected quota is unavailable. Choose a quota in Settings."
          }
        }
        nextRefresh = Date().addingTimeInterval(300)
      } catch {
        failures += 1
        self.error =
          (error as? CodexError)?.localizedDescription
          ?? "Could not read Codex quota. Please try again."
        nextRefresh = Date().addingTimeInterval(
          min(3600, 300 * pow(2, Double(min(failures - 1, 4)))))
      }
      refreshing = false
    }
  }
  private func accept(_ value: QuotaSnapshot) {
    guard
      snapshot == nil || value.received >= snapshot!.received || value.bucket != snapshot!.bucket
    else { return }
    snapshot = value
    now = Date()
    lastIndex = value.index(at: now)
    if !history.contains(where: { $0.identity == value.identity && $0.received == value.received })
    {
      history.append(value)
    }
    history.removeAll { now.timeIntervalSince($0.received) > 90 * 86400 }
    do {
      try FileManager.default.createDirectory(
        at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
      try JSONEncoder().encode(history).write(to: stateURL, options: .atomic)
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
      storageError = nil
    } catch { storageError = "Quota updated, but local history could not be saved." }
  }
}
