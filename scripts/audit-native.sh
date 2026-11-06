#!/bin/bash
# Repeatable local development audit. Browser/OS interaction gates remain manual.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check-repo.py
(cd extensions/chrome && npm test)
./scripts/build-native.sh
./scripts/test-native.sh
python3 scripts/verify-native-bridge.py
python3 scripts/verify-recording.py
APP="$PWD/.build/SurfMeter.app/Contents/MacOS/SurfMeter"
"$APP" --verify-model
"$APP" --verify-appearance
BIN="$(swift build --disable-sandbox --show-bin-path)"
"$BIN/SurfMeterVerification"
./scripts/package-app.sh
RENDERS="$(mktemp -d "${TMPDIR:-/private/tmp}/surfmeter-audit-renders.XXXXXX")"
"$APP" --render-previews "$RENDERS/standard"
"$APP" --render-audit-previews "$RENDERS/edge-cases"
printf 'Inspect the rendered screens in %s\n' "$RENDERS"
printf 'Manual interaction and release gates: docs/qa-audit.md\n'
