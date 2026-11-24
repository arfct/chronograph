# In-app widget defaults (Apple Watch first)

**Goal:** the app holds a set of default options for each widget kind
(Calendar, Reminders, Time Zones, Weather), editable in SwiftUI. A widget
either follows the defaults for its kind or uses its own values. The Watch app
gets the editor first; the model, the resolver and the views are shared code so
the iOS and Mac apps can adopt them later without a second design.

**Why the Watch first:** it is where the gap is widest. watchOS 11 and earlier
have no interface for configuring a widget at all, and on watchOS 26 and later
an interface exists only when `recommendations()` returns an empty array, which
ours does not. Every Chronograph widget on a watch today is one of six fixed
presets (`recommendedIntents` in `apple/Common/WidgetIntents.swift`), and none
of the per-widget options (font, size, colours, which calendars, which time
zones, forecast style, zip code) can be changed there.

## The resolution rule

Each of the four widget intents gets one new parameter:

```swift
@Parameter(title: "Use App Defaults", default: false)
var useDefaults: Bool
```

- **On:** every setting comes from the app's stored defaults for that widget
  kind. A setting the app has not stored falls back to the built-in default.
  The widget's own parameters are ignored (they stay stored, so turning the
  toggle off brings them back).
- **Off:** the widget's own parameters apply exactly as they do today.

So the order is: widget's own values when the toggle is off; otherwise app
default for the kind; otherwise built-in default. The built-in defaults equal
today's `@Parameter` defaults.

**Font Size keeps its `Default` case** (`FontSize.automatic`, App Group key
`defaultFontSize`). With the toggle off it still means "the app-wide Default
Size". A kind's stored default may also be `Default`, which falls through to the
app-wide size the same way. No other parameter gets a per-parameter sentinel.

**The editing sheet.** Each intent's `parameterSummary` lists the toggle first
and shows the rest only when it is off:

```swift
static var parameterSummary: some ParameterSummary {
  When(\.$useDefaults, .equalTo, false) {
    Summary { \.$useDefaults; \.$calendars; \.$features; /* …all of today's… */ }
  } otherwise: {
    Summary { \.$useDefaults }
  }
}
```

Weather nests its existing `When(\.$useCurrentLocation …)` inside the first
branch, so Zip Code still appears only when it applies.

| Platform | Compiles | Hides the other parameters when the toggle is on |
|---|---|---|
| iOS | yes (scheme builds) | expected: it is the same mechanism that already hides Zip Code in the Weather sheet. Not checked on a Home Screen in this PR |
| macOS | yes (scheme builds) | untested. The same `parameterSummary` drives the Mac's Edit Widget panel; nobody has looked at it with this change |
| watchOS | yes (scheme builds) | not applicable today: the watch shows no editing interface because `recommendations()` is not empty. Each preset carries the toggle's value instead (see Migration) |

**Where it resolves.** `WidgetConfig` (the plain struct every intent resolves
to) gains `useDefaults`. `TimelineEngine.timeline(config:)` calls
`config.resolved()` first, so widgets and in-app previews share one code path
and no view ever reads the toggle.

## Per-parameter table

`WidgetDefaults` is one Codable struct; the "Stored as" column is its field.
Everything is stored per widget kind under `widgetDefaults.<kind>`.

