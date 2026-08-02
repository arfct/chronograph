# Chronograph Android — Design

**Date:** 2026-08-03
**Goal:** A native Android version of Chronograph's text-row widgets — Calendar, Time Zones, and Weather — matching the iOS typographic feel (right-aligned time column, keyline gutter, small-caps day headers, obfuscation modes) on Glance widgets, with a Compose companion app for previews and settings.

## Scope

**In (v1):** Calendar widget (day headers, all-day/multi-day events, time bars, free time, inline day forecast), Time Zones widget, Weather widget (current / hourly / daily), per-widget configuration, the four Obfuscation modes, Play Store release.

**Out (v1):** Reminders (Android has no system reminders store — see decisions), the StandBy Clock widget (no StandBy analogue), Wear OS tiles, macOS-style desktop widgets, live/interactive widget buttons.

## Repository layout

This port restructures the repo to match `artifact-villainy`: platform directories as siblings, each build system rooted in its own.

```
apple/                     # was the repo root — Chronograph.xcodeproj + Common, Extensions,
                           # iOS, Mac, Watch, Resources, Experiments
android/
  settings.gradle.kts      # rootProject.name = "chronograph-android"; :core, :app
  gradle/libs.versions.toml
  core/                    # pure Kotlin JVM — no Android dependencies
  app/                     # Glance widgets + Compose app
  scripts/sync-assets.sh   # copies shared assets from apple/ into app/src/main/assets (gitignored)
  keystore/                # gitignored; back up outside the repo
fixtures/                  # cross-platform golden vectors, drift-checked in CI
docs/{specs,plans}
scripts/                   # generate-cmudict-ipa.py
```

