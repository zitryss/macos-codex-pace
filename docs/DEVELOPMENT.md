# Development

- `Sources/PaceCore`: pure pacing arithmetic and the bounded read-only Codex client.
- `Sources/CodexPace`: macOS lifecycle, SwiftUI presentation, refresh orchestration and local persistence.
- `CodexPace.xcodeproj`: native app target; no third-party packages.
- `Package.swift`: builds the same sources and runs the core test suite.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/build.sh
```

Use Xcode's My Mac destination to run. `--preview` supplies an explicitly labeled synthetic balance and bypasses network/persistence. `--inspect-window` opens the same content in a regular window for development inspection. Normal launches show the menu bar popover.

Tests cover quota parsing, selection options, carryover/debt, fractional display, opening sample quality, late-start fallback, account isolation, exact boundaries/expiry, corrections and widget snapshot persistence/expiry. See VALIDATION.md for the actual checks performed.

Do not commit private history, settings, credentials or real account snapshots. Tests use synthetic inputs. Keep network I/O off the main actor and presentation rounding out of arithmetic.

## Widgets after a macOS upgrade

The installed app embeds `Contents/PlugIns/CodexPaceWidgets.appex`, which supplies both Daily Quota and Weekly Quota. Check its registration with:

```sh
pluginkit -m -A -D -v -i dev.zitryss.CodexPace.Widgets
```

If there is no match but the extension is present in the installed app, register that extension again (adjust the path for your installation):

```sh
pluginkit -a "$HOME/Applications/Codex Pace.app/Contents/PlugIns/CodexPaceWidgets.appex"
```

Open Codex Pace and refresh the quota. The host writes a minimal snapshot to `~/Library/Application Support/Codex Pace/Widgets/snapshot.json` and requests new widget timelines. If an existing widget remains blank, remove and add it again from the widget gallery.
