#!/usr/bin/env bash
# quran 1.3.1 imports three translation files with different letter case
# than the files it ships (en_clearQuran.dart vs en_clearquran.dart, ...).
# macOS ignores case, so local builds work; Linux (CI, Vercel) does not.
# Run after `flutter pub get` to add the missing names as symlinks.
set -euo pipefail

root=$(python3 -c "import json; print(next(p['rootUri'] for p in json.load(open('.dart_tool/package_config.json'))['packages'] if p['name'] == 'quran').removeprefix('file://'))")
cd "$root/lib/translations"
ln -sf en_clearquran.dart en_clearQuran.dart
ln -sf fr_hamidullah.dart fr_Hamidullah.dart
ln -sf fa_husseindari.dart fa_husseinDari.dart
