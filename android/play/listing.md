# Play Store listing — Chronograph

Paste-ready copy for the Play Console. Assets in this directory:

| Asset | File | Play requirement |
|---|---|---|
| App icon | `icon-512.png` | 512×512 PNG ✅ |
| Feature graphic | `feature-graphic-1024x500.png` | 1024×500 PNG ✅ |
| Phone screenshots | `screenshots/1-widgets.png`, `2-options.png`, `3-timezones.png` | ≥2, 1080×2400 ✅ |

The feature graphic is generated — edit `feature-graphic.html` and re-render:

```bash
cd android/play
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --allow-file-access-from-files \
  --force-device-scale-factor=1 --hide-scrollbars --window-size=1024,500 \
  --screenshot="feature-graphic-1024x500.png" "file://$PWD/feature-graphic.html"
```

`wordmark.png` is the shipped `Wordmark.pdf` rasterised at 2400px — regenerate with
`qlmanage -t -s 2400 -o . ../../apple/iOS/Assets.xcassets/Wordmark.imageset/Wordmark.pdf`.

---

## App name (30 max)

```
Chronograph
```

## Short description (80 max)

```
Your calendar, reminders and time zones as clean text on your home screen.
```
*(74 characters)*

## Full description (4000 max)

```
Chronograph turns your day into plain text.

No grids, no coloured blocks, no chrome — just your next events set as clean,
readable type on your home screen. Glanceable in the half second you actually
spend looking at a widget.

WIDGETS
• Calendar — upcoming events as a compact text agenda, grouped by day
• Time Zones — current time in the cities you care about, with a sunrise-to-night
  glyph so you can tell at a glance who is awake

MADE TO BE TUNED
• Five text sizes
• Transparent background that reads against your wallpaper
• Accent colours
• Optional time bars, all-day events, multi-day events and free-time gaps
• Obfuscation modes — render your agenda in Braille or Enigma script when you
  want it on screen but not legible over your shoulder

PRIVATE BY CONSTRUCTION
Chronograph reads your calendar on your device and draws it. That is all it does.
The Android app requests no network permission at all, so it cannot send anything
anywhere. No accounts, no analytics, no ads, no tracking.

Requires Android 15 or later.
```

## Categorisation

| Field | Value |
|---|---|
| App category | Productivity |
| Tags | Calendar, Widgets, Productivity |
| Contact email | *(Play requires a public contact email — use a role alias, not a personal address)* |
| Privacy policy | `https://chronograph.page/privacy` |

## Data safety form

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all user data encrypted in transit? | N/A — no data leaves the device |
| Do you provide a way for users to request data deletion? | N/A — no data collected |

Rationale if asked: calendar data is read from the on-device provider at widget
refresh, rendered into the widget, and never transmitted. The app holds no
`INTERNET` permission.

## Content rating questionnaire

Utility / productivity app, no user-generated content, no ads, no violence,
no sexual content, no profanity, no gambling, no data collection → **Everyone**.

## Target audience

18 and over (no Designed for Families / kids program).

## Store settings notes

- Package: `com.artifact.chronograph`
- `minSdk 35` → availability limited to **Android 15+**. This is deliberate
  (see `docs/specs/2026-08-03-android-port-design.md`) but sharply narrows reach;
  reconsider before promoting to production.
- Enrol in **Play App Signing** on first upload.
- Start on the **Internal testing** track, not production.
