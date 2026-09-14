# Widgets

The app embeds one WidgetKit extension with two small widgets: Daily Quota and Weekly Quota. Add either from macOS **Edit Widgets → Codex Pace**. Both use a semicircular 0–100 speedometer, a numeric percentage, and a reset countdown. Carryover can make the daily number exceed 100%; the needle stops at 100 without changing the underlying quota.

Keep Codex Pace running to collect quota updates. Clicking a widget opens the app. WidgetKit schedules rendering and refreshes, so updates may lag the menu bar. A reading older than ten minutes is labelled; an expired bucket/week displays no balance until a new reading arrives. Preview values appear only in the widget gallery and placeholder. They are never saved as real readings.

## Data boundary

The host exports only the two percentages, bucket/week expiry dates, and reading timestamp to `~/Library/Application Support/Codex Pace/Widgets/snapshot.json`, written atomically with user-only permissions. It exports no account identifiers, authentication, or usage history. The sandboxed extension has a read-only file exception limited to this export directory. It cannot invoke Codex or access its authentication files and has no network entitlement.

This direct-download, ad-hoc-signed build has no Apple Developer team/profile. Apple's provisioned app groups require a profile (or a matching signing team for the macOS team-prefixed form). Therefore this build uses the documented narrow home-relative read-only sandbox exception, rather than declaring an unauthorized app group. A future Developer ID/App Store signing workflow should migrate the export to a provisioned shared app group.

The host asks WidgetCenter to reload on successful readings or quota selection changes. Timelines include minute-by-minute countdown entries for the next hour and exact expiry entries, requesting another timeline after five minutes. The system controls the actual schedule. The widget never invents a new quota grant from an expired reading.

## Verification

Version 1.2.0: universal app and embedded extension build successfully. WidgetKit Simulator discovers both widgets and loads real sandboxed timelines matching the installed app (daily 81%, weekly 83% during validation). Daily and weekly reset labels render correctly. Automated tests cover pacing parity, carryover above 100%, bucket/week expiry, clock reversal, export privacy, serialization/invalidation, and countdown formatting.

The normal popover now uses ViewThatFits: content that fits has no ScrollView; longer detail/error states retain a size-dependent scrolling fallback. The normal installed popover exposes no scrollbar and did not move when scrolled with the mouse wheel.

References:
- [Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- [App group authorization on macOS](https://developer.apple.com/documentation/xcode/accessing-app-group-containers)
- [Sandbox file exceptions](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html)
