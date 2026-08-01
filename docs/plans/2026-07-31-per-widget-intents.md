# Per-Widget Configuration Intents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the single shared `ConfigurationIntent` into four per-widget intents that expose only relevant options, routed through one shared plain `WidgetConfig` struct, and verify the Clock and Weather widgets render correctly.

**Architecture:** Each widget gets a thin `WidgetConfigurationIntent` whose only job is collecting user input; every intent resolves to a plain `WidgetConfig` struct via a `ChronographWidgetIntent` protocol. A single generic `ChronographTimelineProvider<Intent>` feeds a shared `TimelineEngine` (the renamed current `TimelineProvider`) that consumes `WidgetConfig`. All views (`ChronographWidgetView`, row views, in-app previews) consume only `WidgetConfig` — AppIntents types never reach the render layer.

**Tech Stack:** Swift 5 / SwiftUI / WidgetKit / AppIntents / EventKit / WeatherKit. Xcode project `Chronograph.xcodeproj`, schemes "Chronograph iOS", "Chronograph Mac", "Chronograph Watch".

## Global Constraints

- Widget kind strings MUST NOT change: `"calendar"`, `"reminders"`, `"timezones"`, `"weather"`, `"clock"`. Placements on user home screens are keyed by kind.
- Changing a widget kind's intent type resets that widget's saved per-instance configuration (placement survives). **Accepted tradeoff** — do not build migration machinery.
- AppIntents `@Parameter` properties cannot be declared in a protocol or shared via inheritance. The appearance parameters (View Options, Font Style, Font Size, Background, Accent) are intentionally declared in each intent. Do not attempt to deduplicate them.
- Deployment targets stay: iOS 18.0, macOS 15.0, watchOS 11.0. `SWIFT_VERSION = 5.0`. No new dependencies.
- App-group suite names in `Common/Keys.swift` are unchanged.
- There is no test target. Verification = all three schemes build + Xcode previews + iOS Simulator visual checks. Every task ends with all three builds green:

```bash
xcodebuild -project Chronograph.xcodeproj -scheme "Chronograph iOS" -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Chronograph.xcodeproj -scheme "Chronograph Mac" -destination 'platform=macOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Chronograph.xcodeproj -scheme "Chronograph Watch" -destination 'generic/platform=watchOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected for each: `** BUILD SUCCEEDED **`. (At plan time, iOS and Watch pass; **Mac fails** — Task 1 fixes it.)

- Related Linear issues: fixes [A-152](https://linear.app/arfct/issue/A-152) (Task 1) and [A-154](https://linear.app/arfct/issue/A-154) (Tasks 4/7). Update both when the corresponding task lands.

---

### Task 1: Fix the macOS build break

**Files:**
- Modify: `Common/ChronographWidget.swift:101-105`

**Interfaces:**
- Produces: a compiling "Chronograph Mac" scheme, so every later task can verify all three platforms.

`fullBleed` moved from `WidgetFeatures` to `WidgetViewOptions` in commit `5e40c91`; the macOS branch was never updated.

- [ ] **Step 1: Fix the stale reference**

In `Common/ChronographWidget.swift`, replace:

```swift
#if os(macOS)
    self.fullBleed = entry.configuration.features.contains(.fullBleed)
#else
    self.fullBleed = widgetFamily == .accessoryRectangular || entry.configuration.viewOptions.contains(.fullBleed)
#endif
```

with:

```swift
#if os(macOS)
    self.fullBleed = entry.configuration.viewOptions.contains(.fullBleed)
#else
    self.fullBleed = widgetFamily == .accessoryRectangular || entry.configuration.viewOptions.contains(.fullBleed)
#endif
```

- [ ] **Step 2: Verify all three schemes build**

Run the three `xcodebuild` commands from Global Constraints. Expected: `** BUILD SUCCEEDED **` for all three (Mac for the first time).

- [ ] **Step 3: Commit**

```bash
git add Common/ChronographWidget.swift
git commit -m "fix: macOS build — fullBleed moved from WidgetFeatures to WidgetViewOptions (A-152)"
```

---

### Task 2: Introduce `WidgetConfig` and route all rendering through it

**Files:**
- Create: `Common/WidgetConfig.swift`
- Modify: `Common/WidgetTimeline.swift` (entry + provider internals)
- Modify: `Common/ChronographWidget.swift` (view reads)
- Modify: `Common/ChronographRow.swift` (`RowViewConfig` + three call sites)
- Modify: `Common/ConfigurationIntent.swift` (add `widgetConfig` mapping)
- Modify: `Common/WidgetPreviewView.swift`, `Common/ChronographTabView.swift`, `Watch/ContentView.swift` (previews consume `WidgetConfig`)

**Interfaces:**
- Produces: `struct WidgetConfig` (fields below); `CalendarTimelineEntry.config: WidgetConfig`; `RowViewConfig.widget: WidgetConfig` and `RowViewConfig.date: Date`; `ConfigurationIntent.widgetConfig: WidgetConfig`; presets `WidgetConfig.calendar/.simpleCalendar/.combo/.appCombo/.reminders/.timezones/.weatherCurrent/.weatherDaily`; `TimelineProvider.timeline(config:context:)`.
- Consumes: nothing new — behavior must be identical after this task.

- [ ] **Step 1: Create `Common/WidgetConfig.swift`**

```swift
import Foundation

