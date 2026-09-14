# Design decisions

## Native macOS interpretation

The concept is quota pacing, not a Linux panel skin. The macOS version uses a compact, transient AppKit NSPopover anchored to an NSStatusItem, containing SwiftUI views. AppKit handles reliable status-item activation and first-launch discovery; SwiftUI supplies typography, buttons, progress views, menus, calendar layout and the settings form. The app is an accessory without a Dock icon.

Apple's menu bar guidance favors a menu unless functionality is too complex. This calendar and pair of balances justify a popover. The highest-value number gets a clear visual hierarchy, instead of three equally large columns. Settings and Quit use familiar controls; details are disclosed by clicking a date. System colors adapt to the current appearance. The menu bar uses an SF Symbol and an accessibility description.

Sources reviewed September 14, 2026:

- [Apple: the menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)
- [Apple: MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra) — describes window-style extras for data-rich controls and LSUIElement for menu-bar-only apps.
- [Apple: window menu bar extra style](https://developer.apple.com/documentation/swiftui/menubarextrastyle/window)
- [OpenAI: Codex app-server](https://learn.chatgpt.com/docs/app-server#auth-endpoints)

## Arithmetic

For a verified 10,080-minute window ending E, infer S=E−604800. Each half-open bucket is [S+i×86400, S+(i+1)×86400), i=0…6. UTC instants drive arithmetic; the calendar uses local civil dates and actual midnight boundaries.

Base B=100/7. With remaining R and active index i, reserve F=(6−i)×B. Available A=max(0,R−F). This incorporates surplus/debt exactly once. Internally use Double with a small formatting tolerance; floor only displayed values.

Without an opening sample: Plan=B, daily percentage=100×A/B, estimated current Used=max(0,B−A). This Used value is a pacing shortfall, not reconstructed current-bucket consumption. Known weekly consumption minus supported bucket deltas and current fallback Used is divided equally among completed unknown buckets. Estimates never enter the snapshot store. Negative residuals or corrections are not forced into history.

A first successful request starting at/after a boundary and finishing within 60 seconds provides a frozen **sampled opening**. Plan=max(0,R_open−F); Used=R_open−R; daily percentage=100×A/Plan. These remain estimates because the provider supplies no measurement timestamp and rounds its quota readings. This deliberately avoids the Omarchy implementation's unreachable requirement for an exact provider boundary timestamp. Late startup stays in standard-plan mode until a later bucket can be sampled. A zero sampled plan has no defined daily ratio.

Only readings from the same hashed account, selected quota and reset epoch contribute to calculations. No carry crosses a provider reset. Expired readings do not create a fictional new grant. A correction can make a sampled ratio exceed 100; the stored arithmetic remains intact, only the bar's fill is capped.

## Data and limitations

The read-only local stdio client performs initialize → initialized → account/read → account/rateLimits/read. It selects windows by duration, exposes multiple bucket choices, and stores the selected choice. It supports primary/secondary weekly windows and the legacy single-bucket response. Missing reset credits display as unknown.

Codex owns authentication and token refresh. The app never parses auth.json. The process environment retains CODEX_HOME when supplied; Finder launches use Codex's default home. A custom absolute CLI path is available in Settings. Process requests run off the main thread, have bounded output and a 25-second watchdog, and clean up only their owned child process. Failed requests back off; manual refresh is explicit. History writes are atomic with user-only file permissions and 90-day retention.

No exact historical reconstruction is promised. Calendar usage is approximate even with near-boundary samples. Shorter quota limits can restrict use despite weekly headroom. Source code builds are ad-hoc signed and unsandboxed to invoke the existing CLI; public binary distribution needs a developer signing/notarization workflow.
