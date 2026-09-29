import AppKit
import SwiftUI

#if canImport(PaceCore)
  import PaceCore
#endif

@main
struct CodexPaceApp: App {
  @NSApplicationDelegateAdaptor(PaceAppDelegate.self) private var delegate
  var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class PaceAppDelegate: NSObject, NSApplicationDelegate {
  private let model = PaceModel()
  private var item: NSStatusItem?
  private let popover = NSPopover()
  private var settingsWindow: NSWindow?
  private var inspectionWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let inspecting = ProcessInfo.processInfo.arguments.contains("--inspect-window")
    NSApp.setActivationPolicy(inspecting ? .regular : .accessory)
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    status.button?.image = NSImage(
      systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: "Codex Pace")
    status.button?.toolTip = "Codex Pace"
    status.button?.target = self
    status.button?.action = #selector(togglePopover)
    item = status
    popover.behavior = .transient
    let panel = NSHostingController(
      rootView: PacePanel(model: model, showSettings: { [weak self] in self?.openSettings() }))
    panel.sizingOptions = []
    popover.contentViewController = panel
    popover.contentSize = NSSize(width: 370, height: 340)
    // Make the status item discoverable on a manual app launch. No login item is installed.
    if inspecting {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 370, height: 340), styleMask: [.titled, .closable],
        backing: .buffered, defer: false)
      window.title = "Codex Pace — Inspection"
      let content = NSHostingController(
        rootView: PacePanel(model: model, showSettings: { [weak self] in self?.openSettings() }))
      content.sizingOptions = []
      window.contentViewController = content
      window.center()
      window.makeKeyAndOrderFront(nil)
      inspectionWindow = window
      NSApp.activate(ignoringOtherApps: true)
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.togglePopover() }
    }
  }
  func application(_ application: NSApplication, open urls: [URL]) {
    guard urls.contains(where: { $0.scheme == "codex-pace" && $0.host == "open" }) else { return }
    model.refreshIfStale()
    if !popover.isShown { togglePopover() }
  }
  @objc private func togglePopover() {
    guard let button = item?.button else { return }
    if popover.isShown {
      popover.performClose(nil)
      return
    }
    NSApp.activate(ignoringOtherApps: true)
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    popover.contentViewController?.view.window?.makeKey()
  }
  private func openSettings() {
    popover.performClose(nil)
    if settingsWindow == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 460, height: 480), styleMask: [.titled, .closable],
        backing: .buffered, defer: false)
      window.title = "Codex Pace Settings"
      window.isReleasedWhenClosed = false
      let content = NSHostingController(rootView: PaceSettings(model: model))
      content.sizingOptions = []
      window.contentViewController = content
      window.center()
      settingsWindow = window
    }
    NSApp.activate(ignoringOtherApps: true)
    settingsWindow?.makeKeyAndOrderFront(nil)
  }
}

