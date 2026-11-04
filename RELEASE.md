# Releasing Samt to the App Store

Everything that could be done from the repo is done. What is left is the part
that needs your Apple account, your domain, and your judgement.

Current state: `flutter build ios --release` succeeds, 26.9 MB, 67 tests
green, `flutter analyze` clean (info-level lints only).

---

## 1. Blocking — the bundle identifier

The app is still `com.example.adhkarApp`. **App Store Connect refuses to
register any App ID under `com.example`**, so the first upload will fail until
this changes. It is one command:

```bash
./tool/set_bundle_id.sh com.yourdomain.samt
```

Pick a reverse-domain you control (`com.<your-domain>.samt`). It is permanent
once a build is published, so choose it before the first upload, not after.
The script refuses `com.example.*` and anything malformed, and updates both
the iOS project and the Android one.

## 2. Apple Developer account

$99/year, at <https://developer.apple.com/programs>. Enrolment as an
individual is instant-ish; as a company it needs a D-U-N-S number and can take
a week or two. Then:

- App Store Connect → **My Apps → +** → New App
- Platform iOS, name `سمت` (or `Samt` if Arabic is taken), primary language
  Arabic, the bundle ID from step 1, and an SKU of your choosing.

## 3. Signing

Open the workspace (not the project):

```bash
open ios/Runner.xcworkspace
```

Runner target → **Signing & Capabilities** → tick *Automatically manage
signing* and pick your Team. Xcode creates the App ID and provisioning
profile. Also add the **Push Notifications** capability only if you later add
remote push — the current prayer reminders are local and need nothing.

## 4. Build and upload

```bash
flutter build ipa
```

Then either `open build/ios/archive/Runner.xcarchive` and use Xcode's
Organizer → Distribute App, or:

```bash
xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios \
  -u you@example.com -p <app-specific-password>
```

An app-specific password comes from <https://appleid.apple.com> → Sign-In and
Security → App-Specific Passwords.

## 5. Store listing

Everything is written and ready to paste:

- **`store/listing.md`** — name, subtitle, description, keywords and
  promotional text in Arabic and English, plus the App Review answers and the
  review note explaining the optional location permission.
- **`store/screenshots/ios-6.9/`** — six screenshots at 1320×2868, which is
  the 6.9" size Apple requires. Upload them under the 6.9" slot; App Store
  Connect scales them down for the smaller sizes automatically.
  - `01-home` · `02-prayer-times` · `03-adhkar` · `04-more`
  - `05-categories` · `06-mushaf`
  - Not included: the qibla screen. The simulator has no compass so it renders
    a "no compass on this device" notice. Take that one on a real iPhone if
    you want it in the set.

## 6. Privacy — two things Apple will ask for

1. **A privacy policy URL is mandatory.** `store/PRIVACY.md` is written, in
   Arabic and English, and accurately describes what the app does (location
   on-device only, two optional network calls, nothing collected). Host it
   anywhere public — a GitHub Pages page or a Notion page is fine — and paste
   the URL into App Store Connect.
2. **The App Privacy questionnaire: answer "No data collected."** Location
   used on-device and never transmitted is not "collection" under Apple's
   definitions. Do not tick Location unless a future feature sends it.

`ios/Runner/PrivacyInfo.xcprivacy` is already written and bundled into the
build — it declares no tracking, no collected data, and the required-reason
APIs the app touches.

---

## Already done

| | |
|---|---|
| Version | `1.0.0+1` in `pubspec.yaml` |
| Display name | `Samt` (`CFBundleDisplayName`), `سمت` on Android |
| App icons | 15 iOS sizes + Android adaptive icons, from `tool/make_icon.py` |
| Launch screen | Night-sky `#0B1026`, no stray Flutter default |
| Location permission string | `NSLocationWhenInUseUsageDescription`, in Arabic |
| Export compliance | `ITSAppUsesNonExemptEncryption` = false |
| Privacy manifest | `PrivacyInfo.xcprivacy`, wired into the Runner target |
| Release build | Verified: 26.9 MB, builds clean |

## Known gaps, deliberately

- **The assistant is hidden**, not removed — `kAssistantEnabled = false` in
  `lib/config.dart`. Its code, tests and 2.6 MB corpus still ship in the
  bundle. If you want the binary smaller before release, also drop
  `assets/corpus/` from `pubspec.yaml`; if you plan to switch it on soon,
  leave it.
- **Android is configured but unverified.** Signing, minification, desugaring,
  permissions and the adaptive icon are all wired, but no Android SDK is
  installed on this machine so `flutter build appbundle` has never run. It
  will also need a keystore — see `android/key.properties.example`.
- **The religious content is sourced, not certified.** Every dhikr, tafsir and
  hadith traces to the source named in the More screen, and nothing was
  composed by the app. Whether the wording, the repetition counts and the
  gradings are *sound* is a scholarly judgement — have someone qualified read
  through before you publish under your own name.
