# Feature parity

✅ shipped · ➖ not applicable / no plan · 🔜 planned (linked)

| Feature | iOS | macOS | watchOS | Android |
|---|---|---|---|---|
| Calendar widget | ✅ | ✅ | ✅ | ✅ |
| Note / meeting / attachment rows | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Description boilerplate stripping | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Reminders widget | ✅ | ✅ | ✅ | ➖ [^reminders] |
| Time Zones widget | ✅ | ✅ | ✅ | ✅ (Glance + live TextClock) |
| Weather widget | ✅ | ✅ [^macweather] | ✅ | 🔜 [phase 3](specs/2026-08-03-android-port-design.md) |
| Weather via zip code | ✅ | ✅ | ✅ | 🔜 [phase 3](specs/2026-08-03-android-port-design.md) |
| StandBy Clock widget | ✅ (StandBy and home screen) | ➖ | ➖ | ➖ (no StandBy analogue) |
| Lock screen / accessory widgets | ✅ (`accessoryRectangular`) | ➖ | ✅ | 🔜 [^keyguard] |
| Extra-large page widget | 🔜 (iOS 27, declared) | ➖ | ➖ | ➖ |
| Obfuscation — Braille | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Obfuscation — Enigma (CMUdict IPA) | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Enigma — acronyms & URLs pass through | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Obfuscation — Ishihara font | ✅ | ✅ | ✅ | ➖ [^ishihara] |
| Per-widget configuration | ✅ (AppIntents sheet) | ✅ | ✅ | ✅ (config activity, reconfigurable) |
| App-wide Default Size | ✅ (Display Options picker; widget Font Size "Default") | ✅ | ✅ (Display section of the Watch app) | ✅ (home-screen slider; "Use default size" switch) |
| In-app widget defaults ("Use App Defaults") | 🔜 toggle on the widget, no editor yet ([plan](plans/2026-11-20-in-app-widget-defaults.md)) | 🔜 same | ✅ (per-kind forms in the Watch app; "App Defaults" presets) | 🔜 (size only today) |
| Transparent background | ✅ (clear default) | ✅ | ➖ | ✅ (per-widget toggle, default on) |
| Wallpaper-adaptive text | ➖ (system vibrancy) | ➖ | ➖ | ✅ (WallpaperColors hint) |
| Time bars | ✅ | ✅ | ✅ | ✅ |
| Accent color | ✅ (hex field) | ✅ | ✅ | ✅ (presets) |
| Widget gallery previews | ✅ (`recommendedIntents`) | ✅ | ✅ | ✅ (generated previews) |
| Dynamic system color | ➖ | ➖ | ➖ | ✅ (Material You via GlanceTheme) |
| 24-hour time | ✅ (locale / system setting) | ✅ | ✅ | ✅ (system 24-hour setting) |
| Current-location weather prompt | ✅ | ✅ | ✅ | ➖ (no weather yet) |

[^reminders]: Android has no system reminders store; the nearest equivalent (Google Tasks API) needs OAuth + Play verification — disproportionate for one widget type. See the design spec's key decisions.
[^macweather]: The Mac widget extension carries the WeatherKit and outgoing-network entitlements as of the release-polish pass; a signed build has not yet been checked against live WeatherKit.
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

Rows are intrinsically sized on iOS, and `ChronographWidget.swift` packs them
with an estimate of that size (`rowHeight`). Glance cannot measure a row
containing a `fillMaxHeight` child, so `:core`'s `EventLayout` ports the same
estimate — title wrap from the column width at a 0.55 em mean advance, two
unspread text lines when it wraps, one small line per location / attachment /
attendee line, a note's second line on a newline or by length — and Android
lays every row out at exactly that height *and* packs with it. A title is
given two lines only when the estimate says so; otherwise it is one line with
an ellipsis, so no glyph is cut by the row's height. `eventHeight`/
`headerHeight` in CalendarWidget.kt spend that budget.

### Detail rows

Same order and gates as `EventRowView`: the block shows when the row is
happening or soon and has a location, attachments or a note; the meeting link
is drawn only inside the location line (as on iOS, an event with a Zoom link
and no location shows no meeting row); every attachment gets a line; the
attendee line (FacePile) shows above two attendees; the note is
`lineLimit(2)`. SF Symbols are Material Symbols vectors in `res/drawable`
(`ic_row_meeting`, `ic_row_link`, `ic_row_document`, `ic_row_chat`,
`ic_row_attendees`, `ic_row_conflict` for `exclamationmark.triangle`), tinted
with the row's secondary colour and sized to the small font, where iOS uses
`.foregroundStyle(.secondary)`. No emoji stand-ins remain in the calendar row. Time Zones day parts use Material Symbols vectors (`ic_daypart_*`) in place of the SF Symbols, tinted with the average of that hour's two daylight-gradient stops, because a Glance tint is one colour.

Note cleanup (shared, fixture-verified on both platforms) treats Zoom for
Workspace's "Zoom Meeting Info" block as boilerplate, drops `Telephone:` dial-in
lines, and strips the emoji bullets conferencing tools put at the start of a
line (📹, ☎️). Emoji inside a sentence are kept on both platforms. Title emoji
follow `extractEmoji`: pulled out and drawn after the title at the small size.

### What Glance cannot reproduce

| iOS | Why not |
|---|---|
| `.kerning(1)` on day names | `TextStyle` has no letter spacing |
| `.weight(.light)` on the large day number | Glance exposes Normal/Medium/Bold only |
| `.weight(.semibold)` on small text | same; Medium is used, 600 sits between Medium and Bold |
| `.baselineOffset` on compact minutes | `Text` takes a String, so no spans — the time is an `AndroidRemoteViews` `TextView` carrying `RelativeSizeSpan` + `SuperscriptSpan` instead. A Row's `verticalAlignment` is **not** a substitute: Top and Bottom both render the minutes on the shared baseline, i.e. as a subscript |
| SF Symbols inline in a `Text` run | an `Image` cannot sit inside a `Text`, so each symbol is a sibling in the line's Row, centred on the line rather than on the text baseline |
| HStack truncation that keeps a trailing symbol beside a long title | a Glance Row cannot shrink one child for the next; a title (or attendee list) estimated to fill its line takes the row's weight, so the conflict symbol / count sits at the line end, and a short one keeps its natural width with the symbol right after it |
| `<initial>.circle` calendar symbol | a circled-letter glyph (ⓐ…ⓩ) stands in |
| Attributed (HTML) notes | `Text` takes a String; HTML is stripped to plain text |

iOS reserves an attendee line for any event with attendees even when FacePile
draws nothing (two or fewer); Android counts the line only when it draws it.

A fixed Glance width also cannot behave like a SwiftUI `minWidth`, so the Time
Zones clock column is `fontSize * 2.9` rather than `keyline` — narrowing it to
the keyline clips the meridiem off "11 AM".
