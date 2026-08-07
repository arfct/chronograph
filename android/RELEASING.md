# Releasing to Google Play

## One-time setup (done)

- Upload keystore at `keystore/upload.jks` with `keystore/keystore.properties`
  (both gitignored — never commit the plaintext). With Play App Signing (enroll
  on first upload — say yes), Google holds the real app signing key and this is
  only the upload key, so a loss is recoverable via an upload-key reset request
  in Play Console (Setup → App signing) rather than fatal.

### Where the signing key lives

Three layers, so no single loss is fatal:

| Layer | What | Where |
|---|---|---|
| System of record | `upload.jks`, `keystore.properties`, and the age identity | 1Password, `geist@artifact.com` → Employee vault → **"Chronograph Play upload key"** (all three as attachments) |
| Encrypted in git | `android/keystore.tar.age` — age-encrypted tarball of `keystore/` | Committed to `arfct/chronograph`; every clone is a backup |
| Unlock key | age identity, also as a standalone document for scripting | 1Password → **"Chronograph age key"**; cached locally at `~/.config/age/chronograph.txt` |

**Fresh checkout — one command:**

```bash
cd android && ./scripts/unlock-keystore.sh
```

It uses `~/.config/age/chronograph.txt` if present, otherwise pulls the identity
from 1Password via `op document get` and caches it. Requires `brew install age`
(and `1password-cli` for the automatic path).

age public key (safe to share; encrypts to the identity above):
`age19mrr7nzh5v9rzcq3jf3mhp9hmhuu0nm7pas5gwx0nqmcwvjxes8sxn95vs`

To re-encrypt after rotating the keystore:

```bash
cd android && tar -czf - keystore | age -r <public-key-above> -o keystore.tar.age
```

For CI (GitHub Actions) later: put the age identity in a repo secret and run the
unlock script in the workflow — the encrypted archive is already in the checkout,
so no keystore binary needs to live in Actions secrets.
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
- [ ] Note: `minSdk 35` limits availability to Android 15+
      (docs/specs/2026-08-03-android-port-design.md — modern-only baseline).
