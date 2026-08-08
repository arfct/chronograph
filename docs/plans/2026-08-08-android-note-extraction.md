# Android note & meeting extraction (parity phase 2 remainder)

**Goal:** the Android calendar widget renders what Apple's does below an event
title — meeting link, document attachments, and the human part of the
description — with calendar/conferencing boilerplate suppressed.

**Status of "phase 2":** the design spec's phase 2 (Calendar + Time Zones
widgets, config activity, previews, refresh) shipped. The outstanding item is
the one `docs/parity.md` footnotes: note/meeting extraction, which phase 1
listed as part of the `:core` port and which never landed. Android currently
does not even select `DESCRIPTION` from `CalendarContract`.

## What Apple does, as the spec to match

`TimelineEngine` (apple/Common/WidgetTimeline.swift), for events starting
within 4 hours:

1. `cleanEventNote(notes)` — cut the machine-generated tail, drop chrome lines
2. `extractAttachments(note)` — pull links out into rows, keep the remainder
3. filter conferencing/mail hosts out of the attachment list
4. `extractMeetingUrls` — the join link, rendered on its own row with a video glyph
5. remaining text becomes the note row

## Work

| # | Where | What |
|---|---|---|
| 1 | `:core/NoteCleanup.kt` | Port `apple/Extensions/NoteCleanup.swift` verbatim — markers, noise lines, `cleanEventNote` |
| 2 | `:core/EventAttachment.kt` | Port the `EventAttachment` model: host→icon mapping, `displayName`, `displayIcon`, `titleFromUrl` |
| 3 | `:core/NoteParsing.kt` | `extractMeetingUrls`, `extractAttachments`, `cleanPrefix`, `stripHtmlTags`, `cleanLocation` |
| 4 | `:core/RowEntry.kt` | `CalendarItem.description`; `RowEntry.notes` + `.attachments` |
| 5 | `:core/RowBuilder.kt` | Wire the five steps above, gated on the same 4-hour window Apple uses |
| 6 | `app/CalendarRepository.kt` | Select `Instances.DESCRIPTION` |
| 7 | `app/CalendarWidget.kt` | Meeting row, attachment rows, note row — matching Apple's order and secondary styling |
| 8 | `fixtures/` + `:core` test | Cross-language vectors for `cleanEventNote` and meeting-URL extraction, generated from Swift |
| 9 | `docs/parity.md` | Flip the calendar footnote |

## Accepted divergences

- **Rich text.** Apple renders HTML notes as an `AttributedString`. Glance
  `Text` takes a plain `String`, so Android strips tags and decodes the common
  entities. Bold/italic inside a note is lost; the text is not. (RemoteViews
  could carry a `Spanned` if this ever matters — `TimeZonesWidget` already does
  that for the clock — but it is not worth a bitmap-row detour for secondary
  text.)
- **Attachment icons.** SF Symbols `doc`/`bubble`/`link` map to Material
  equivalents already vendored in `res/drawable`.
- **Fixture scope.** `cleanEventNote` and meeting-URL extraction are pure
  string/regex work and are fixture-verified against Swift. `stripHtmlTags`
  is *not*: Apple routes it through `NSAttributedString`'s HTML parser, whose
  whitespace and entity behaviour is not reasonably reproducible in Kotlin.
  Attachment prefixes are therefore covered by Kotlin-side tests only, and the
  fixtures avoid HTML-bearing inputs.

## Verification

- `./gradlew :core:test` — parity vectors plus Kotlin-only unit tests
- `swiftc` harness `scripts/check-note-cleanup.swift` still green (Swift side unchanged)
- All three Apple schemes + Android build
- Emulator: seed an event whose description is the Gmail boilerplate plus a real
  sentence, confirm the widget shows only the sentence
