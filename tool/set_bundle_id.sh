#!/usr/bin/env bash
# Swap the app's bundle identifier everywhere it is written down.
#
# Apple will not register an App ID under `com.example`, so this has to be run
# once with your own reverse-domain before the first upload. It is safe to run
# again if you change your mind later — but only before the app is published;
# once a build is on App Store Connect the identifier is permanent.
#
#   ./tool/set_bundle_id.sh com.yourdomain.samt
#
set -euo pipefail

NEW="${1:-}"
if [[ -z "$NEW" ]]; then
  echo "usage: $0 <bundle-id>    e.g. $0 com.yourdomain.samt" >&2
  exit 1
fi
if [[ ! "$NEW" =~ ^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z][A-Za-z0-9-]*)+$ ]]; then
  echo "error: '$NEW' is not a valid reverse-domain identifier." >&2
  echo "       Letters, digits and hyphens per segment, at least one dot." >&2
  exit 1
fi
if [[ "$NEW" == com.example.* ]]; then
  echo "error: Apple rejects App IDs under com.example — pick your own domain." >&2
  exit 1
fi

cd "$(dirname "$0")/.."

# iOS: the app target and its test target (which must stay a child of it).
PBX=ios/Runner.xcodeproj/project.pbxproj
python3 - "$NEW" "$PBX" <<'PY'
import io, re, sys
new, path = sys.argv[1], sys.argv[2]
s = io.open(path, encoding='utf-8').read()
s = re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = [^;]*\.RunnerTests;',
           f'PRODUCT_BUNDLE_IDENTIFIER = {new}.RunnerTests;', s)
s = re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = (?!' + re.escape(new) + r')[^;]+;',
           f'PRODUCT_BUNDLE_IDENTIFIER = {new};', s)
io.open(path, 'w', encoding='utf-8').write(s)
PY

# Android: applicationId and namespace. The Kotlin package under
# android/app/src/main/kotlin is left alone — it is internal and renaming it
# would break MainActivity's compass channel for no gain.
ANDROID_ID="${NEW//-/_}"
python3 - "$ANDROID_ID" <<'PY'
import io, re, sys
new = sys.argv[1]
p = 'android/app/build.gradle'
s = io.open(p, encoding='utf-8').read()
s = re.sub(r'applicationId = "[^"]*"', f'applicationId = "{new}"', s)
s = re.sub(r'namespace = "[^"]*"', f'namespace = "{new}"', s)
io.open(p, 'w', encoding='utf-8').write(s)
PY

echo "Bundle identifier set to: $NEW"
echo
grep -h 'PRODUCT_BUNDLE_IDENTIFIER' "$PBX" | sed 's/^[[:space:]]*/  ios: /' | sort -u
grep -hE 'applicationId|namespace' android/app/build.gradle | sed 's/^[[:space:]]*/  android: /'
echo
echo "Next: open ios/Runner.xcworkspace in Xcode, pick your team under"
echo "Signing & Capabilities, then run: flutter build ipa"
