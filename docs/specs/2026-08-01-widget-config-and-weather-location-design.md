# Widget Configuration UI Pass + Weather Location — Design

**Date:** 2026-08-01
**Scope:** (1) Improve the configuration UIs for all widget types; (2) make weather fetching reliable, with per-widget choice of zip code or current location.

## Findings

The real configuration UI for widgets is the AppIntents parameter sheet
(`Common/WidgetIntents.swift`), recently split per widget type. Issues found:

- **Weather has no location control.** It always uses CoreLocation, and the
  fetch path is fragile (below). This is the root of "weather is not working
  reliably."
- **No `parameterSummary`** on any intent — parameter ordering is declaration
  order, and there is no conditional display.
- Hex color fields are tersely labeled ("Background (Hex)").
- "Weather Style" is redundant inside a Weather widget sheet.

The in-app settings sheets (`Common/Settings/*`) are partially dead:

- `WeatherSettingsView` is a non-functional stub (static list rows, fake
  search).
- `ViewOptionsView` (in CalendarSettingsView.swift) renders two empty pickers
  that only `print`, and writes keys (`fontSize`, `fontStyle`,
  `foregroundColor`, `backgroundColor`, `multicolor`, `padding`) that nothing
  reads. Dead + visibly broken.
- Timezone favorites (`Keys.favoriteTimezones`) are written but never read.
- Same setting labeled differently: "Wrap Parenthesis" vs "Tokenize
  Parentheses" (both write `Keys.tokenizeParens`).

Weather fetch (`Extensions/Weather.swift`) reliability defects:

1. Location is fetched (10 s timeout) and reverse-geocoded on **every** call,
   before the cache is even consulted — a fresh cache can't save a fetch when
   location fails.
2. Any location/geocode error throws away a perfectly good cached forecast.
3. Cache lives in `UserDefaults.standard`, not the app group, and has no
   location key.

## Design

### Weather location (per widget)

- `WidgetConfig` gains `weatherLocation: String = ""` — empty means current
  location; non-empty is a zip/postal code.
- `WeatherWidgetIntent` gains `useCurrentLocation: Bool` (default true) and
  `zipCode: String`, with a `parameterSummary` `When` clause so the zip field
  only appears when the toggle is off.
- `TimelineEngine.fetchWeather` passes `config.weatherLocation` through.

### Weather fetch rework (`WeatherLocationManager`)

- **Cache first:** a `CachedWeather` struct (weather + location name + fetch
  date) stored in the app-group defaults, keyed by location spec
  (`cachedWeather.current` / `cachedWeather.<zip>`). Fresh (< 5 min) cache
  returns immediately — no CoreLocation, no geocoder.
- **Zip mode:** `CLGeocoder.geocodeAddressString(zip)`, with the resolved
  coordinate + name cached per zip so geocoding happens once per zip, not per
  timeline reload.
- **Current-location mode:** reverse geocoding failure no longer fails the
  fetch (name becomes nil); a failed location fix falls back to the last
  cached coordinate.
- **Stale fallback:** if a fresh fetch fails for any reason, return the stale
  cached forecast instead of throwing.
- Weather widget with no weather at all renders an error row ("Unable to load
  weather") instead of an empty widget.

### Configuration UI pass (widget intents)

- Add `parameterSummary` to all four intents: content parameters first, then
  Font Style / Font Size, colors, layout (padding / pages).
- Titles: "Background (Hex)" → "Background Color (Hex)", "Accent (Hex)" →
  "Accent Color (Hex)", "Weather Style" → "Forecast". Parameter descriptions
  added where the field needs explanation (hex format, Skip Pages).
- Property names are unchanged, so saved widget configurations survive.

### In-app settings cleanup

- `WeatherSettingsView`: functional form — current-location toggle + zip
  field persisted to app-group keys (`Keys.weatherUseCurrentLocation`,
  `Keys.weatherZipCode`); the in-app weather preview tab uses them.
- Delete `ViewOptionsView` + `PaddingStyle` and the NavigationLink to it;
  per-widget appearance now lives in the widget intents.
- Timezone favorites drive the in-app Time Zones preview when non-empty.
- Unify the parentheses toggle label ("Wrap Parentheses").

### Out of scope

- Color pickers in widget config (AppIntents has no color parameter type).
- Mac widget WeatherKit entitlement (A-155).
- Migrating dead keys out of `Keys.swift` beyond what's removed above.

## Error handling

Weather: geocode failure of an invalid zip → stale cache if any, else error
row. Location permission missing in widget → same path (the existing app
onboarding already prompts for location).

## Testing

No test target exists; verification is the three-scheme build matrix
(iOS / Mac / Watch simulators) as established by the 2026-07-31 plan, plus
Xcode previews.
