#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/.build/SurfMeter.app"
if [[ ! -f "$APP/Contents/Resources/ChromeExtension/manifest.json" ]]; then
  echo "Build the Chrome extension, then run ./scripts/build-native.sh before packaging." >&2
  exit 1
fi
codesign --verify --deep --strict "$APP"
ARCHIVE="$PWD/.build/SurfMeter-0.2.0-development.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
printf 'Development archive: %s\nAd hoc signed; not notarized or a public release.\n' "$ARCHIVE"
