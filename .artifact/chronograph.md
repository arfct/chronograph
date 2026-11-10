---
title: Chronograph
date: 2024-06
category: product
tags:
  - ios
  - android
  - widget
  - time
links:
  testflight: https://testflight.apple.com/join/qP1EtCvZ
  play: https://play.google.com/store/apps/details?id=com.artifact.chronograph
  source: https://github.com/arfct/chronograph
media:
  - src: calendar-tablet.png
    caption: The calendar widget on an Android tablet, with events listed under Friday and Saturday
    alt: A tablet home screen with a text agenda of events for Friday and Saturday in a pale rounded widget
  - src: widgets-phone.png
    caption: The time zones widget above the calendar widget on an Android phone
    alt: A phone home screen with a widget listing four cities and their local times above a widget listing events by day
  - src: ios-calendar.png
    caption: The calendar tab of the iOS app, with events and reminders for three days
    alt: A phone screen with a plain list of events and reminders under the day headings Monday 9, Tuesday 10 and Wednesday 11, with small times at the left and a row of five tab icons along the bottom
  - src: ios-calendar-dark.png
    caption: The same list in dark appearance
    alt: A phone screen in dark mode with white text listing events and reminders by day, Monday 9 to Wednesday 11, above a row of five tab icons
  - src: options.png
    caption: The options for one widget on Android, including text size, obfuscation and accent color
    alt: A settings sheet with a font size slider, Braille and Enigma obfuscation buttons, accent color swatches and calendar toggles
unconfirmed:
  - date
---

Chronograph is a set of text widgets for iOS, macOS, watchOS and Android. The widgets show calendar events, reminders, the time in other cities and the weather as lines of type under day headings. On iOS they also run on the lock screen, and a separate clock widget is made for StandBy.

Each widget has its own settings, including an accent color and a transparent background. Two obfuscation modes make the text hard to read at a glance. Braille replaces each letter with its braille cell. Enigma respells each word in phonetic symbols, using the CMU Pronouncing Dictionary.

The Apple version is in public TestFlight under the name Chronograph³¹ and has no App Store release. The Android version was added in 2026 and is on Google Play. It has the calendar and time zones widgets.

Swift and WidgetKit for the Apple platforms; Kotlin and Glance for Android. 2024.
