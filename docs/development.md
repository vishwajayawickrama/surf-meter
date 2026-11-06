# Developing SurfMeter

SurfMeter 0.2 is a native macOS development build with Chrome activity accounting, a local aggregate store, and a SwiftUI menu bar dashboard. Safari integration and release certification remain unfinished. The web prototype is retained as the visual reference.

[Annotated setup guide](setup.md) · [Implementation tracker](implementation.md) · [Architecture](architecture.md) · [Current validation](validation.md) · [Browser protocol](browser-protocol.md)

## Build the native app

Prerequisites: macOS 14+, Swift 6 toolchain (Command Line Tools or Xcode), Node.js with npm, and Python 3 for verification scripts. The exercised environment is Apple Silicon/macOS 27.2 with Swift 6.4 CLT. Full Xcode is still absent and is required for Safari packaging. Intel and macOS 14 execution remain unverified.

From the repository root:

```sh
cd extensions/chrome
npm ci
npm test
cd ../..
./scripts/build-native.sh
./scripts/test-native.sh
open .build/SurfMeter.app
```

The build bundles the compiled Chrome extension, native helper, and Public Suffix List into the app and ad hoc signs it. The build has no external Swift dependencies. The scripts use temporary module caches and disable nested SwiftPM sandboxing. The Swift 6.4 CLT testing script also supplies the installed Testing macro plugin path. `ViewState` is a type alias for the existing SwiftUI property wrapper, avoiding macOS 27 SDK's new `State` macro dependency under CLT.

Click the waves icon in the menu bar. Recording is **off until setup is completed and explicitly enabled**. Daily, Yesterday, Weekly, website details, pause/resume, appearance, exclusions, retention, deletion, and browser setup use native views and actual aggregate data. The preview mode below is separate from recording.

## Connect Chrome

For the full walkthrough with numbered screenshot callouts, expected results, and troubleshooting, see [Set up SurfMeter](setup.md).

1. Open **Browser setup** via **gear → Connected browsers** in SurfMeter. Choose **Show Chrome extension folder**.
2. Open `chrome://extensions`, enable Developer mode, choose **Load unpacked**, and select that `ChromeExtension` folder. The repository's `extensions/chrome/dist` also works for iterative development.
3. Copy Chrome's 32-letter extension ID into SurfMeter and choose **Connect Chrome**. This installs the per-user native helper registration with that exact allowed origin. No wildcard origins or administrator access are used.
4. Open a normal web page in Chrome and click the SurfMeter extension button. Once connected, enable **Record eligible Chrome activity** in SurfMeter. This development path is intended for a single Chrome profile until multi-profile arbitration is validated.

Permission use: `tabs` reads the selected tab URL, `nativeMessaging` connects to the local helper, and `alarms` retries a suspended worker. The extension reduces URLs to hostnames before native messaging; no content scripts, history API, browser storage, or remote host permissions are used. Incognito access is disabled. Real private-window focus and permission-loss behavior remain release validation gates.

The GUI installer copies the helper into `~/Library/Application Support/SurfMeter/NativeHost`, creates adjacent `host-config.json`, and writes `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/dev.surfmeter.bridge.json`. On a new native-host session, the helper can reopen the configured app when a validated Chrome message arrives. Once that host has connected, later app loss returns a negative reply instead of immediately undoing Quit. Clicking the extension button creates a new host connection. App relaunch from real Chrome is not yet certified. Move SurfMeter to its final location before setup; reconnect after moving it.

An existing different native registration is left intact. To replace an old development registration, inspect/remove that SurfMeter-specific JSON file and reconnect. The optional CLI installer is still available:

```sh
python3 scripts/prepare-chrome-host.py --extension-id YOUR_32_CHARACTER_EXTENSION_ID
# Inspect the generated preview before registering it:
python3 scripts/prepare-chrome-host.py --extension-id YOUR_32_CHARACTER_EXTENSION_ID --install
```

The CLI path points to `.build/chrome-native-host` in this checkout. The GUI installer is the self-contained app path. Neither path enables recording automatically.

### Configure the installed app from Terminal

After loading the bundled extension in Chrome and approving its access, the installed app can perform its own setup without automating a menu bar popover:

```sh
/Applications/SurfMeter.app/Contents/MacOS/SurfMeter --configure-chrome YOUR_32_LETTER_EXTENSION_ID --enable-recording --enable-login
```

Use the actual extension ID. `--enable-recording` explicitly enables and unpauses local recording while preserving other preferences; omit it to leave recording settings unchanged. `--enable-login` uses `SMAppService.mainApp` and is opt-in; omit it to leave login settings unchanged. Exit status 3 means Chrome setup succeeded but login still needs approval or registration did not complete. The command reports the result; it does not bypass macOS approval. Missing/invalid IDs and unknown flags fail before changing configuration.

This command runs before the activity model and does not open another usage store or bridge server. It notifies an already-running app to reload preferences. The local registration and helper are identical to the GUI installer's output. It does not turn on Chrome Developer mode or load an extension for you; those steps still require Chrome's normal user-authorized flow.