struct PacePanel: View {
  @ObservedObject var model: PaceModel
  var showSettings: () -> Void
  var body: some View {
    ViewThatFits(in: .vertical) {
      panelContent.fixedSize(horizontal: false, vertical: true)
      ScrollView { panelContent }
        .scrollBounceBehavior(.basedOnSize)
    }
    .frame(width: 370, height: 340, alignment: .top)
    .onAppear { model.refreshIfStale() }
  }
  private var panelContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label("Codex Pace", systemImage: "gauge.with.dots.needle.50percent").font(.headline)
        Spacer()
        if model.preview { Text("Preview").font(.caption).foregroundStyle(.secondary) }
        Button(action: showSettings) { Image(systemName: "gearshape") }.buttonStyle(.plain).help(
          "Settings")
      }
      if let snapshot = model.snapshot, let pace = model.projection {
        VStack(spacing: 12) {
          meter(
            "Today's quota left", value: pace.dailyPercent,
            tint: quotaColor(pace.dailyPercent)
          )
          .help(
            pace.standardPlan
              ? "Compared with a standard daily allocation. Can exceed 100% when you have extra headroom."
              : "Compared with the balance sampled near this bucket's opening. Timing is approximate."
          )
          resetMeter("Bucket resets in", end: pace.end, duration: 86400, label: model.countdown)
          meter(
            "Weekly quota left", value: pace.weeklyPercent,
            tint: quotaColor(pace.weeklyPercent))
          resetMeter(
            "Weekly resets in", end: snapshot.reset, duration: 604800,
            label: model.weeklyCountdown)
        }
        if pace.correction { notice("Provider balance corrected; your quota may change.") }
        if snapshot.shortLimitReached {
          notice("Your shorter Codex limit is reached. Weekly headroom is still shown.")
        }
        if model.stale { notice("Showing an older reading. Refresh to check your balance.") }
        HStack {
          Label("Resets available", systemImage: "arrow.counterclockwise.circle")
          Spacer()
          Text(snapshot.resetCredits.map(String.init) ?? "—").monospacedDigit()
        }.font(.caption).foregroundStyle(.secondary)
      } else if model.options.count > 1 && model.selected.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          Text("Choose your quota").font(.title3.weight(.semibold))
          Text(
            "Your account has more than one weekly quota. This choice won't change your model."
          ).foregroundStyle(.secondary)
          ForEach(model.options) { option in
            Button {
              model.choose(option.id)
            } label: {
              HStack {
                Text(option.name)
                Spacer()
                Text("\(Pacing.whole(option.snapshot.remaining))% left")
              }
            }.buttonStyle(.bordered)
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text(
            model.refreshing
              ? "Connecting to Codex…"
              : model.snapshot == nil ? "Your week, at a steady pace." : "Weekly reset reached"
          ).font(.title3.weight(.semibold))
          Text(
            model.snapshot == nil
              ? "Codex Pace uses your existing Codex CLI sign-in to show how much you can spend each day."
              : "Checking the next quota window. Unused balance from the old week has expired."
          )
          .font(.callout).foregroundStyle(.secondary)
          if model.refreshing { ProgressView().controlSize(.small) }
        }.padding(.vertical, 12)
      }
      if let error = model.error { notice(error) }
      if let error = model.storageError { notice(error) }
      if let error = model.widgetError { notice(error) }
      Divider()
      HStack {
        Text(model.age).font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button {
          model.refresh()
        } label: {
          Image(systemName: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(.plain).disabled(model.refreshing || model.preview).help(
          "Refresh quota (⌘R)"
        )
        .keyboardShortcut("r").accessibilityLabel(
          model.refreshing ? "Refreshing quota" : "Refresh quota")
        Menu {
          Button("Settings…", action: showSettings)
          Divider()
          Button("Quit Codex Pace") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("More")
      }
    }
    .padding(20).frame(width: 370)
  }
  private func quotaColor(_ value: Double?) -> Color {
    blend(.systemRed, .systemGreen, fraction: (value ?? 0) / 100)
  }
  private func blend(_ start: NSColor, _ end: NSColor, fraction: Double) -> Color {
    Color(nsColor: start.blended(withFraction: min(1, max(0, fraction)), of: end) ?? start)
  }
  private func resetMeter(_ title: String, end: Date, duration: TimeInterval, label: String)
    -> some View
  {
    let fraction = min(1, max(0, end.timeIntervalSince(model.now) / duration))
    return meter(
      title, value: fraction * 100,
      tint: blend(.systemGreen, .systemGray, fraction: fraction), label: label
    )
    .help("Resets \(end.formatted(date: .abbreviated, time: .shortened))")
  }
  private func meter(_ title: String, value: Double?, tint: Color, label: String? = nil)
    -> some View
  {
    let reading = label ?? (value == nil ? "—" : "\(Pacing.whole(value))%")
    return VStack(spacing: 5) {
      HStack {
        Text(title)
        Spacer()
        Text(reading).monospacedDigit()
      }.font(.caption)
      ProgressView(value: min(100, max(0, value ?? 0)), total: 100).tint(tint)
        .accessibilityLabel(title).accessibilityValue(reading)
    }
  }
  private func notice(_ text: String) -> some View {
    Label(text, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary).fixedSize(
      horizontal: false, vertical: true)
  }
}

struct PaceSettings: View {
  @ObservedObject var model: PaceModel
  var body: some View {
    Form {
      Section("Codex connection") {
        TextField("CLI executable", text: $model.customPath, prompt: Text("Automatic"))
          .help("Leave empty to find Codex automatically, or enter an absolute executable path.")
        Picker(
          "Weekly quota", selection: Binding(get: { model.selected }, set: { model.choose($0) })
        ) {
          Text("Choose a quota").tag("")
          ForEach(model.options) { Text($0.name).tag($0.id) }
          if !model.selected.isEmpty && !model.options.contains(where: { $0.id == model.selected })
          {
            Text(model.selected).tag(model.selected)
          }
        }
        Button("Refresh connection") { model.refresh() }.disabled(model.refreshing)
        Text(
          "Uses your existing Codex CLI sign-in. To sign in, run codex login in Terminal. Refreshes every five minutes."
        ).font(.caption).foregroundStyle(.secondary)
      }
      Section("About your pace") {
        Text(
          "Your weekly quota is split into seven equal 24-hour buckets. Unused quota carries forward within the week; overspending leaves less for the next bucket."
        )
        Text(
          "Values use whole percentages; fractions are kept in the calculation. Today’s quota can exceed 100% when you have extra headroom."
        )
        Text(
          "Quota history stays on this Mac for 90 days. No model calls are made and reset credits are never redeemed."
        )
      }.font(.callout)
    }.formStyle(.grouped).padding().frame(width: 460, height: 480)
  }
}
