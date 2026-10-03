# Verification — September 14, 2026

- Xcode 26.6 / macOS 26 host: native app builds for arm64 and x86_64, with local ad-hoc signing.
- Swift package tests: 8 passed, including an opt-in live read-only Codex connection. Ordinary test runs skip that network check.
- Live account reading succeeded through the installed CLI with its existing login; the account exposed the general `codex` weekly quota.
- Inspected the actual SwiftUI view in a temporary regular window: live daily/weekly balances, calendar overlap, date details, refresh pending state and successful freshness update.
- Corrected a hosting-size feedback loop found during live testing. Explicit hosting sizes and scrollable content bound the popover and settings.
- Verified the final actual NSPopover and Settings window visually: calendar dates and quota values are readable; footer and refresh remain visible. The temporary inspection mode is off in the shipped scheme.
- No model turns or reset-credit redemptions were used.

Limitations: near-boundary sampling, 90-day retention and background scheduling are implemented but have not been observed over a full live quota week. Intel was compiled, not executed. Distribution notarization, launch-at-login and automatic app updates are outside this initial source release.

## Release 1.0.1

- Universal optimized Release build, embedded app icon, and strict code-signature verification passed.
- Installed release replaces the debug copy in `~/Applications`; the two extra debug bundles were unregistered and moved to Trash.
- Captured the actual installed menu bar popover for the README and screenshot issue.
- No Developer ID signing identity is installed. The download is explicitly labeled ad-hoc signed and not notarized.

## Release 1.3.0 — October 3, 2026

- Nine automated tests passed; the optional live CLI test was skipped.
- Universal optimized Release app and widget extension built for arm64 and x86_64. Both report version 1.3.0, build 6.
- Strict recursive code-signature verification and ZIP integrity checks passed; SHA-256 checksum generated.
- Distribution remains ad-hoc signed and not notarized. Intel binaries were compiled, not executed.
