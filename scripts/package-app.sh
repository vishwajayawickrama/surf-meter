#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/.build/SurfMeter.app"
VERSION="$(cat version.txt)"
ARCH="$(lipo -archs "$APP/Contents/MacOS/SurfMeter")"
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "Unsupported package architecture: $ARCH" >&2; exit 1
fi
if [[ ! -f "$APP/Contents/Resources/ChromeExtension/manifest.json" ]]; then
  echo "Build the Chrome extension, then run ./scripts/build-native.sh before packaging." >&2; exit 1
fi
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print SurfMeterReleaseVersion' "$APP/Contents/Info.plist")
[[ "$BUNDLE_VERSION" == "$VERSION" ]] || { echo 'Rebuild the app to match version.txt.' >&2; exit 1; }
codesign --verify --deep --strict "$APP"
STAGE="$(mktemp -d "$PWD/.build/dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/SurfMeter.app"
ln -s /Applications "$STAGE/Applications"
cp docs/download-installation.html "$STAGE/Start Here.html"
cp third-party-notices.md "$STAGE/third-party-notices.md"
mkdir "$STAGE/setup-images"
cp docs/media/desktop/onboarding-{1,2,3,4}-light-2x.png "$STAGE/setup-images/"
DMG="$PWD/.build/SurfMeter-$VERSION-$ARCH.dmg"
hdiutil create -quiet -ov -volname SurfMeter -srcfolder "$STAGE" -format UDZO "$DMG"
hdiutil verify "$DMG"
(cd .build && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
# Keep the existing development archive workflow available too.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$PWD/.build/SurfMeter-$VERSION.zip"
printf 'DMG: %s\nAd hoc signed development build; not notarized.\n' "$DMG"