| Parameter | Widget kinds | Stored as | Watch control (this PR) | iOS later |
|---|---|---|---|---|
| Calendars | Calendar | `calendarIDs` (empty = all; the engine's existing fallback to `enabledCalendars` still applies) | calendars grouped by account, tap to toggle | the same view replaces `CalendarSettingsView`'s list; `enabledCalendars` is read once into the struct |
| Lists | Reminders | `reminderListIDs` (empty = all; same fallback to `enabledReminders`) | reminder lists, tap to toggle | the same view replaces `RemindersSettingsView`'s list |
| Time Zones | Time Zones | `timezoneIDs` (empty = the four built-in cities) | regions → cities, tap to toggle; chosen zones listed first with a Reset | same view plus `.searchable`; `favoriteTimezones` is read once into the struct |
| Show (`features`) | Calendar | `features` | one toggle per option. Time Bars is hidden: never drawn at watch width | all toggles |
| View Options | Calendar | `viewOptions` | Show Colors toggle. Remove Padding is hidden: the watch family is always full bleed | both toggles |
| Remove Padding | Reminders, Time Zones, Weather | `viewOptions` (`.fullBleed`) | none: no effect on the watch | toggle |
| Forecast | Weather | `weatherStyle` | picker: Current / Hourly / Daily | same picker |
| Use Current Location | Weather | `useCurrentLocation` | toggle | toggle; `weatherUseCurrentLocation` is read once into the struct |
| Zip Code | Weather | `zipCode` | text field (keyboard, dictation or Scribble), shown when the toggle is off | text field; `weatherZipCode` is read once |
| Font Style | all four | `fontStyle` | picker | same picker |
| Font Size | all four | `fontSize` (`automatic` = app-wide Default Size) | picker: Default + five sizes | same picker |
| Background Color (hex) | all four | `backgroundColor` (hex string; empty = system glass) | preset swatches; a stored value that is not a preset shows as "Custom" and is kept | swatches plus the hex field or a `ColorPicker` |
| Accent Color (hex) | all four | `accentColor` (hex string; empty = default accent) | preset swatches | swatches plus the hex field or a `ColorPicker` |
| Skip Pages | Calendar, Reminders | **not stored.** It exists so two widgets side by side differ; a widget on app defaults shows page 0 | none | none |
| Use App Defaults | all four | — (it is the switch, per widget) | none (set by the preset) | first row of the editing sheet |

Obfuscation, Compact Time, Wrap Parentheses and the app-wide Default Size stay
app-global keys: they are not widget parameters and are not part of this model.

## Migration: widgets already placed

A widget placed before this change has no stored `useDefaults`. If the
parameter defaulted to `true`, that widget would take the new default on its
next reload and drop its custom font, colours and selections. That must not
happen.

**Mechanisms considered**

| Mechanism | Outcome |
|---|---|
| Rely on the declared `@Parameter` default for the missing value | WidgetKit is expected to fill a parameter missing from a stored intent with the declared default (not observed, see below). That is the same value a brand-new widget gets, so one constant cannot be `true` for new widgets and `false` for old ones |
| A version marker parameter on the intent | same problem: the marker is also missing on old widgets and also takes its declared default, which is what a new widget gets |
| An optional `Bool?` with `nil` meaning "placed before" | a new widget is `nil` too |
| Treat "toggle on, but some other parameter differs from its built-in default" as an old customized widget | tells old from new, but the same stored state is also "turned off, customized, turned on again", so the toggle could never bring a customized widget back to the defaults, and the sheet would show On for a widget using its own values |
| Have the app fingerprint the placed widgets at first launch (`WidgetCenter.getCurrentConfigurations`) | needs the app to run before the widget reloads, cannot tell a new widget from an old one with the same values, and has the same "cannot turn it back on" hole |

None of these is reliable, because the stored state of an old widget and of a
new one with the same values is identical once both read the same declared
default.

**Decision: the declared default is `false`.** A placed widget reads `false`
and keeps its own values with certainty, and its sheet shows the toggle off
with its options visible, which is the truth. The cost is that a new widget on
iOS and macOS also starts off. That cost is nil in this PR, because iOS and
macOS have no editor for the defaults yet: a new widget defaulting to on would
hide every option behind defaults nobody can change.

**Where new widgets do start on:** the Watch. A watch widget is created from a
preset, and a preset is an intent we build, so it can set the toggle
explicitly:

- The six existing presets are unchanged (same descriptions, same values,
  toggle off), so a complication already on a face is the same intent as
  before.
- Four presets are appended, one per kind, with the toggle on: "Events - App
  Defaults", "Reminders - App Defaults", "Time Zones - App Defaults",
  "Weather - App Defaults". These are the ones the Watch app's editor drives.

**Not tested:** what WidgetKit does with a parameter missing from a stored
intent was not observed on a device or simulator (placing and editing a widget
cannot be scripted with `simctl`). The decision does not depend on it: `false`
keeps placed widgets as they are whether the system fills the gap with the
declared default or rebuilds the intent from `init()`.

**When iOS gets the editor**, making new widgets start on is the same question
again, with the same options. It is open question 1.

## Storage and reload

- **One Codable struct per widget kind**, `WidgetDefaults`, stored as a JSON
  string under `widgetDefaults.<kind>` in the App Group suite
  (`Keys.suiteName`). The kind is the existing `DisplayedContent` raw value,
  which is also the WidgetKit kind string. Decoding takes each field on its own
  and falls back to the built-in value, so a later version can add or drop a
  field without losing what is stored.
- **One struct type for all four kinds**: the appearance fields are common, and
  a kind ignores the fields it has no control for. Four types would repeat them
  and split the form.
- **Who reads it:** the app (editor and previews) and the widget extension on
  the same device, through the shared suite. The Watch app and the Watch widget
  share the watch's own App Group container.
- **When a widget picks up a change:** every save calls
  `WidgetCenter.shared.reloadTimelines(ofKind:)` for that kind. The in-app
  preview reloads on `UserDefaults.didChangeNotification`, as it already does.
- **iPhone and Watch defaults are separate.** An App Group does not span
  devices. Syncing them needs WatchConnectivity (`updateApplicationContext`
  with the four JSON values) and is open question 3.

## Shared code, and how iOS adopts it

| File | Holds | Platform-specific parts |
|---|---|---|
| `apple/Common/WidgetDefaults.swift` | the struct, built-in values, `WidgetDefaultsStore`, `WidgetConfig.resolved(with:)`, the colour presets, the DEBUG self-check | none |
| `apple/Common/Settings/WidgetDefaultsView.swift` | `WidgetDefaultsForm` (one kind) with its selection pickers, and `WidgetKindLabel` | `#if os(watchOS)` only for picker style, the fixed preview height and hiding the options the watch never draws |
| `apple/Watch/ContentView.swift` | the Watch home: wordmark, the four kinds, Display (Default Size, Obfuscation), Access | watch only |

Both shared files compile into the iOS and Mac apps in this PR, unused, so the
build proves they are portable. iOS adoption is then: push `WidgetDefaultsForm`
from each tab's settings button, read the existing `enabledCalendars`,
`enabledReminders`, `favoriteTimezones`, `weatherUseCurrentLocation` and
`weatherZipCode` keys into the struct once, and build each tab's preview from
`WidgetConfig(content:useDefaults: true)`. Those five keys are already half of
this feature: they drive the iOS previews, and two of them are the engine's
fallback for an empty widget selection.

## What ships now, what ships later

**Now (this PR):**
- `useDefaults` on the four intents with the conditional `parameterSummary`,
  the model, store and resolver, on all Apple platforms;
- the Watch app home listing the four kinds, each pushing its form with a live
  preview on top; Default Size and Obfuscation in a Display section; the
  permission buttons in an Access section;
- the four "App Defaults" watch presets;
- DEBUG launch arguments for screenshots (`-openWidgetDefaults <kind>`, `-widgetDefaultsSelection YES`,
  `-widgetDefaultsAnchor <section>`, `-widgetDefaultsPatch <json>`) and a DEBUG
  resolver self-check (`-checkWidgetDefaults`), since there is no test target.

**Later:**
- the iOS and Mac editor (reusing the form) and the one-time read of the five
  keys;
- hex entry or `ColorPicker` on iOS;
- iPhone ↔ Watch sync;
- making watch widgets configurable on watchOS 26 and later (empty
  `recommendations()` behind an availability check);
- Android: the same toggle over `AppPrefs`/`WidgetPrefs`, which already has
  "Use default size".

## Verification

- All six schemes build unsigned with 0 warnings, which is the compile check
  for the `parameterSummary` on iOS, macOS and watchOS.
- `-checkWidgetDefaults` on the watch simulator: the self-check logs one line
  per case and a total. It covers: toggle off returns the config untouched
  whatever is stored; toggle on with nothing stored equals each intent's
  built-in defaults; toggle on takes every stored field; Font Size `Default`
  survives resolution; Skip Pages resets; Weather keeps its weather feature;
  and a JSON round trip with a missing, an unknown and an invalid field.
- Watch simulator screenshots of the home list, each form, and a changed
  default showing in the preview.
- Not verifiable from the simulator command line: a widget on a watch face or
  in the Smart Stack picking up a changed default, the editing sheet on iOS and
  macOS, and anything needing a signed build (the shared App Group container,
  WeatherKit).

## Open questions

1. **New iOS and Mac widgets starting on app defaults.** Proposed: leave the
   declared default `false` until the iOS editor ships, then decide. The only
   way found to flip it without touching placed widgets is the "some parameter
   differs from built-in" rule above, with its cost that such a widget cannot
   be switched back to the defaults by the toggle alone.
2. **Watch presets.** Proposed: keep the six and append the four "App Defaults"
   entries (ten in the picker). Alternatives: turn the toggle on in the existing
   Reminders and Time Zones presets instead of adding two (their values are all
   built-in, but it changes an intent that may be on someone's face), or return
   no recommendations on watchOS 26 and later so each widget is edited on the
   watch.
3. **iPhone ↔ Watch sync.** Proposed: none for now; the watch is set on the
   watch. Alternative: one-way push from the phone, or two-way with
   last-writer-wins per kind.
4. **Two levels of size default.** Proposed: keep the app-wide Default Size and
   let a kind override it. Alternative: drop the app-wide key once every kind
   has its own.
5. **Colours.** Proposed: a short swatch list for each of background and accent
   on the watch. The list is a guess and wants a designer's pick.
6. **Where the editor lives on iOS.** Proposed: behind each tab's existing
   settings button, replacing the per-tab sheets. Alternative: one Widgets
   screen like the watch's.
7. **Watch home previews.** The two always-on previews on the Watch home move
   into the Calendar and Reminders forms. Proposed: keep it that way; the home
   becomes a short list.