/// Plain, intent-free description of what a widget instance displays.
/// Every widget intent resolves to one of these; the timeline engine and
/// all views consume only this type.
struct WidgetConfig {
  var content: DisplayedContent = .calendar
  var features: [WidgetFeatures] = []
  var calendars: [CalendarSelectionEntity] = []
  var reminderLists: [ReminderSelectionEntity] = []
  var timezones: [TimeZoneSelectionEntity] = []
  var weatherStyle: WeatherStyle = .current
  var viewOptions: [WidgetViewOptions] = []
  var fontStyle: FontStyle = .normal
  var fontSize: FontSize = .medium
  var backgroundColor: String = ""
  var accentColor: String = ""
  var pageOffset: Int = 0
}

// Presets — replaces the static configs on ConfigurationIntent.
extension WidgetConfig {
  static let calendar = WidgetConfig(content: .calendar,
                                     features: [.allDayEvents, .timeBars, .multiDayEvents])
  static let simpleCalendar = WidgetConfig(content: .calendar, features: [.allDayEvents])
  static let combo = WidgetConfig(content: .calendar,
                                  features: [.allDayEvents, .timeBars, .multiDayEvents, .weather])
  static var appCombo: WidgetConfig {
    var config = combo
    config.accentColor = "#db4437"
    config.viewOptions = [.showColors]
    return config
  }
  static let reminders = WidgetConfig(content: .reminders)
  static let timezones = WidgetConfig(content: .timezones, timezones: [
    TimeZoneSelectionEntity(id: "America/Los_Angeles", title: "Los Angeles", subtitle: nil, color: nil),
    TimeZoneSelectionEntity(id: "America/New_York", title: "New York City", subtitle: nil, color: nil),
    TimeZoneSelectionEntity(id: "Europe/London", title: "London", subtitle: nil, color: nil),
    TimeZoneSelectionEntity(id: "Asia/Tokyo", title: "Tokyo", subtitle: nil, color: nil),
  ])
  static let weatherCurrent = WidgetConfig(content: .weather, weatherStyle: .current)
  static let weatherDaily = WidgetConfig(content: .weather, weatherStyle: .daily)
}
```

- [ ] **Step 2: Map the old intent onto it**

At the bottom of `Common/ConfigurationIntent.swift` add:

```swift
extension ConfigurationIntent {
  var widgetConfig: WidgetConfig {
    WidgetConfig(content: content,
                 features: features,
                 calendars: calendars,
                 reminderLists: reminders,
                 timezones: timezones,
                 weatherStyle: weatherStyle,
                 viewOptions: viewOptions,
                 fontStyle: fontStyle,
                 fontSize: fontSize,
                 backgroundColor: backgroundColor,
                 accentColor: accentColor,
                 pageOffset: pageOffset)
  }
}
```

- [ ] **Step 3: Convert the entry and provider internals in `Common/WidgetTimeline.swift`**

1. `CalendarTimelineEntry`: replace `let configuration: ConfigurationIntent` with `let config: WidgetConfig`.
2. The `AppIntentTimelineProvider` conformance methods become thin shims:

```swift
func snapshot(for configuration: ConfigurationIntent, in context: Context) async -> CalendarTimelineEntry {
  let timeline = await timeline(config: configuration.widgetConfig, context: context)
  return timeline.entries.first!
}