`apple/` rather than `ios/` (villainy's name) for two reasons: this repo builds iOS, macOS, and watchOS targets, and the filesystem is case-insensitive, so `ios/` and the existing `iOS/` folder would collide.

The Xcode project needs **no `project.pbxproj` edits**: every source folder is a `PBXFileSystemSynchronizedRootGroup` with a plain relative path (`path = Common`) resolved against the project's own directory, so moving the project and its folders together preserves every path. The one external follow-up is repointing the Xcode Cloud workflow at `apple/Chronograph.xcodeproj` in App Store Connect.

## Key decisions

| Decision | Choice | Rationale |
|---|---|---|
| Widget framework | Jetpack Glance | The only supported way to build App Widgets in Compose. Chronograph's rows are `Row`/`Column`/`Text` — Glance's constrained composable set is a good fit, unlike the game-shaped ports where it wouldn't be. |
| Module split | `:core` (Kotlin JVM) + `:app` (Android) | Mirrors villainy. Row building, config, obfuscation, and note parsing are platform-free and JVM-testable without an emulator; only data sources and rendering need Android. |
| Row layout model | Static row count from widget size | Glance cannot measure text, so it can't do a measure-and-refit pass. iOS dropped its own refit loop on 2026-08-01 (it caused blank widgets), so both platforms now derive rows from `height / lineHeight` — the models already agree. |
| Calendar source | `CalendarContract.Instances` | Direct analogue of `EKEventStore.events(matching:)`; expands recurrences server-side in the provider, which is what the iOS predicate does. |
| Reminders | Deferred | Android has no system reminders store. The nearest equivalent is the Google Tasks REST API, which needs an OAuth consent flow and Play Console verification — disproportionate ceremony for one widget type. Revisit as its own phase. |
| Weather source | Open-Meteo | Keyless, free, no account, permissive terms; returns current/hourly/daily in one call. WeatherKit has no Android SDK, and OpenWeatherMap needs a key shipped in the client. |
| Condition icons | Material Symbols drawable set mapped from WMO codes | SF Symbols don't exist on Android, and Open-Meteo returns WMO weather codes rather than Apple's `symbolName`. One explicit code→icon+label table replaces two implicit Apple mappings. |
| Zip → coordinates | `android.location.Geocoder` | Direct analogue of `CLGeocoder.geocodeAddressString`, same per-zip caching strategy. |
| Current location | `FusedLocationProviderClient.lastLocation`, coarse permission | Widgets get no foreground time for a fresh fix; last-known plus the cached-coordinate fallback mirrors what `WeatherLocationManager` already does on iOS. |
| Forecast cache | File in app-private storage, keyed by location, 5-minute lifetime, 4 locations max | Same policy and layout as the iOS `WeatherCache` directory, for the same reason: widget reloads must never block on network or location. |
| Config storage | One `Preferences` DataStore per widget id + app-level defaults | Android widget configuration is an activity, not a declarative parameter sheet, so `WidgetConfig` is persisted per `glanceId` rather than serialized into an intent. |
| Dictionary + font | Single source of truth in `apple/`, synced into `android/app/src/main/assets/` | Villainy's `sync-assets.sh` precedent. Avoids a second copy of the 2.8 MB `cmudict-ipa.txt` in git; the same script carries `Ishihara-Regular.otf`. |
| Parity enforcement | Golden vectors in `fixtures/` + a CI drift job | Obfuscation and row building are pure functions with rich edge cases; shared vectors are the only thing that keeps two implementations honest. |

### Alternatives considered

- **Kotlin Multiplatform with a shared core consumed by both platforms.** Rejected: none of the existing logic is Kotlin, so the Swift side would have to be rewritten to gain sharing, and Swift/Kotlin interop on the Apple side adds a build-system dependency to a project that currently has none.
- **React Native / Flutter.** Rejected outright: neither can implement Android App Widgets, which *are* the product here. A companion-app-only port has no value.
- **`RemoteViews` by hand instead of Glance.** More layout control (real `TextView` measurement, custom fonts with certainty), but a large amount of XML and manual size handling. Worth reconsidering only if Glance blocks the Ishihara font or the time bar — see Risks.
- **WorkManager-driven periodic refresh.** Deferred in favor of Glance's `updateAll` plus a 15-minute `AlarmManager`/`WorkManager` tick, matching the iOS timeline reload cadence.

## The row kernel (port verbatim)

These constants define the look and must match iOS exactly; they live in `:core` as a `RowMetrics` value type derived from widget size and font size.

- **Font scale:** Tiny/Small/Medium/Large/Huge → **11 / 13 / 17 / 20 / 28 sp**, the iOS `UIFont.TextStyle` point sizes (`caption2`, `footnote`, `body`, `title3`, `title1`) at default Dynamic Type. Android has no Dynamic Type equivalent in widgets, so the points are hardcoded as sp.
- **Minimum lines per font size:** Tiny 6, Small 5, Medium 4, Large 3, Huge 2 — `lineHeight = min(fontLineHeight, widgetHeight / minLines)`, then `× 1.5`.
- **Row count:** `floor(widgetHeight / lineHeight)`.
- **Keyline (time gutter):** `fontSize × 2.25` compact, `× 2.6` non-compact.
- **Small text:** `fontSize × 0.66`, semibold — used for minutes, day names, and precipitation.
- **Column spacing:** `fontSize / 6`.
- **Compact time:** hour at full size, minutes at small size, monospaced digits, kerning −0.5, baseline-offset superscript.
- **Free time:** gaps rounded to the nearest 15 minutes, shown when ≥ 30 minutes, labelled with an Oblique Strategy chosen by `epochSeconds % strategyCount` (the strategy list ports verbatim so both platforms pick the same one).
- **Conflicts:** adjacent overlapping events mark `hasConflict`; equal start times additionally mark `hasStartConflict`.
- **Timeline:** 15 one-minute entries per build, rebuilt at the end — the Glance equivalent is one render plus a 15-minute scheduled refresh.

## Obfuscation

All four modes port to `:core`. Braille and Enigma are pure text transforms and are covered by fixtures. Enigma reads the same `cmudict-ipa.txt`, binary-searched over a memory-mapped buffer (`FileChannel.map` + `ByteBuffer`), mirroring `Cmudict.swift`; the rule-based fallback ports rule-for-rule.

Ishihara is a font swap rather than a text transform, and whether Glance can apply a bundled custom font is unverified — see Risks.

## Architecture

```
android/core/src/main/kotlin/com/artifact/chronograph/core/
  WidgetConfig.kt      # content type, features, view options, font, colors, weather location
  EventEntry.kt        # row model: type, title, dates, forecast, conflict flags
  RowBuilder.kt        # calendar / timezone / weather row assembly (TimelineEngine's builders)
  RowMetrics.kt        # the constants above
  Obfuscation.kt       # None / Braille / Ishihara / Enigma
  Cmudict.kt           # mmap + binary search
  Enigma.kt            # fallback grapheme rules
  NoteParsing.kt       # meeting URLs, attachments, locations (StringProcessing.swift)
  Weather.kt           # provider-agnostic forecast model + WMO code mapping

android/app/src/main/kotlin/com/artifact/chronograph/
  widget/              # Glance: CalendarWidget, TimeZonesWidget, WeatherWidget + receivers
  widget/RowViews.kt   # Glance composables per row type
  data/CalendarRepository.kt   # CalendarContract queries
  data/WeatherRepository.kt    # Open-Meteo client + file cache
  data/LocationRepository.kt   # fused last-known + geocoding
  config/              # per-widget configuration activities (DataStore)
  ui/                  # Compose preview/settings app
```

## Error handling

Permission and fetch failures render as an error row, exactly as iOS does — a tappable row that opens the relevant settings screen, rather than an empty widget. Missing calendar permission, missing location permission with no zip configured, and a failed forecast with no cached fallback each produce a distinct message. Weather failures fall back to the stale cache first.

## Testing

- **`:core` unit tests (JUnit 5, JVM)** for row building, metrics, note parsing, and obfuscation — no emulator.
- **`fixtures/obfuscation-vectors.json`** — input strings → expected Braille and Enigma output. Generated from the Swift implementation, consumed by both an Xcode test and a Kotlin test.
- **`fixtures/row-vectors.json`** — synthetic events + config + render timestamp → expected row types, titles, and conflict flags.
- **CI drift job** regenerates both from the Swift source of truth and fails if the committed files differ, matching villainy's `fixture-drift` job.
- Widget rendering is verified by screenshot on an emulator per phase; there is no automated widget snapshot test.

## Risks to resolve in phase 1

- **Custom fonts in Glance.** If a bundled `.otf` can't be applied to Glance `Text`, Ishihara needs another route (pre-rendered bitmap rows, or `RemoteViews` for that mode) or gets dropped on Android with a parity footnote.
- **Time bars.** iOS draws a gradient-filled rectangle; Glance has no canvas, so this becomes a `Box` with a background and fractional width, or a generated bitmap.
- **Widget size buckets.** Glance `SizeMode.Responsive` needs a fixed set of sizes; the dp buckets that best mirror iOS's `systemMedium`/`systemLarge` need to be measured on a real launcher, not assumed.

## Build order

1. **Phase 1 — restructure + scaffold + `:core`.** Repo move to `apple/`, root `.gitignore`, Gradle scaffold with `:core` and `:app`, and the pure-Kotlin port: config, entries, metrics, obfuscation with CMUdict, note parsing. Ends with `:core` tests green against the shared fixtures, and the three risks above answered by a spike.
2. **Phase 2 — Calendar + Time Zones widgets.** `CalendarContract` repository, Glance row composables, per-widget configuration activity, refresh scheduling. Ends with both widgets rendering real data on an emulator.
3. **Phase 3 — Weather.** Open-Meteo client, file cache, location and zip resolution, WMO icon mapping, the three forecast styles, and the calendar widget's inline day forecast.
4. **Phase 4 — Play release.** Signing, `docs/play-release.md`, store assets, internal testing track.
