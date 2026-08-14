# Releasing to Google Play

## One-time setup (done)

- Upload keystore at `keystore/upload.jks` with `keystore/keystore.properties`
  (both gitignored — never commit the plaintext). With Play App Signing (enroll
  on first upload — say yes), Google holds the real app signing key and this is
  only the upload key, so a loss is recoverable via an upload-key reset request
  in Play Console (Setup → App signing) rather than fatal.

### Where the signing key lives

**1Password** — `geist@artifact.com` → Employee vault → **"Chronograph Play upload
key"**. Both files are attachments on that item.

On a new machine, download the two attachments into `android/keystore/`:

| Attachment | Save as |
|---|---|
| `upload_keystore` | `android/keystore/upload.jks` |
| `keystore_properties` | `android/keystore/keystore.properties` |

That's the whole procedure. The item's notes carry the `upload.jks` SHA-256 if you
want to verify the copy, and the reset procedure if it's ever lost.

When CI publishing arrives, load these from 1Password in the workflow (via
`1password/load-secrets-action`) or as base64 repo secrets — no need to keep a
keystore copy in the repo.
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

## Store screenshots

Captured from a **release** build, never a debug one, so what ships is what the
listing shows. The `play-store-assets` skill owns the geometry table and the spec
check; this is just the order of operations.

```bash
adb install app/build/outputs/apk/release/app-release.apk   # uninstall first if
                                                            # a debug build is on
adb shell pm grant com.artifact.chronograph android.permission.READ_CALENDAR
scripts/seed-calendar.sh                                    # a realistic day
```

Then, for each of `phone`, `tablet7`, `tablet10`:

```bash
python3 ~/.claude/skills/play-store-assets/scripts/capture.py set --form tablet10
# re-pin both widgets: changing wm size/density makes the launcher re-lay-out and
# it drops widgets that no longer fit. Then find the page they landed on — HOME
# returns to the default page, which is usually not that one.
python3 ~/.claude/skills/play-store-assets/scripts/capture.py shot \
  --out play --name tablet10-1-widgets
python3 ~/.claude/skills/play-store-assets/scripts/capture.py reset
```

Finally:

```bash
python3 ~/.claude/skills/play-store-assets/scripts/validate.py play
```

Things that have bitten us, all of which show up in the capture:

- `screencap` emits RGBA and Play rejects an alpha channel. `capture.py shot`
  flattens it; a hand-rolled `adb exec-out screencap` does not.
- Other apps' foreground services put a chip in the status bar. `com.artifact.shareware`
  leaves a red "Sharing your screen" timer there; force-stop it first.
- A "Item removed" snackbar lingers for several seconds after deleting a widget.
- **Look at every capture before trusting it.** Two of these were of the wrong
  home-screen page and one was of a stale build.

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
- [ ] Note: `minSdk 35` limits availability to Android 15+
      (docs/specs/2026-08-03-android-port-design.md — modern-only baseline).
