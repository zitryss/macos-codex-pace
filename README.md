# Codex Pace for Mac

**Make your Codex subscription last through the week.**

A native macOS menu bar app for keeping a steady pace of AI usage. See how much of your weekly quota you can spend today without eating into the days ahead.

Your week is divided into seven equal, 24-hour planning buckets. Spend less and the surplus is available in the next bucket; spend more and the next quota shrinks. Buckets follow your provider's reset time, not midnight. Unused quota expires at the weekly reset.

![Codex Pace menu bar app](https://raw.githubusercontent.com/zitryss/macos-codex-pace/dd1ba2d83d923da53bcc703fe3f3deff64787773/docs/screenshots/codex-pace-1.1.0.png)

## Use it

Click the gauge in the menu bar. Four bars show today's quota, time until the next bucket, weekly quota, and time until the weekly reset. Balance bars turn from green toward red as you spend. Countdown bars shrink from gray toward green as a fresh quota approaches. The time remaining appears beside each countdown.

Today's quota includes surplus or overspending from earlier buckets. It can exceed 100% when you have extra headroom.

The month calendar highlights the dates your week touches—usually eight dates for seven buckets. Stronger blue marks the current bucket, and an outline marks today's calendar date. Click a day for its range and calculation basis. P is Plan; U is Used. Asterisks mean estimated usage, not exact daily consumption.

Readings refresh every five minutes, on wake, and at bucket boundaries. Use the refresh button or ⌘R to check now. Settings lets you choose the weekly quota and, if necessary, locate your Codex CLI. Reset credits are displayed only.

## Download

Get the universal Mac app (Apple silicon and Intel) from [GitHub Releases](https://github.com/zitryss/macos-codex-pace/releases/latest). Unzip it and move **Codex Pace.app** to Applications. Requires macOS 14 or later and a signed-in Codex CLI.

## Build and run

Requires macOS 14 or later, Xcode, and a Codex CLI already signed in with your subscription (`codex login`). No API key is needed.

1. Clone this repository and open **CodexPace.xcodeproj** in Xcode.
2. Choose **CodexPace → My Mac**, then Run (⌘R).
3. On first launch, choose the quota you want to pace. Choosing a quota does not change your model.

Or build from Terminal:

```sh
./scripts/build.sh
```

The app is built at `.build/xcode/Build/Products/Release/Codex Pace.app`. You can copy it to Applications. The build is locally signed (ad-hoc), not Apple Developer ID signed or notarized. macOS may block a downloaded copy until you approve it in System Settings → Privacy & Security. You can also build from source.

## Private by design

The app asks your existing Codex CLI for quota readings. It makes no model calls, copies no credentials and never redeems credits. History stays in `~/Library/Application Support/Codex Pace/history.json` for 90 days. Quit from the popover's More menu. No login item is installed.

The weekly balance is the reference. Without an opening sample, daily figures use a standard-plan estimate. A reading captured within 60 seconds after a boundary provides a better opening estimate; it still cannot establish exact usage at the boundary. Offline gaps remain uncertain.

[Design and accounting](docs/DESIGN.md) · [Development and verification](docs/DEVELOPMENT.md)

Inspired by [Codex Pace for Omarchy](https://github.com/zitryss/omarchy-codex-pace). Independent project; not affiliated with OpenAI or Apple.
