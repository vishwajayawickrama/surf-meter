#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/surfmeter-clang-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/private/tmp/surfmeter-swift-cache}"
EXTRA=()
# Swift 6.4's CLT swiftbuild discovers Testing.framework but omits its macro library.
DEVELOPER_DIR_PATH="$(xcode-select -p)"
MACRO="$DEVELOPER_DIR_PATH/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ "$DEVELOPER_DIR_PATH" == */CommandLineTools && -f "$MACRO" ]]; then
  EXTRA=(-Xswiftc -load-plugin-library -Xswiftc "$MACRO")
fi
swift test --disable-sandbox --disable-xctest --cache-path /private/tmp/surfmeter-spm-cache "${EXTRA[@]}"