func timeline(for configuration: ConfigurationIntent, in context: Context) async -> Timeline<CalendarTimelineEntry> {
  await timeline(config: configuration.widgetConfig, context: context)
}
```

3. Rename the workhorse `func timeline(for configuration: ConfigurationIntent, context: Context? = nil)` to `func timeline(config: WidgetConfig, context: Context? = nil)` and inside it mechanically replace every `configuration.` read: `.content`, `.features`, `.weatherStyle`, `.timezones`, `.calendars`, `.pageOffset` stay same-named on `config`; `configuration.reminders` becomes `config.reminderLists`. Same rename inside `getTimezoneEntries`, `fetchReminders`, `fetchScheduledReminders`, `fetchEvents` (change their `configuration: ConfigurationIntent` parameters to `config: WidgetConfig`).
4. The cache identifier at `:107` becomes `String(reflecting: config)` with `config.content`.
5. `placeholder(in:)` builds its entry with `config: WidgetConfig.calendar` instead of `configuration: ConfigurationIntent()` (delete the locally-built `config` variable there — it was already unused).
6. Every `CalendarTimelineEntry(date:configuration:...)` construction becomes `CalendarTimelineEntry(date:config:...)`.

- [ ] **Step 4: Convert the view in `Common/ChronographWidget.swift`**

Mechanical rename `entry.configuration.` → `entry.config.` at every site: `init` (`fontSize` ×2, `viewOptions` fullBleed branches from Task 1, `fontStyle`), `body` (`content`, `backgroundColor`, `accentColor`, `fontStyle` ×2, `features` timeBars, `content` for reminder clipping, `pageOffset`).

Where `RowViewConfig` is built (`let row = { var config = RowViewConfig(entry: entry) ... }`), change to:

```swift
var config = RowViewConfig(widget: entry.config, date: entry.date)
```

- [ ] **Step 5: Convert `RowViewConfig` and its three consumers in `Common/ChronographRow.swift`**

Replace `var entry: TimelineProvider.Entry` in `RowViewConfig` with:

```swift
var widget: WidgetConfig
var date: Date = Date()
```

Fix the three read sites:
- `EventRowView` (~`:411`): `config.entry.configuration.viewOptions.contains(.showColors)` → `config.widget.viewOptions.contains(.showColors)`
- `EventRowView` (~`:416`) and `ReminderRowView` (~`:586`): `timeIntervalSince(config.entry.date)` → `timeIntervalSince(config.date)`
- `ReminderRowView` (~`:653`): `config.entry.configuration.content == .reminders` → `config.widget.content == .reminders`

- [ ] **Step 6: Point the in-app previews at `WidgetConfig`**

`Common/WidgetPreviewView.swift`: change `var config: ConfigurationIntent` to `var config: WidgetConfig`; `reloadTimeline()` calls `TimelineProvider(kind: kind).timeline(config: config)`. Update the two `#Preview` blocks to build `WidgetConfig` values (e.g. the test config becomes `var c = WidgetConfig.calendar; c.fontSize = .tiny; c.accentColor = "#FF5500"; ...`).

`Common/ChronographTabView.swift`: `WidgetPreviewView(config: ConfigurationIntent.appComboConfig)` → `.init(config: .appCombo)`; `remindersConfig` → `.reminders`; `timezonesConfig` → `.timezones`; `weatherCurrentConfig` → `.weatherCurrent`.

`Watch/ContentView.swift`: `ConfigurationIntent.calendarConfig` → `.calendar`; `ConfigurationIntent.remindersConfig` → `.reminders`.

- [ ] **Step 7: Build all three schemes**

Run the three commands from Global Constraints. Expected: all `** BUILD SUCCEEDED **`. Compile errors here are almost certainly missed `entry.configuration` / `config.entry` sites — the compiler is the checklist.

- [ ] **Step 8: Visual regression check**

Open the iOS app in the simulator (scheme "Chronograph iOS", any iPhone 16 sim). Tab through Calendar / Reminders / Timezones / Weather preview tabs. Expected: identical rendering to before this task (this task is pure plumbing).

- [ ] **Step 9: Commit**

```bash
git add Common/ Extensions/ Watch/ iOS/
git commit -m "refactor: route all widget rendering through plain WidgetConfig struct"
```

---

### Task 3: Split `TimelineEngine` from a generic provider

> **Design decision — single vs. multiple providers (resolved):** one generic
> `ChronographTimelineProvider<Intent>` for all four widgets. Rationale: the
> provider layer (placeholder/snapshot/timeline/recommendations) is identical
> ceremony per widget, and per-content logic cannot be isolated per provider
> anyway because the Calendar widget crosses content types — it renders weather
> forecasts on day headers (`.weather` feature) and inlines scheduled
> reminders. Four concrete providers would be ~100 lines of duplicate glue
> delegating to the same shared builders. The sharing is instead made explicit
> by decomposing the engine into named per-content builders (Step 1b): shared
> scaffolding (fetches, error entries, minute fanout, reload policy) stays in
> `timeline(config:context:)`; content assembly lives in one builder per
> `DisplayedContent`. If a future widget needs a different timeline *policy*
> (e.g. per-second entries), add a second provider then — the builders make
> that cheap.

