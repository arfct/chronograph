# Play Store listing — Chronograph

The three text fields Play requires, first, so `validate.py` can cross-check the
counts in these headings against the blocks themselves. Everything below them is
working notes.

Written with the `play-store-assets` skill; the voice rules live in that skill's
`reference/artifact-voice.md`.

## App name — 13 / 30

```
Chronograph³¹
```

## Short description — 71 / 80

```
Your calendar as type, not a grid. Plus the time wherever your team is.
```

## Full description — 1640 / 4000

```
It is 8:47. Coffee in one hand, phone in the other, and half a second to find out whether the next thing is in ten minutes or two hours.

Half a second is not long enough to read a grid. It is long enough to read a line of text.

Chronograph puts your day on the home screen as type. Events in the order they happen, under the day they belong to: the 9:00 with a Meet link on it, the 10:30 you are supposed to bring something to, then a header for tomorrow. Nothing is colour-coded. You already know which one is the dentist.

WIDGETS

Calendar. Your upcoming events as a text agenda. For anything starting in the next four hours it also shows the meeting link, the location, and the one line of notes a person actually typed. The Gmail and Zoom boilerplate is stripped before it reaches the screen.

Time Zones. What time it is in the cities you choose, ordered by offset, each with a small glyph for whether they are awake.

TUNING

Five text sizes. A transparent background that reads against the wallpaper, or a solid card. A default accent plus four colours. Separate toggles for all-day events, multi-day events, time bars, and the free gaps between things.

There are also two obfuscation modes, Braille and Enigma. They leave your agenda readable to you and not to the person behind you on the bus.

PRIVACY

Chronograph reads the calendar already on your device and draws it. It ships without Android's INTERNET permission, so it cannot open a network connection at all. That is enforced by the operating system, not promised in a store listing. No accounts, no analytics, no ads, no crash reporting.

Requires Android 15 or later.
```

---

## Assets in this directory

| Asset | File | Play requirement |
|---|---|---|
| App icon | `icon-512.png` | exactly 512x512 |
| Feature graphic | `feature-graphic-1024x500.png` | exactly 1024x500 |
| Phone screenshots | `phone-1-widgets.png`, `phone-2-options.png`, `phone-3-timezones.png` | 2-8, sides 320-3840, no alpha |
| 7-inch tablet | `tablet7-1-widgets.png`, `tablet7-2-options.png` | required, sides 320-3840 |
| 10-inch tablet | `tablet10-1-widgets.png`, `tablet10-2-options.png` | required, sides **1080**-7680 |

Validate before opening Play Console:

```bash
python3 ~/.claude/skills/play-store-assets/scripts/validate.py android/play
```

Two standing warnings are expected and safe: no Chromebook set (optional), and
the tablet captures are 0.625 rather than exactly 9:16. Play has accepted taller
captures for years; if an upload is ever refused, pad with the skill's
`conform.py` rather than cropping.

## Regenerating

Screenshots come from a release build on an emulator, seeded with
`android/scripts/seed-calendar.sh`, captured through the skill's `capture.py` at
three geometries. See `android/RELEASING.md`.

The feature graphic is generated from `feature-graphic.html`:

```bash
cd android/play
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --allow-file-access-from-files \
  --force-device-scale-factor=1 --hide-scrollbars --window-size=1024,500 \
  --screenshot="feature-graphic-1024x500.png" "file://$PWD/feature-graphic.html"
```

`wordmark.png` is the shipped `Wordmark.pdf` rasterised at 2400px:

```bash
qlmanage -t -s 2400 -o . ../../apple/iOS/Assets.xcassets/Wordmark.imageset/Wordmark.pdf
```

## Categorisation

| Field | Value |
|---|---|
| App category | Productivity |
| Tags | Calendar, Widgets, Productivity |
| Contact email | `support@artifact.com` |
| Privacy policy | `https://chronograph.fyi/privacy` |

## Data safety form

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all user data encrypted in transit? | N/A, no data leaves the device |
| Do you provide a way for users to request data deletion? | N/A, no data collected |

Rationale if asked: calendar data is read from the on-device provider at widget
refresh, rendered into the widget, and never transmitted. The shipped manifest
declares `READ_CALENDAR` only; `ACCESS_NETWORK_STATE`, `FOREGROUND_SERVICE`,
`RECEIVE_BOOT_COMPLETED` and `WAKE_LOCK` arrive through WorkManager's manifest
merge. `INTERNET` is absent, so the process cannot open a socket.

## Content rating questionnaire

Utility / productivity app, no user-generated content, no ads, no violence,
no sexual content, no profanity, no gambling, no data collection -> **Everyone**.

## Target audience

18 and over (no Designed for Families / kids program).

## Store settings notes

- Package: `com.artifact.chronograph`
- `minSdk 35` limits availability to **Android 15+**. This is deliberate
  (see `docs/specs/2026-08-03-android-port-design.md`) but sharply narrows reach;
  reconsider before promoting to production.
- Play App Signing is already enabled on this app. Publishing to an open track
  fixes the signing-key choice permanently.
- The upload keystore lives in 1Password; see `android/RELEASING.md`.
