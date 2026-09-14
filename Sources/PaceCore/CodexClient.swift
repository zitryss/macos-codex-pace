import CryptoKit
import Foundation

public struct QuotaOption: Identifiable, Sendable {
  public var id: String
  public var name: String
  public var snapshot: QuotaSnapshot
}
public enum CodexError: LocalizedError {
  case unavailable(String)
  public var errorDescription: String? {
    if case .unavailable(let message) = self { return message }
    return nil
  }
}

public enum CodexClient {
  public static func executable(custom: String = "") -> String? {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let paths =
      custom.isEmpty
      ? [
        "/opt/homebrew/bin/codex", "/usr/local/bin/codex", "\(home)/.local/bin/codex",
        "/Applications/Codex.app/Contents/Resources/codex",
      ]
        + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map {
          "\($0)/codex"
        } : [custom]
    return paths.first { $0.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: $0) }
  }

  public static func parse(
    account: [String: Any], result: [String: Any], requested: Date, received: Date
  ) throws -> [QuotaOption] {
    guard account["type"] as? String == "chatgpt" else {
      throw CodexError.unavailable(
        "Sign in to the Codex CLI with your subscription using codex login.")
    }
    guard let accountID = result["accountId"] as? String, !accountID.isEmpty else {
      throw CodexError.unavailable(
        "Codex did not return an account identity. Update the Codex CLI and try again.")
    }
    let identity = SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }
      .joined()
    var buckets = result["rateLimitsByLimitId"] as? [String: [String: Any]] ?? [:]
    if buckets.isEmpty, let legacy = result["rateLimits"] as? [String: Any] {
      buckets[legacy["limitId"] as? String ?? "legacy"] = legacy
    }
    let credits =
      ((result["rateLimitResetCredits"] as? [String: Any])?["availableCount"] as? NSNumber).flatMap
    { n -> Int? in
      guard CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue >= 0,
        n.doubleValue < Double(Int.max), n.doubleValue.rounded() == n.doubleValue
      else { return nil }
      return n.intValue
    }
    var options: [QuotaOption] = []
    for (key, bucket) in buckets {
      let windows = [bucket["primary"], bucket["secondary"]].compactMap { $0 as? [String: Any] }
      let weekly = windows.filter { ($0["windowDurationMins"] as? Int) == 10080 }
      guard weekly.count == 1, let window = weekly.first,
        bucket["limitId"] == nil || bucket["limitId"] as? String == key,
        let usedNumber = window["usedPercent"] as? NSNumber,
        CFGetTypeID(usedNumber) != CFBooleanGetTypeID(),
        let resetNumber = window["resetsAt"] as? NSNumber,
        CFGetTypeID(resetNumber) != CFBooleanGetTypeID()
      else { continue }
      let used = usedNumber.doubleValue
      let end = resetNumber.doubleValue
      guard used.isFinite, (0...100).contains(used), end.isFinite,
        end > received.timeIntervalSince1970, end <= received.timeIntervalSince1970 + 604800
      else { continue }
      if let start = window["startsAt"] as? Double, abs(start - (end - 604800)) > 0.001 { continue }
      let short = windows.contains {
        ($0["windowDurationMins"] as? Int) != 10080 && ($0["usedPercent"] as? Double ?? 0) >= 100
      }
      let snapshot = QuotaSnapshot(
        account: identity, bucket: key, remaining: 100 - used,
        reset: Date(timeIntervalSince1970: end), received: received, requested: requested,
        resetCredits: credits, shortLimitReached: short)
      options.append(
        QuotaOption(id: key, name: bucket["limitName"] as? String ?? key, snapshot: snapshot))
    }
    guard !options.isEmpty else {
      throw CodexError.unavailable(
        "No active weekly quota was returned. Try refreshing after the reset.")
    }
    return options.sorted { $0.id < $1.id }
  }

  /// Runs on a background task. A separate watchdog bounds blocking pipe reads.
  public static func collect(path: String) throws -> [QuotaOption] {
    let rpc = RPCSession(path: path)
    try rpc.start()
    defer { rpc.close() }
    _ = try rpc.request(
      id: 1, method: "initialize",
      params: ["clientInfo": ["name": "macos_codex_pace", "version": "1.2.0"]])
    try rpc.send(["method": "initialized", "params": [:]])
    let account = try rpc.request(id: 2, method: "account/read")["account"] as? [String: Any] ?? [:]
    let requested = Date()
    let result = try rpc.request(id: 3, method: "account/rateLimits/read")
    return try parse(account: account, result: result, requested: requested, received: Date())
  }
}

private final class RPCSession: @unchecked Sendable {
  private let process = Process()
  private let input = Pipe()
  private let output = Pipe()
  private var buffer = Data()
  private var watchdog: DispatchWorkItem?
  init(path: String) {
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = ["app-server"]
    process.standardInput = input
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
    process.environment = env
  }
  func start() throws {
    do { try process.run() } catch {
      throw CodexError.unavailable("Could not start Codex. Check its executable path in Settings.")
    }
    let job = DispatchWorkItem { [weak self] in
      guard let self, self.process.isRunning else { return }
      kill(self.process.processIdentifier, SIGKILL)
    }
    watchdog = job
    DispatchQueue.global().asyncAfter(deadline: .now() + 25, execute: job)
  }
  func close() {
    watchdog?.cancel()
    try? input.fileHandleForWriting.close()
    if process.isRunning { process.terminate() }
    // Codex owns only this child. Reap it without touching any other Codex session.
    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    process.waitUntilExit()
    try? output.fileHandleForReading.close()
  }
  func send(_ value: [String: Any]) throws {
    var data = try JSONSerialization.data(withJSONObject: value)
    data.append(10)
    try input.fileHandleForWriting.write(contentsOf: data)
  }
  func request(id: Int, method: String, params: [String: Any] = [:]) throws -> [String: Any] {
    try send(["id": id, "method": method, "params": params])
    for _ in 0..<1000 {
      while !buffer.contains(10) {
        let data = output.fileHandleForReading.availableData
        guard !data.isEmpty else {
          throw CodexError.unavailable("Codex timed out or disconnected. Try refreshing.")
        }
        buffer.append(data)
        guard buffer.count <= 2_000_000 else {
          throw CodexError.unavailable("Codex returned an oversized response.")
        }
      }
      guard let newline = buffer.firstIndex(of: 10) else { continue }
      let line = Data(buffer[..<newline])
      buffer.removeSubrange(...newline)
      guard let message = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
        continue
      }
      if message["method"] != nil, let requestID = message["id"] {
        try send(["id": requestID, "error": ["code": -32601, "message": "Read-only client"]])
        continue
      }
      guard message["id"] as? Int == id else { continue }
      guard message["error"] == nil, let result = message["result"] as? [String: Any] else {
        throw CodexError.unavailable(
          "Codex could not read the account quota. Check your CLI login and try again.")
      }
      return result
    }
    throw CodexError.unavailable("Too many messages from Codex. Try again.")
  }
}