**Files:**
- Modify: `Common/WidgetTimeline.swift`
- Modify: `Common/ChronographWidget.swift` (widget structs + view's entry type)
- Modify: `Common/ConfigurationIntent.swift` (temporary protocol conformance)
- Modify: `Common/WidgetPreviewView.swift` (engine rename)

**Interfaces:**
- Produces:
  - `protocol ChronographWidgetIntent: WidgetConfigurationIntent { var widgetConfig: WidgetConfig { get }; static var recommendedIntents: [(intent: Self, description: String)] { get } }`
  - `struct TimelineEngine { func timeline(config: WidgetConfig, context: TimelineProviderContext? = nil) async -> Timeline<CalendarTimelineEntry>; func placeholderEntry(context: TimelineProviderContext?) -> CalendarTimelineEntry }`
  - `struct ChronographTimelineProvider<Intent: ChronographWidgetIntent>: AppIntentTimelineProvider`
- Consumes: `WidgetConfig`, `ConfigurationIntent.widgetConfig` from Task 2.

- [ ] **Step 1: Rename `TimelineProvider` → `TimelineEngine` and strip provider conformance**

In `Common/WidgetTimeline.swift`:
1. Rename `struct TimelineProvider: AppIntentTimelineProvider` to `struct TimelineEngine` (no protocol conformance).
2. Delete `let kind: String` (never read), the `snapshot(for:in:)`/`timeline(for:in:)` shims from Task 2, `recommendations()`, and the unused `static let sampleEntry`.
3. Rename `placeholder(in context: Context)` to `func placeholderEntry(context: TimelineProviderContext?) -> CalendarTimelineEntry`.
4. `static var cachedTimelines` stays for now (tracked separately in A-159).
5. Fix remaining `TimelineProvider.` references project-wide: `RowViewConfig` no longer has any (Task 2); `ChronographWidgetView` declares `var entry: TimelineProvider.Entry` → change to `var entry: CalendarTimelineEntry`; `WidgetPreviewView.reloadTimeline()` → `TimelineEngine().timeline(config: config)`.

- [ ] **Step 1b: Decompose `timeline(config:context:)` into per-content builders**

This is an extract-method refactor — move code, do not change logic. The goal is that shared scaffolding and per-content assembly are separated by named function boundaries:

```swift
struct TimelineEngine {
  // Shared scaffolding stays in timeline(config:context:):
  //   date-range setup, permission checks + error entries, weather fetch
  //   (needed by BOTH .weather content and the calendar `.weather` feature),
  //   reminder/event fetches, the 15-minute entry fanout, reload policy,
  //   cache bookkeeping.

  /// The big `if configuration.content == .calendar` loop (~:213-393):
  /// headers, dedup, conflicts, free time, note/URL/meeting extraction.
  /// Also consumes `scheduledReminders` and `weather` — this cross-content
  /// dependency is WHY there is one engine and one provider.
  private func buildCalendarEntries(config: WidgetConfig,
                                    items: [EKCalendarItem],
                                    weather: Weather?,
                                    renderDate: Date,
                                    context: TimelineProviderContext?) -> [EventEntry]

  /// Current `fetchReminders` result shaping (header row + sorted rows).
  private func buildReminderEntries(config: WidgetConfig,
                                    reminders: [EKReminder]) -> [EventEntry]

  /// Current `getTimezoneEntries` (~:67-101), renamed.
  private func buildTimezoneEntries(config: WidgetConfig) -> [EventEntry]

  /// Current weather-style switch (~:546-579) plus `upcomingWeatherEntries`
  /// (which becomes a private method instead of a nested function).
  private func buildWeatherEntries(config: WidgetConfig,
                                   weather: Weather,
                                   location: String?) -> [EventEntry]
}
```

`timeline(config:context:)` becomes: fetch shared inputs → switch on `config.content` to call the right builder(s) → append conflict marking (~:398-412) → fan out the 15 minute-entries. The accessoryRectangular first-header trim (~:388-393) stays in the calendar builder.

After this step `timeline(config:context:)` should be under ~120 lines. If any builder still reads a variable computed in `timeline()` that isn't in its parameter list, pass it explicitly — no captured state.

- [ ] **Step 2: Add the protocol and generic provider (same file, below the engine)**

```swift
protocol ChronographWidgetIntent: WidgetConfigurationIntent {
  var widgetConfig: WidgetConfig { get }
  static var recommendedIntents: [(intent: Self, description: String)] { get }
}

struct ChronographTimelineProvider<Intent: ChronographWidgetIntent>: AppIntentTimelineProvider {
  let engine = TimelineEngine()

  func placeholder(in context: Context) -> CalendarTimelineEntry {
    engine.placeholderEntry(context: context)
  }

  func snapshot(for configuration: Intent, in context: Context) async -> CalendarTimelineEntry {
    let timeline = await engine.timeline(config: configuration.widgetConfig, context: context)
    return timeline.entries.first!
  }

  func timeline(for configuration: Intent, in context: Context) async -> Timeline<CalendarTimelineEntry> {
    await engine.timeline(config: configuration.widgetConfig, context: context)
  }

  func recommendations() -> [AppIntentRecommendation<Intent>] {
    Intent.recommendedIntents.map { AppIntentRecommendation(intent: $0.intent, description: $0.description) }
  }
}
```

- [ ] **Step 3: Temporarily conform the old intent**

In `Common/ConfigurationIntent.swift` (this bridge is deleted in Task 4):

```swift
extension ConfigurationIntent: ChronographWidgetIntent {
  static var recommendedIntents: [(intent: ConfigurationIntent, description: String)] {
    [(comboConfig, "Events - Combined"),
     (simpleCalendarConfig, "Events - Simple"),
     (remindersConfig, "Reminders"),
     (weatherCurrentConfig, "Weather - Today"),
     (weatherDailyConfig, "Weather - This Week"),
     (timezonesConfig, "Time Zones")]
  }
}
```

- [ ] **Step 4: Swap the provider in all four widget structs**

In `Common/ChronographWidget.swift`, each of `ChronographWidget`, `RemindersWidget`, `TimezonesWidget`, `WeatherWidget` changes `provider: TimelineProvider(kind: kind)` to `provider: ChronographTimelineProvider<ConfigurationIntent>()`.

- [ ] **Step 5: Build all three schemes**

Expected: all `** BUILD SUCCEEDED **`. Behavior identical — same intent, same engine, now decoupled.

- [ ] **Step 6: Commit**

```bash
git add Common/
git commit -m "refactor: TimelineEngine + generic ChronographTimelineProvider, decoupled from intent type"
```

---

### Task 4: Four per-widget intents; delete the shared one

**Files:**
- Create: `Common/WidgetIntents.swift`
- Delete: `Common/ConfigurationIntent.swift` contents *except* the enums (see Step 1)
- Modify: `Common/ChronographWidget.swift` (widget structs)
- Modify: `Common/EventEntries.swift` (delete dead stubs referencing the old type)

**Interfaces:**
- Consumes: `ChronographWidgetIntent`, `ChronographTimelineProvider`, `WidgetConfig` from Task 3.
- Produces: `CalendarWidgetIntent`, `RemindersWidgetIntent`, `TimezonesWidgetIntent`, `WeatherWidgetIntent` — each `ChronographWidgetIntent`. `DisplayedContent` is no longer a user-facing parameter anywhere.

- [ ] **Step 1: Slim `Common/ConfigurationIntent.swift` down to the shared enums**

Keep: `FontStyle`, `WeatherStyle`, `FontSize`, `DisplayedContent`, `WidgetFeatures`, `WidgetViewOptions` (with their `AppEnum` conformances — the new intents' `@Parameter`s need them).
Delete: `struct RemindersConfigurationIntent` (dead), `struct ConfigurationIntent` including all statics and the Task 2/3 extensions. (Presets already live on `WidgetConfig`; recommendations move to the new intents.)
Optionally rename the file `WidgetEnums.swift` — if renaming, do it via `git mv` so history follows.

- [ ] **Step 2: Create `Common/WidgetIntents.swift` with the four intents**

Note: the five appearance parameters are deliberately repeated in each intent — AppIntents macros cannot share `@Parameter` declarations (Global Constraints). Each intent shows ONLY its relevant options; none has a "Widget Type" parameter.

```swift
import WidgetKit
import AppIntents

struct CalendarWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Calendar"
  static var description = IntentDescription("Upcoming events as text")

  @Parameter(title: "Calendars", default: [])
  var calendars: [CalendarSelectionEntity]

  @Parameter(title: "Show", default: [.allDayEvents, .timeBars])
  var features: [WidgetFeatures]

  @Parameter(title: "View Options", default: [])
  var viewOptions: [WidgetViewOptions]

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .medium)
  var fontSize: FontSize

  @Parameter(title: "Background (Hex)", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent (Hex)", default: "")
  var accentColor: String

  @Parameter(title: "Skip Pages", default: 0)
  var pageOffset: Int

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .calendar)
    config.calendars = calendars
    config.features = features
    config.viewOptions = viewOptions
    config.fontStyle = fontStyle
    config.fontSize = fontSize
    config.backgroundColor = backgroundColor
    config.accentColor = accentColor
    config.pageOffset = pageOffset
    return config
  }

  static var recommendedIntents: [(intent: CalendarWidgetIntent, description: String)] {
    let combo = CalendarWidgetIntent()
    combo.features = [.allDayEvents, .timeBars, .multiDayEvents, .weather]
    let simple = CalendarWidgetIntent()
    simple.features = [.allDayEvents]
    return [(combo, "Events - Combined"), (simple, "Events - Simple")]
  }
}

struct RemindersWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Reminders"
  static var description = IntentDescription("Incomplete reminders as text")

  @Parameter(title: "Lists", default: [])
  var reminderLists: [ReminderSelectionEntity]

  @Parameter(title: "View Options", default: [])
  var viewOptions: [WidgetViewOptions]

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .medium)
  var fontSize: FontSize

  @Parameter(title: "Background (Hex)", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent (Hex)", default: "")
  var accentColor: String

  @Parameter(title: "Skip Pages", default: 0)
  var pageOffset: Int

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .reminders)
    config.reminderLists = reminderLists
    config.viewOptions = viewOptions
    config.fontStyle = fontStyle
    config.fontSize = fontSize
    config.backgroundColor = backgroundColor
    config.accentColor = accentColor
    config.pageOffset = pageOffset
    return config
  }

  static var recommendedIntents: [(intent: RemindersWidgetIntent, description: String)] {
    [(RemindersWidgetIntent(), "Reminders")]
  }
}

struct TimezonesWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "World Clock"
  static var description = IntentDescription("Times across time zones")

  @Parameter(title: "Time Zones", default: [])
  var timezones: [TimeZoneSelectionEntity]

  @Parameter(title: "View Options", default: [])
  var viewOptions: [WidgetViewOptions]

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .medium)
  var fontSize: FontSize

  @Parameter(title: "Background (Hex)", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent (Hex)", default: "")
  var accentColor: String

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .timezones)
    config.timezones = timezones.isEmpty ? WidgetConfig.timezones.timezones : timezones
    config.viewOptions = viewOptions
    config.fontStyle = fontStyle
    config.fontSize = fontSize
    config.backgroundColor = backgroundColor
    config.accentColor = accentColor
    return config
  }

  static var recommendedIntents: [(intent: TimezonesWidgetIntent, description: String)] {
    [(TimezonesWidgetIntent(), "Time Zones")]
  }
}

struct WeatherWidgetIntent: WidgetConfigurationIntent, ChronographWidgetIntent {
  static var title: LocalizedStringResource = "Weather"
  static var description = IntentDescription("Forecast as text")

  @Parameter(title: "Weather Style", default: .current)
  var weatherStyle: WeatherStyle

  @Parameter(title: "View Options", default: [])
  var viewOptions: [WidgetViewOptions]

  @Parameter(title: "Font Style", default: .normal)
  var fontStyle: FontStyle

  @Parameter(title: "Font Size", default: .medium)
  var fontSize: FontSize

  @Parameter(title: "Background (Hex)", default: "")
  var backgroundColor: String

  @Parameter(title: "Accent (Hex)", default: "")
  var accentColor: String

  var widgetConfig: WidgetConfig {
    var config = WidgetConfig(content: .weather)
    config.weatherStyle = weatherStyle
    config.features = [.weather]
    config.viewOptions = viewOptions
    config.fontStyle = fontStyle
    config.fontSize = fontSize
    config.backgroundColor = backgroundColor
    config.accentColor = accentColor
    return config
  }

  static var recommendedIntents: [(intent: WeatherWidgetIntent, description: String)] {
    let current = WeatherWidgetIntent()
    let daily = WeatherWidgetIntent()
    daily.weatherStyle = .daily
    return [(current, "Weather - Today"), (daily, "Weather - This Week")]
  }
}
```

(The `let x = Intent(); x.property = ...` mutation pattern works because `@Parameter` has reference semantics — it's the same pattern the old statics used. Note `WeatherWidgetIntent.widgetConfig` sets `features = [.weather]` so the engine's `showWeather` check stays true regardless of content-specific logic.)

- [ ] **Step 3: Point each widget at its intent**

In `Common/ChronographWidget.swift`:

```swift
// ChronographWidget (kind "calendar"):
AppIntentConfiguration(kind: kind, intent: CalendarWidgetIntent.self,
                       provider: ChronographTimelineProvider<CalendarWidgetIntent>()) { ... }
// RemindersWidget (kind "reminders"): RemindersWidgetIntent
// TimezonesWidget (kind "timezones"): TimezonesWidgetIntent
// WeatherWidget  (kind "weather"):   WeatherWidgetIntent
```

Kind strings unchanged. `configurationDisplayName` strings stay as they are.

- [ ] **Step 4: Delete the dead stubs**

In `Common/EventEntries.swift` delete `func fetchReminders(configuration: ConfigurationIntent? ...)` and `func fetchEvents(calendarIDs:configuration:...)` (`:176-184`) — both return `[]`, nothing calls them, and they reference the deleted type.

- [ ] **Step 5: Grep for stragglers, then build all three schemes**

```bash
grep -rn "ConfigurationIntent" --include="*.swift" . | grep -v "ClockConfigurationIntent\|WidgetConfigurationIntent"
```

Expected: no hits. Then the three builds — all `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Verify configuration sheets in the simulator**

Run "Chronograph iOS" in an iPhone simulator. Delete any previously-added Chronograph widgets (stale intent data). Add each widget fresh from the gallery, then long-press → Edit Widget:

| Widget | Must show | Must NOT show |
|---|---|---|
| Calendar | Calendars, Show, View Options, fonts, colors, Skip Pages | Widget Type, Lists, Time Zones, Weather Style |
| Reminders | Lists, View Options, fonts, colors, Skip Pages | Widget Type, Calendars, Weather Style |
| World Clock | Time Zones, View Options, fonts, colors | Widget Type, Calendars, Lists, Skip Pages |
| Weather | Weather Style, View Options, fonts, colors | Widget Type, Calendars, Lists, Skip Pages |

And each widget must render its own content type immediately on add — no calendar-by-default (A-154).

- [ ] **Step 7: Commit**

```bash
git add Common/
git commit -m "feat: per-widget configuration intents; content type fixed per widget (A-154)"
```

---

### Task 5: Clock widget correctness + render verification

**Files:**
- Modify: `Common/ClockWidget.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks (Clock already has its own `ClockConfigurationIntent` + `Provider`). Independent of Tasks 2–4.

- [ ] **Step 1: Make the adaptive-minutes logic explicit and safe**

In `ClockWidgetView.body`, replace:

```swift
let hour = Calendar.current.dateComponents([.hour], from: now)

let showHour = style == .hour || style == .time || style == .timeAdaptive
let showMinute = style == .minute || style == .time || style == .timeAdaptive && hour.hour! > 6
```

with:

```swift
let hour = Calendar.current.component(.hour, from: now)

let showHour = style == .hour || style == .time || style == .timeAdaptive
let showMinute = style == .minute || style == .time || (style == .timeAdaptive && hour > 6)
```

Same behavior (`&&` already bound tighter), but no force-unwrap and no precedence trap. The widget's stated purpose — "only shows hours overnight" — now reads directly.

- [ ] **Step 2: Add previews that pin the adaptive behavior**

Replace the existing `#Preview` block with one that covers night vs day and each style:

```swift
#Preview("Adaptive", as: .systemSmall) {
  ClockWidget()
} timeline: {
  ClockEntry(date: Calendar.current.date(bySettingHour: 3, minute: 24, second: 0, of: .now)!,
             configuration: ClockConfigurationIntent())
  ClockEntry(date: Calendar.current.date(bySettingHour: 14, minute: 24, second: 0, of: .now)!,
             configuration: ClockConfigurationIntent())
}
```

Expected in the preview canvas: the 3:24 entry shows only "3"; the 14:24 entry shows "2" with small "24".

- [ ] **Step 3: Verify in the simulator**

Build & run "Chronograph iOS". Add the "StandBy Clock" widget (systemSmall) to the home screen. Expected: large thin-weight hour digit, smaller minutes, centered, no clipping at the frame edges; with a Background hex set in its config, the color fills the container; in accented rendering mode (StandBy/tinted home screen) the background goes clear.

- [ ] **Step 4: Build all three schemes** (Clock is iOS-only via `#if os(iOS)` in `iOS/Widget/Bundle.swift` — confirm Mac/Watch still build untouched)

- [ ] **Step 5: Commit**

```bash
git add Common/ClockWidget.swift
git commit -m "fix: clock widget — explicit adaptive-minutes logic, no force unwrap, pinned previews"
```

---

### Task 6: Weather rendering verification + weather-path cleanup

**Files:**
- Modify: `Common/WidgetTimeline.swift` (weather entry construction)
- Modify: `Common/ChronographRow.swift` (dead binding in `CurrentWeatherRowView`)

**Interfaces:**
- Consumes: `WeatherWidgetIntent` → `WidgetConfig` path from Task 4.

- [ ] **Step 1: Remove debug prints and dead code from the weather path**

In `Common/WidgetTimeline.swift`, inside `upcomingWeatherEntries`:
1. Delete `let _ = print(weather.hourlyForecast.map({$0.date}))` (~`:439`).
2. Delete `print("entries", entries.map({$0.title}))` (~`:542`).
3. Delete the no-op sunrise block (~`:450-457`) — it constructs an `EventEntry` and discards it; a working sunrise entry is already appended later from `dailyForecast` (~`:503`). (This is A-158 item 2; the rest of A-158 stays out of scope.)
4. Delete the unused bindings the compiler flags in this function: `now`, `in24Hr`, `forecast` (~`:418-420`), `tommorowForecast` (~`:437`), `sunrise` (~`:445`), and the unused `highTemp`/`lowTemp` in their `if let`s (keep the `...Time` bindings that are used).

In `Common/ChronographRow.swift` `CurrentWeatherRowView.body`, delete the unused `let currentMinute = ...` (~`:305`) and the unused `(hour, minute, ampm)` destructuring (~`:308`) — keep `if let date = entry.startDate` since it gates the body.

- [ ] **Step 2: Build all three schemes**

Expected: all green, and the weather-related "unused value" warnings from the Mac build log are gone.

- [ ] **Step 3: Verify all three weather styles in the simulator**

Setup: simulator needs a location — Features → Location → Apple (or a custom one). Run "Chronograph iOS", grant location when prompted.

1. In-app Weather tab: expected a "NOW" row (condition + temperature), then High / Low / Sunset / Night rows in chronological order, each with an SF Symbols condition icon. No "Loading..." stuck state.
2. Home screen: add the Weather widget → expected: weather content immediately (not a calendar — regression check on A-154).
3. Edit Widget → Weather Style → **Hourly**: expected up to 24 rows, times ascending from the current hour, temperature + condition per row, precipitation % only on rows with chance > 0.
4. Weather Style → **Daily**: expected up to 10 rows, weekday abbreviations, low—high span bar per row.
5. Screenshot each state for the record.

Known environmental caveat: WeatherKit in the simulator requires the app to be signed with the real team (entitlement `com.apple.developer.weatherkit`). If every style renders empty, check the build log for a WeatherKit auth error before suspecting this refactor — and note the Mac *widget* target is missing the entitlement entirely (tracked as A-155, out of scope here).

- [ ] **Step 4: Commit**

```bash
git add Common/
git commit -m "fix: weather path — remove debug prints, dead sunrise entry, unused bindings"
```

---

### Task 7: Full gallery matrix pass + close out Linear

**Files:** none (verification only)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Fresh-install matrix in the iOS simulator**

Erase content on the simulator (or delete the app) so no stale serialized intents survive. Reinstall, grant calendar/reminders/location. Add all five widgets from the gallery and verify each renders its own content with zero configuration:

| Widget | Expected default render |
|---|---|
| Calendar | Day headers + events (or permission error row) |
| Reminders | Reminder rows with circles |
| World Clock | LA / NYC / London / Tokyo rows with time-of-day icons |
| Weather | Current-conditions rows |
| StandBy Clock | Large hour + minutes |

- [ ] **Step 2: Reconfiguration smoke test**

For one widget (Calendar), change Font Size to Huge, set an Accent hex, toggle Time Bars off. Expected: widget re-renders reflecting all three within a refresh cycle.

- [ ] **Step 3: Watch + Mac spot checks**

- Watch simulator: run "Chronograph Watch"; expected the app's preview list renders; widget gallery recommendations show the per-intent descriptions ("Events - Combined", "Weather - Today", …).
- Mac: run "Chronograph Mac"; expected app launches and desktop widgets appear in the widget gallery. (Mac widget weather stays broken until A-155 — entitlement, separate issue.)

- [ ] **Step 4: Update Linear**

- A-152: mark Done (Task 1).
- A-154: mark Done, comment linking the commit from Task 4.
- A-158: comment that item 2 (discarded sunrise entry) was fixed in Task 6; items 1 and 3 remain open.
- A-162: comment that the weather-path unused-binding warnings were cleared in Task 6.

- [ ] **Step 5: Final commit if any docs changed; push only if asked**

---

## Self-Review

- **Spec coverage:** separate configs per widget → Task 4; hide irrelevant options → Task 4 parameter matrix (no Widget Type anywhere); reuse shared logic → Tasks 2–3 (`WidgetConfig`, `TimelineEngine`, generic provider, shared enums/entities/views); clock renders correctly → Task 5; weather renders correctly → Task 6; regression safety → build gates every task + Task 7 matrix. No gaps found.
- **Placeholder scan:** clean — every code step has concrete code or exact before/after; verification steps have commands and expected output.
- **Type consistency:** `WidgetConfig` field names (`reminderLists`, `calendars`, `timezones`, `weatherStyle`, `viewOptions`, `pageOffset`) match between Task 2's struct, Task 2's mapping extension, and Task 4's intents. `ChronographWidgetIntent.recommendedIntents` name matches between Task 3's protocol/provider and Task 4's implementations. `TimelineEngine.timeline(config:context:)` matches its call sites in Tasks 3 (provider) and 2→3 (`WidgetPreviewView`).
