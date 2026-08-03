# Releasing to Google Play

## One-time setup (done)

- Upload keystore at `keystore/upload.jks` with `keystore/keystore.properties`
  (both gitignored). **Back both up outside the repo** — losing the upload key
  means a reset request through Play support. With Play App Signing (enroll on
  first upload — say yes), Google holds the real app signing key and this is
  only the upload key.
- Release builds are minified; `app/proguard-rules.pro` carries keep rules for
  WorkManager/Room reflection that Glance depends on. Any new "Can't load
  widget" in a release build: check `adb logcat` for reflective
  instantiation failures first.

## Every release

1. Bump `versionCode` (must increase every upload) and `versionName` in
   `app/build.gradle.kts`.
2. `sh scripts/sync-assets.sh` (cmudict + fonts into the APK).
3. `./gradlew :core:test :app:bundleRelease`
4. Smoke-test the minified build on an emulator or device:
   `./gradlew :app:assembleRelease && adb install -r app/build/outputs/apk/release/app-release.apk`
   — launch the app, pin both widgets, open the config sheet.
5. Upload `app/build/outputs/bundle/release/app-release.aab` to the Play
   Console (start with the **Internal testing** track).

## Play Console checklist (first submission)

- [ ] Developer account ($25 one-time), app created as
      `com.artifact.chronograph`.
- [ ] Enroll in Play App Signing when uploading the first AAB.
- [ ] Store listing: title, short + full description, 512×512 icon,
      1024×500 feature graphic, ≥2 phone screenshots.
- [ ] Privacy policy URL (required; READ_CALENDAR is user-data adjacent).
- [ ] Data safety form: no data collected, no data shared — calendar data is
      read on-device and rendered into the widget only; no network use today.
- [ ] Content rating questionnaire (utility, no user content → Everyone).
- [ ] Target audience: 18+ or 13+ (no kids design program).
- [ ] App category: Productivity or Tools.
- [ ] Note: `minSdk 36` intentionally limits availability to Android 16+
      (docs/specs/2026-08-03-android-port-design.md — modern-only baseline).