## Data and tracking behavior

- The main app is the sole writer of Core Data/SQLite hourly platform aggregates under `~/Library/Application Support/SurfMeter/Data/activity.sqlite`. Daily and weekly totals are derived from them. No raw browsing-event history is stored.
- Settings persist through UserDefaults. Retention is 30 calendar days by default, with 7/30/90-day choices. A day is a fixed local date key; later time-zone changes do not rewrite old keys. Repeated daylight-saving clock hours share a bucket.
- Foreground Chrome, eligible fresh browser state, active system/session, input within 60 seconds, enabled collection, no pause, and no matching exclusion are required. The initial 60 idle seconds count. Unknown/stale states, long scheduling gaps, clock jumps, and reconnect gaps are not backfilled.
- Native foreground changes invalidate old snapshots. Browser heartbeats run once a second, with a two-second accounting freshness deadline. Thirty-second alarms help recover suspended extension workers. Measured CPU and recovery performance are still pending.
- Ten-second checkpoints, sleep/session notifications, and quit save the aggregate ledger. Save failures stop recording, retain unsaved totals in memory, and offer retry. Successful deletion clears the store before the UI updates and invalidates transient tracking state.
- Login items use `SMAppService` and are opt-in. The GUI reports registration/approval errors. Signed Applications-folder behavior needs manual validation.
- Screen sleep, session changes, and lock notifications close eligibility. The lock implementation also reads the supplemental `CGSSessionScreenIsLocked` dictionary key. This key and the distributed notification names are not a certified public lock API contract; lock/startup/unlock/session behavior must be tested before release.

## Verify and preview

```sh
./scripts/test-native.sh
python3 scripts/verify-native-bridge.py
python3 scripts/verify-recording.py
```

`verify-recording.py` runs about 35 seconds. It starts the real app and helper with **synthetic browser input in a temporary directory**, verifies native accounting and SQLite totals, rejects duplicate writers, and verifies crash/reopen/helper recovery without unavailable time or downtime backfill. It does not inspect your browser or alter normal preferences. `--simulate-chrome` is honored only with an explicit `--bridge-directory`; the app labels this mode Simulation.

For the accelerated ten-minute deterministic accounting/disk/reopen/retention/deletion check, run the built `SurfMeterVerification` executable at the bin directory reported by `swift build --show-bin-path`. This is a simulated timeline, not a real-browser accuracy certification.

Preview sample data without reading/writing the real database or opening the browser bridge:

```sh
open -n .build/SurfMeter.app --args --demo
.build/SurfMeter.app/Contents/MacOS/SurfMeter --verify-appearance
.build/SurfMeter.app/Contents/MacOS/SurfMeter --render-previews /private/tmp/surfmeter-native-previews
```

The exporter renders native AppKit-hosted SwiftUI views at 2× in both appearances. Panel widths are 780 pixels (390 points); heights vary by screen. Full setup/preferences captures use their content height. Sample data is labeled Preview. Transparency is disabled for reproducible layout captures; inspect the running app for live system glass and accessibility behavior.

Create a local development archive after a successful build:

```sh
./scripts/package-app.sh
```

This verifies the ad hoc signature and creates `.build/SurfMeter-0.2.0-development.zip`. It is not notarized or a production release. Signing, real-browser accuracy/privacy, supported OS versions, login items, lifecycle, resource limits, and clean installation remain open gates in [Validation](validation.md). Safari does not record anything in this build; see [its prerequisites](../extensions/safari/README.md).

## Remove the development integration

Remove the SurfMeter extension from Chrome and quit the Mac app. Remove only SurfMeter's native registration:

```sh
rm "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/dev.surfmeter.bridge.json"
```

Disable launch at login in SurfMeter or macOS Login Items if enabled. Use **Delete all activity** before uninstalling if you want to clear recorded totals. Removing the app alone does not delete its local data/settings.

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

## Repeatable functional and visual audit

```sh
./scripts/audit-native.sh
# Sample-only window for pointer/keyboard checks; never opens normal activity:
.build/SurfMeter.app/Contents/MacOS/SurfMeter --ui-audit
```

The audit script uses temporary databases and a unique temporary preferences suite, which is removed afterward. `--verify-model` checks app-level persistence and recovery; `--verify-appearance` now checks explicit and System modes against both simulated system appearances. `--render-audit-previews DIRECTORY` writes comparison edge cases and genuine isolated first-run screens. Normal browsing history is never seeded or cleared by these commands. See [QA audit](qa-audit.md) for completed evidence and remaining manual checks.

Only one service-enabled app may own an activity directory. The app acquires `activity.lock` (mode 0600) before opening Core Data; a duplicate exits with status 75. `bridge.lock` separately protects the socket endpoint. The OS releases both locks if the process exits or crashes; do not delete a lock file to bypass an active instance. The recording integration check now exercises duplicate rejection and crash/restart recovery in a temporary directory.
