# Chronograph Android — Design

**Date:** 2026-08-03
**Goal:** A native Android version of Chronograph's text-row widgets — Calendar, Time Zones, and Weather — matching the iOS typographic feel (right-aligned time column, keyline gutter, small-caps day headers, obfuscation modes) on Glance widgets, with a Compose companion app for previews and settings.

## Scope

**In (v1):** Calendar widget (day headers, all-day/multi-day events, time bars, free time, inline day forecast), Time Zones widget, Weather widget (current / hourly / daily), lock screen variants of all three, generated widget-picker previews, per-widget configuration, the four Obfuscation modes, Play Store release.

**Out (v1):** Reminders (Android has no system reminders store — see decisions), the StandBy Clock widget (no StandBy analogue), Wear OS tiles, macOS-style desktop widgets, live/interactive widget buttons.

Lock screen widgets are in scope only because of the modern-only baseline below — they landed in AOSP for phones and tablets after Android 16 QPR1. They are the direct analogue of iOS's `accessoryRectangular` family, which the app already supports.

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

## Platform baseline and toolchain

Deliberately modern-only: no compatibility shims, no `AppCompat`, no hand-written `RemoteViews` fallbacks, no legacy widget-preview drawables. Edge-to-edge and predictive back are platform defaults at this API level rather than opt-ins.

| | Version | Note |
|---|---|---|
| `compileSdk` / `targetSdk` | **37** (Android 17) | Stable since 2026-06-16. Requires AGP 9.1+. |
| `minSdk` | **36** (Android 16) | The aggressive floor that still has an install base; API 37 alone would be a few months of devices. Lock screen widgets arrived in a QPR after the 36.0 baseline, so that one category is runtime-gated rather than assumed. |
| AGP | **9.2** | April 2026; first line supporting API 37 (9.0 caps at 36.1). |
| Gradle | **9.5.1** | Current stable. |
| Kotlin | **2.4.0** | What Compose BOM 2026.06.00 is built against. |
| Compose BOM | **2026.06.00** | Compose 1.11.x, `material3` 1.4.0. |
| Glance | **1.2.0-rc01** | See below. |
| Material 3 Expressive | `material3` **1.5.0-alpha**, opt-in | Companion app only; behind `@ExperimentalMaterial3ExpressiveApi`. |

**On Glance versions:** stable is still **1.1.1** (October 2024) and is too old to use — it has no generated-preview API. **1.2.0-rc01** adds `providePreview()` / `setWidgetPreviews()`, `MultiProcessGlanceAppWidget`, and image alpha, which covers everything this app needs at release-candidate quality. **1.3.0-alpha02** (July 2026) is fresher still, but its additions are Wear-widget-specific (`GlanceWearWidget`, health data, wear brushes) and buy this app nothing, so taking alpha churn in the framework that renders the entire product would be cost without benefit. Pin 1.2.0-rc01, and revisit when 1.3.0 stabilizes or if a home-screen feature we want appears there.

## Key decisions

| Decision | Choice | Rationale |
|---|---|---|
| Widget framework | Jetpack Glance | The only supported way to build App Widgets in Compose. Chronograph's rows are `Row`/`Column`/`Text` — Glance's constrained composable set is a good fit, unlike the game-shaped ports where it wouldn't be. |
| Widget picker previews | `providePreview()` + `setWidgetPreviews()` | Renders the real widget with real data in the picker — the closest analogue to iOS's `recommendedIntents` gallery entries. Push-based and rate-limited to ~2 calls/hour, so previews are refreshed on first launch and after a config change, not on every timeline tick. `previewSizeMode` must be set to `SizeMode.Responsive` or the picker renders only what fits the minimum size. |
| Widget theming | `GlanceTheme` + `glance-material3` color providers | Gives widgets Material You dynamic color from the system palette, which is the Android-native equivalent of the accent/background hex fields rather than a port of them. Per-widget hex overrides still win when set. |
| Companion app UI | Compose Material 3 Expressive (opt-in alpha) | The app is only previews and settings, so experimental-API churn is cheap there — unlike the widgets, where it would put the whole product on alpha. |
| Lock screen widgets | Same Glance widgets, `keyguard` category, runtime-gated | Direct analogue of `accessoryRectangular`. The row renderer already handles a constrained height via the metrics kernel, so this is a manifest category plus a size bucket, not a second implementation. |
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

