# Developing SurfMeter

A macOS menu bar app in development that tracks active browser time by website or platform and compares today's usage with yesterday's.

## Project status

Native foundation plus the approved interactive UI prototype. The Swift menu bar app and Chrome bridge are implemented for development; time accounting, storage, and the complete native UI are not implemented yet.

See the [Software Requirements Specification](SRS.md) for the proposed MVP, tracking rules, privacy requirements, and acceptance criteria.

## Native implementation direction

The proposed production stack is **Swift + SwiftUI**, `MenuBarExtra`, native Liquid Glass materials, **TypeScript browser extensions**, browser native messaging, and **local SwiftData persistence**. Xcode and Swift Package Manager will support the native app and helper targets. The MVP does not require a backend or account.

See [Technology stack and architecture](ARCHITECTURE.md) for the component flow, browser-specific adapters, tracking engine, storage boundaries, and integration decisions still to validate. The native foundation uses Swift Package Manager; full Xcode is required for Safari extension packaging. See the verified and pending checks in [Foundation validation](FOUNDATION-VALIDATION.md).

Follow the [five-task implementation tracker](IMPLEMENTATION.md) for delivery order, completion criteria, current progress, and handoff notes between sessions. Task 1 is in progress. See [Browser protocol](BROWSER-PROTOCOL.md) for the implemented bridge contract.

## Native foundation

Prerequisites: macOS 14 or later, Swift 6 toolchain (`xcode-select --install` for Command Line Tools), Python 3, and Node.js with npm for the Chrome extension. Only Apple Silicon/macOS 27.2 has been exercised so far. No Apple Developer account is required for the local ad hoc build; distribution and Safari need additional signing/setup.

From the repository root:

```sh
./scripts/build-native.sh
./scripts/test-native.sh
python3 scripts/verify-native-bridge.py
open .build/SurfMeter.app
```

Click the waves icon in the menu bar. This is a small connection diagnostic shell; the Daily/Weekly design remains in the prototype until Task 4. It shows hostname snapshots and native signals, with no usage timer or database. The integration test launches a separate app with a temporary bridge directory and exits it after synthetic checks.

The build script creates a local `.app` bundle and ad hoc signs it. Build products, helper registration previews, dependencies, and caches are excluded from Git. It disables SwiftPM's nested build sandbox to work in the coding sandbox; the package has no external Swift dependencies. A second instance using the same socket directory reports an unavailable bridge; quit the older instance first.

### Chrome development setup

```sh
cd extensions/chrome
npm ci
npm test
cd ../..
```

1. Open `chrome://extensions`, enable Developer mode, choose **Load unpacked**, and select `extensions/chrome/dist` from this checkout. Chrome's permission prompt is expected: tabs allows reading the active tab URL; nativeMessaging connects to the local helper; alarms retries a suspended worker. No content script, history API, remote host permission, or browser storage is used.
2. Copy the extension's actual ID from Chrome. Generate and inspect the host registration, then install that exact registration:

```sh
python3 scripts/prepare-chrome-host.py --extension-id YOUR_32_CHARACTER_EXTENSION_ID
python3 scripts/prepare-chrome-host.py --extension-id YOUR_32_CHARACTER_EXTENSION_ID --install
open .build/SurfMeter.app
```

3. Click the extension toolbar action to reconnect, then focus a normal HTTP/HTTPS tab and inspect SurfMeter's Chrome row. The helper is named `dev.surfmeter.bridge`. Its registration allows only the specified extension origin and points to the helper copy in this checkout's `.build/chrome-native-host` directory. Keep the checkout in place while using it. Rebuild and rerun preparation/installation after helper changes or moving the checkout.
4. Use [Foundation validation](FOUNDATION-VALIDATION.md) to record real-browser results. Chrome incognito access is disabled by the manifest, and private/unsupported snapshots contain no hostname. Verify actual private-window focus behavior before accepting the integration.

The installer refuses to replace a different existing registration. It writes only the per-user Chrome host file when `--install` is supplied; running without that option prepares a preview inside `.build`. The helper does not launch SurfMeter automatically. A missing app produces a negative acknowledgement; clicking the toolbar action reconnects. Automatic recovery and launch behavior remain Task 1 validation items.

To remove the development integration: remove SurfMeter from `chrome://extensions`, quit SurfMeter, and remove the generated registration:

```sh
rm "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/dev.surfmeter.bridge.json"
```

This removal command is for the SurfMeter development registration only. The socket/lock live in `~/Library/Application Support/SurfMeter`; no activity is stored there by this foundation. Safari is **not installed or supported yet**; see [Safari adapter prerequisites](../extensions/safari/README.md).

## UI prototype

Run from the repository root:

```sh
python3 -m http.server 5173 --bind 127.0.0.1 --directory prototype
```

Open [the prototype](http://127.0.0.1:5173) in your browser. No dependencies or build step are needed.

The prototype includes a menu bar dashboard with **Daily** and **Weekly** tabs. Daily opens on today and has a dedicated **Yesterday** toggle; click it again to return to today. Weekly shows the last seven calendar days (including today so far), a daily chart, daily averages, and per-platform totals. Website details follow the selected day or week. Preferences, browser setup, pause/resume, exclusions, and an empty state are also included. Appearance and preview settings persist in browser local storage. Use **Reset demo** to restore the sample data.

All usage data and browser connections are simulated. Login and retention controls update preview preferences only; they do not change macOS settings or collect activity. The desktop frame and left navigation are preview controls, not part of the planned native menu bar app.

### Visual direction

The prototype follows an Apple Liquid Glass direction: a translucent floating popover, illuminated edges, capsule controls, and separate content/control layers in light and dark appearances. Adjust the material tokens in `prototype/liquid-glass.css` to tune opacity, blur, highlights, and corner radius. Reduced transparency, increased contrast, and reduced motion preferences have CSS fallbacks.

This is a browser approximation of the material for UI review. The native macOS implementation should adopt Apple's system Liquid Glass APIs where supported, with an appropriate fallback on older macOS versions. See [Apple's materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials).
