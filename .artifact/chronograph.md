---
title: Chronograph
date: 2024-06
status: released
category: product
tags:
  - ios
  - macos
  - watchos
  - android
  - widget
  - time
url: https://chronograph.fyi
links:
  testflight: https://testflight.apple.com/join/qP1EtCvZ
  play: https://play.google.com/store/apps/details?id=com.artifact.chronograph
  source: https://github.com/arfct/chronograph
media:
  - src: calendar-tablet.png
    caption: The calendar widget on an Android tablet, its events set under Friday and Saturday
    alt: A tablet home screen with a text agenda of events for Friday and Saturday in a pale rounded widget
  - src: widgets-phone.png
    caption: Time zones above calendar on an Android phone, four cities and then the events by day
    alt: A phone home screen with a widget listing four cities and their local times above a widget listing events by day
  - src: ios-calendar.png
    caption: The calendar tab of the iOS app, three days of events and reminders with their times at the left
    alt: A phone screen with a plain list of events and reminders under the day headings Monday 9, Tuesday 10 and Wednesday 11, a fourth heading cut off below them, small times at the left and a row of five tab icons along the bottom
  - src: ios-calendar-dark.png
    caption: The same three days in dark appearance
    alt: A phone screen in dark mode with white text listing events and reminders by day, Monday 9 to Wednesday 11, above a row of five tab icons
  - src: options.png
    caption: One widget's options on Android, with a text size slider, Braille and Enigma buttons and accent swatches
    alt: A settings sheet with a font size slider, Braille and Enigma obfuscation buttons, accent color swatches and calendar toggles
unconfirmed: [date, status]
---

On a home screen, a Chronograph widget is a short column of type. Calendar events, reminders, the time in other cities and the weather are set as lines under day headings. There are versions for iOS, macOS, watchOS and Android; on iOS the widgets run on the lock screen as well, and a separate clock is made for StandBy.

Each widget keeps its own settings, among them an accent color, a transparent background and a choice of ways to make its text hard to read at a glance. Braille replaces every letter with its braille cell. Enigma looks each word up in the CMU Pronouncing Dictionary and prints the pronunciation in phonetic symbols, leaving acronyms as they were and cutting a web address down to its host. Ishihara alters no text and changes only the typeface, to one whose glyphs are braille cells with the dots joined into strokes; because Android's Glance widgets cannot use a bundled font, that third mode is found on the Apple platforms alone.

The Apple version is in public TestFlight under the name Chronograph³¹ and has no App Store release. Android followed in 2026 and is on Google Play with two of the widgets, calendar and time zones.

Swift and WidgetKit for the Apple platforms; Kotlin and Glance for Android. 2024.
