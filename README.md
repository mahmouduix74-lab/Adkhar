# سمت · Samt

تطبيق Flutter للمواقيت والأذكار والمصحف — يعمل بالكامل بدون إنترنت.

A Flutter app for prayer times, adhkar and the mushaf. Everything it needs
ships in the bundle; it is fully usable offline.

## What's in it

- **مواقيت الصلاة** — computed on-device with [`adhan`](https://pub.dev/packages/adhan)
  from the user's coordinates (Egyptian General Authority of Survey method),
  with local notifications that fire with no network.
- **اتجاه القبلة** — great-circle bearing to the Kaaba, with a live compass
  over a native platform channel (`adhkar_app/compass`): CoreLocation on iOS,
  the rotation-vector sensor on Android.
- **الأذكار** — nine categories from حصن المسلم, each dhikr with its wording,
  its repetition count and the book's own English translation.
- **المصحف** — 114 surahs in the Uthmani script, one page per screen with no
  scrolling, a bookmark, and press-and-drag on a verse to read its tafsir.
- **التفسير الميسّر** — complete, bundled as an asset, offline.
- Ten interface languages, light/dark, and no accounts, ads or analytics.

## Sources

Every piece of religious content is reproduced from a named source; none of
it is composed by the app.

| | |
|---|---|
| Mushaf text | [`quran`](https://pub.dev/packages/quran) package — Uthmani |
| Juz / hizb / page boundaries | Tanzil.net |
| Adhkar and repetition counts | hisnmuslim.com (official site of حصن المسلم) |
| Tafsir al-Muyassar | alquran.cloud / King Saud University |
| Forty Nawawi | hadith-api (CC0) — متن only |
| Translation of meanings | Quran Foundation (quran.com) |
| Recitation | Mishary Alafasy via islamic.network |

> The content is **sourced, not certified**. Whether a wording, a repetition
> count or a hadith grading is sound is a scholarly judgement — have someone
> qualified review it before publishing.

## Generated data

Three files are generated and must never be hand-edited. Each names its
source in its own header; regenerate rather than patch:

```bash
python3 tool/generate_adhkar.py    # lib/data/adhkar_generated.dart
python3 tool/generate_corpus.py    # assets/corpus/*.json + lib/data/islamic_corpus.dart
python3 tool/make_icon.py          # iOS + Android launcher icons
```

## Building

```bash
flutter pub get
flutter run                 # debug, on a connected device or simulator
flutter test                # 67 tests
flutter analyze
flutter build ios --release
```

Before the first store upload the bundle identifier has to change from
`com.example.adhkarApp` to one you own — Apple refuses `com.example`:

```bash
./tool/set_bundle_id.sh com.yourdomain.samt
```

See [`RELEASE.md`](RELEASE.md) for the full App Store checklist, and
[`store/`](store/) for the listing copy, the privacy policy and the 6.9"
screenshots.

## Layout

```
lib/
  data/        sources, repositories, the offline corpus and the assistant
  screens/     one file per screen
  widgets/     shared pieces — footer nav, sky header, counters
  l10n/        ten languages in one table
  config.dart  feature flags
tool/          generators and release scripts
store/         App Store listing, privacy policy, screenshots
```

The offline assistant is built and tested but switched off for this release
via `kAssistantEnabled` in `lib/config.dart`.
