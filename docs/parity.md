# Feature parity

✅ shipped · ➖ not applicable / no plan · 🔜 planned (linked)

| Feature | iOS | macOS | watchOS | Android |
|---|---|---|---|---|
| Calendar widget | ✅ | ✅ | ✅ | 🔜 [phase 2](specs/2026-08-03-android-port-design.md) |
| Reminders widget | ✅ | ✅ | ✅ | ➖ [^reminders] |
| Time Zones widget | ✅ | ✅ | ✅ | ✅ (Glance + live TextClock) |
| Weather widget | ✅ | ➖ [^macweather] | ✅ | 🔜 [phase 3](specs/2026-08-03-android-port-design.md) |
| Weather via zip code | ✅ | ➖ | ✅ | 🔜 [phase 3](specs/2026-08-03-android-port-design.md) |
| StandBy Clock widget | ✅ | ➖ | ➖ | ➖ (no StandBy analogue) |
| Lock screen / accessory widgets | ✅ (`accessoryRectangular`) | ➖ | ✅ | 🔜 [^keyguard] |
| Extra-large page widget | 🔜 (iOS 27, declared) | ➖ | ➖ | ➖ |
| Obfuscation — Braille | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Obfuscation — Enigma (CMUdict IPA) | ✅ | ✅ | ✅ | ✅ (`:core`, fixture-verified) |
| Obfuscation — Ishihara font | ✅ | ✅ | ✅ | ➖ [^ishihara] |
| Per-widget configuration | ✅ (AppIntents sheet) | ✅ | ✅ | 🔜 (config activity, phase 2) |
| Widget gallery previews | ✅ (`recommendedIntents`) | ✅ | ✅ | ✅ (generated previews) |
| Dynamic system color | ➖ | ➖ | ➖ | ✅ (Material You via GlanceTheme) |

[^reminders]: Android has no system reminders store; the nearest equivalent (Google Tasks API) needs OAuth + Play verification — disproportionate for one widget type. See the design spec's key decisions.
[^macweather]: The Mac widget target is missing the WeatherKit entitlement (Linear A-155).
[^keyguard]: Declared (`widgetCategory="home_screen|keyguard"`, registers on API 37) but the phone emulator exposes no lock-screen widget surface yet — enabled wherever the OS offers the glanceable hub.
[^ishihara]: Glance cannot apply bundled custom fonts (phase-1 spike, 2026-08-03); the bitmap-row workaround isn't worth one novelty mode.
