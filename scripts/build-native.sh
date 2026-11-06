#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/surfmeter-clang-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/private/tmp/surfmeter-swift-cache}"
CONFIGURATION="${SURFMETER_BUILD_CONFIGURATION:-debug}"
VERSION="$(cat version.txt)"
BUNDLE_VERSION="${VERSION%%-*}"
swift build --configuration "$CONFIGURATION" --disable-sandbox --cache-path /private/tmp/surfmeter-spm-cache -Xswiftc -module-cache-path -Xswiftc /private/tmp/surfmeter-swift-cache
BIN="$(swift build --configuration "$CONFIGURATION" --disable-sandbox --show-bin-path)"
APP="$PWD/.build/SurfMeter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
rm -rf "$APP/Contents/Resources/SurfMeter_SurfMeterCore.bundle"
cp -R "$BIN/SurfMeter_SurfMeterCore.bundle" "$APP/Contents/Resources/"
if [[ -f extensions/chrome/dist/manifest.json ]]; then
  rm -rf "$APP/Contents/Resources/ChromeExtension"
  cp -R extensions/chrome/dist "$APP/Contents/Resources/ChromeExtension"
else
  echo "Chrome extension not built. Run npm ci && npm run build in extensions/chrome, then rebuild the app." >&2
fi
ICONSET="$PWD/.build/app-icon.iconset"
mkdir -p "$ICONSET"
swift -module-cache-path /private/tmp/surfmeter-swift-cache scripts/render-app-icon.swift "$PWD/.build/app-icon.png"
for POINTS in 16 32 128 256 512; do
  sips -z "$POINTS" "$POINTS" .build/app-icon.png --out "$ICONSET/icon_${POINTS}x${POINTS}.png" >/dev/null
  PIXELS=$((POINTS * 2))
  sips -z "$PIXELS" "$PIXELS" .build/app-icon.png --out "$ICONSET/icon_${POINTS}x${POINTS}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$BIN/SurfMeterApp" "$APP/Contents/MacOS/SurfMeter"
cp "$BIN/SurfMeterNativeHost" "$APP/Contents/Helpers/SurfMeterNativeHost"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.surfmeter.app</string>
<key>CFBundleName</key><string>SurfMeter</string>
<key>CFBundleExecutable</key><string>SurfMeter</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$BUNDLE_VERSION</string>
<key>SurfMeterReleaseVersion</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>4</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP/Contents/Helpers/SurfMeterNativeHost"
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
