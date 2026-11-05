#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/surfmeter-clang-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/private/tmp/surfmeter-swift-cache}"
swift build --disable-sandbox --cache-path /private/tmp/surfmeter-spm-cache -Xswiftc -module-cache-path -Xswiftc /private/tmp/surfmeter-swift-cache
BIN="$(swift build --disable-sandbox --show-bin-path)"
APP="$PWD/.build/SurfMeter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers"
cp "$BIN/SurfMeterApp" "$APP/Contents/MacOS/SurfMeter"
cp "$BIN/SurfMeterNativeHost" "$APP/Contents/Helpers/SurfMeterNativeHost"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.surfmeter.app</string>
<key>CFBundleName</key><string>SurfMeter</string>
<key>CFBundleExecutable</key><string>SurfMeter</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP/Contents/Helpers/SurfMeterNativeHost"
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
