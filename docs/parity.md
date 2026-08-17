# Feature parity

✅ shipped · ➖ not applicable / no plan · 🔜 planned (linked)

| Feature | iOS | macOS | watchOS | Android |
|---|---|---|---|---|
| Calendar widget | ✅ | ✅ | ✅ | ✅ |
| Note / meeting / attachment rows | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Description boilerplate stripping | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Reminders widget | ✅ | ✅ | ✅ | ➖ [^reminders] |
| Time Zones widget | ✅ | ✅ | ✅ | ✅ (Glance + live TextClock) |
| Weather widget | ✅ | ➖ [^macweather] | ✅ | 🔜 [phase 3](specs/2026-08-03-android-port-design.md) |
| Weather via zip code | ✅ | ➖ | ✅ | 🔜 [phase 3](specs/2026-08-03-android-port-design.md) |
| StandBy Clock widget | ✅ | ➖ | ➖ | ➖ (no StandBy analogue) |
| Lock screen / accessory widgets | ✅ (`accessoryRectangular`) | ➖ | ✅ | 🔜 [^keyguard] |
| Extra-large page widget | 🔜 (iOS 27, declared) | ➖ | ➖ | ➖ |
| Obfuscation — Braille | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Obfuscation — Enigma (CMUdict IPA) | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Enigma — acronyms & URLs pass through | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Obfuscation — Ishihara font | ✅ | ✅ | ✅ | ➖ [^ishihara] |
| Per-widget configuration | ✅ (AppIntents sheet) | ✅ | ✅ | ✅ (config activity, reconfigurable) |
| Transparent background | ✅ (clear default) | ✅ | ➖ | ✅ (per-widget toggle, default on) |
| Wallpaper-adaptive text | ➖ (system vibrancy) | ➖ | ➖ | ✅ (WallpaperColors hint) |
| Time bars | ✅ | ✅ | ✅ | ✅ |
| Accent color | ✅ (hex field) | ✅ | ✅ | ✅ (presets) |
| Widget gallery previews | ✅ (`recommendedIntents`) | ✅ | ✅ | ✅ (generated previews) |
| Dynamic system color | ➖ | ➖ | ➖ | ✅ (Material You via GlanceTheme) |

[^reminders]: Android has no system reminders store; the nearest equivalent (Google Tasks API) needs OAuth + Play verification — disproportionate for one widget type. See the design spec's key decisions.
[^macweather]: The Mac widget target is missing the WeatherKit entitlement (Linear A-155).
[^keyguard]: Declared (`widgetCategory="home_screen|keyguard"`, registers on API 37) but the phone emulator exposes no lock-screen widget surface yet — enabled wherever the OS offers the glanceable hub.
[^ishihara]: Glance cannot apply bundled custom fonts (phase-1 spike, 2026-08-03); the bitmap-row workaround isn't worth one novelty mode.

## Row layout

The row kernel is shared arithmetic, not a redrawing by eye: `RowMetrics`
reproduces `RowViewConfig` exactly, including the values iOS derives rather than
declares.

| Constant | iOS | Android |
|---|---|---|
| `fontSize` | `UIFont.preferredFont(forTextStyle:).pointSize` | `FontSize.sp` |
| base line height | `…​.lineHeight` | `FontSize.lineHeightSp` |
| `lineHeight` | `min(base, height / minLines) * 1.5` | same |
| `keyline` | `fontSize * 2.25` (compact time) | same |
| `smallFontSize` | `fontSize * 0.66` | same |
| `smallLineHeight` | `lineHeight * 0.66` | same |
| `columnSpacing` | `fontSize / 6` | same |
| container inset | `min(margins.leading, fontSize/2)` × `margins.top/2`, or `margins.top/8` full bleed | `WidgetInsets` |

`lineHeightSp` carries the real per-style values (13/18/22/25/34) because the
ratio to point size is not constant — 1.18 at caption2, 1.38 at footnote. It was
once approximated as `sp * 1.2`, which shrank every row by ~8% at body size and
fit one row more than iOS does.

Rows are intrinsically sized on iOS. Glance cannot measure a row containing a
`fillMaxHeight` child, so `eventHeight`/`headerHeight` sum the same terms the
SwiftUI frames imply, and the row-packing loop spends that same budget.

### What Glance cannot reproduce

| iOS | Why not |
|---|---|
| `.kerning(1)` on day names | `TextStyle` has no letter spacing |
| `.weight(.light)` on the large day number | Glance exposes Normal/Medium/Bold only |
| `.weight(.semibold)` on small text | same; Medium is used, 600 sits between Medium and Bold |
| `.baselineOffset` on compact minutes | `Text` takes a String, so no spans — the time is an `AndroidRemoteViews` `TextView` carrying `RelativeSizeSpan` + `SuperscriptSpan` instead. A Row's `verticalAlignment` is **not** a substitute: Top and Bottom both render the minutes on the shared baseline, i.e. as a subscript |
| SF Symbols | emoji and geometric glyphs stand in |

A fixed Glance width also cannot behave like a SwiftUI `minWidth`, so the Time
Zones clock column is `fontSize * 2.9` rather than `keyline` — narrowing it to
the keyline clips the meridiem off "11 AM".