Braille and Enigma port to `:core` as pure text transforms covered by fixtures. Enigma reads the same `cmudict-ipa.txt`, binary-searched over a memory-mapped buffer (`FileChannel.map` + `ByteBuffer`), mirroring `Cmudict.swift`; the rule-based fallback ports rule-for-rule.

**Ishihara is out of scope on Android** (decided 2026-08-03): it's a font swap rather than a text transform, the spike proved Glance can't apply bundled fonts, and the bitmap-row workaround isn't worth carrying for one novelty mode. Tracked as a ➖ in docs/parity.md; revisit only if Glance grows custom-font support.

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

## Risks — resolved by the phase-1 spike (2026-08-03, Pixel 9 AVD, API 37)

- **Custom fonts in Glance: not supported.** `FontFamily("ishihara")` with the font in `res/font` renders identically to the default sans (generic families like Monospace do work). Ishihara on Android therefore needs pre-rendered bitmap rows via Glance `Image`, or ships as a parity footnote. Decide in phase 2; Braille unicode dots and IPA accents render fine in the system font, so the other three modes are unaffected.
- **Time bars: solved.** A `Box` with an explicit dp width computed from `LocalSize` under `SizeMode.Exact` gives clean fractional bars with `cornerRadius`, no canvas needed.
- **Size buckets: measured.** On a Pixel 9 grid, 4×2 = 373×212 dp and 4×5 = 373×548 dp (≈106 dp per row of cells, full width 373 dp). 4×2 is the `systemMedium` analogue (iOS: 364×170 pt); responsive buckets anchor at roughly 212/324/548 dp heights. `SizeMode.Exact` recomposes live on launcher resize.
- **Lock screen: declare and wait.** `widgetCategory="home_screen|keyguard"` is accepted and registers (`widgetCategory=3` in dumpsys) on API 37, but the phone emulator exposes no lock-screen widget surface (no glanceable-hub settings or flags). Keep the declaration — it's free — and treat lock screen as enabled-where-the-OS-offers-it rather than a testable v1 deliverable.
- **Glance 1.2.0-rc01 durability** (still open). It has sat at RC since December 2025. If it never goes stable before release, decide whether to ship on an RC dependency or drop generated previews and fall back to a static `previewImage`.

Toolchain notes from the spike: AGP 9 has built-in Kotlin — applying `org.jetbrains.kotlin.android` is an error now; `:core` needs `junit-platform-launcher` at test runtime under Gradle 9.

## Build order

1. **Phase 1 — restructure + scaffold + `:core`.** Repo move to `apple/` and the root `.gitignore` (both done 2026-08-03), Gradle scaffold on the toolchain above with `:core` and `:app`, and the pure-Kotlin port: config, entries, metrics, obfuscation with CMUdict, note parsing. Ends with `:core` tests green against the shared fixtures, and the risks above answered by a throwaway spike widget on an Android 17 emulator.
2. **Phase 2 — Calendar + Time Zones widgets.** `CalendarContract` repository, Glance row composables, `GlanceTheme` wiring, per-widget configuration activity, generated previews, refresh scheduling. Ends with both widgets rendering real data on home and lock screens.
3. **Phase 3 — Weather.** Open-Meteo client, file cache, location and zip resolution, WMO icon mapping, the three forecast styles, and the calendar widget's inline day forecast.
4. **Phase 4 — Play release.** Signing, `docs/play-release.md`, store assets, internal testing track.
