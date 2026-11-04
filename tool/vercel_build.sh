#!/usr/bin/env bash
# Build command for Vercel, which has no Flutter preinstalled.
# Installs the Flutter SDK, then builds the web version into build/web.
set -euo pipefail

FLUTTER_VERSION=3.47.9
FLUTTER_HOME="$HOME/flutter"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"

flutter config --no-analytics
flutter pub get
bash tool/fix_quran_case.sh
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
find build/web -name '*.symbols' -delete
