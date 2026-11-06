# Functional and visual audit — 2026-11-06

The automated development audit passes, and **41 assertions passed through the actual sample-data UI** in the isolated test workflow. The installed menu-panel check and real-browser/release matrix remain separate gates. This document does not certify every browser scenario or accessibility configuration.

Environment: Apple Silicon, macOS 27.2, Swift 6.4 Command Line Tools, Node 24.22.2. The baseline was commit `5b626d3`; this audit adds the fixes and repeatable checks below. Full Xcode and Safari packaging remain unavailable.

## Findings fixed

| Finding | Correction | Regression evidence |
| --- | --- | --- |
| A second instance could lose the socket race but still checkpoint stale store contents. | Acquire an exclusive, private writer lease before Core Data opens; reject duplicate instances with exit status 75. | New integration assertion reproduced the old bug (duplicate stayed running until the three-second timeout), then passed after the fix. Disposable crash/restart validation also checks lease release. |
| Shortening retention while idle pruned memory without marking the store dirty. | Pruning expired buckets or coverage now schedules a durable save immediately. | Model audit seeds 16 days, clears the dirty flag, changes 30 to 7 days, then opens a separate store and checks expired rows and coverage are gone. |
| Missing yesterday data could produce a comparison against assumed zero. | Comparisons require recorded coverage or existing totals. Setup/partial-only coverage does not establish a zero baseline. | Missing-yesterday fixture has partial-only coverage; its render shows today's time and the missing-data note without a delta. Known zero remains a separate fixture. |
| Bridge failure displayed a storage retry action. | The bridge banner now retries the connection; storage retains its separate retry action. | Wiring reviewed; normal bridge framing/reconnect/app-loss integration passes. Clicking retry after a real bridge failure remains pending. |
| Website details used a large total instead of the paired prototype statistics. | Restored domain identity, paired daily/weekly statistics, context labels, and exclusion explanation. | Actual Daily/Yesterday/Weekly detail interaction and Back-state checks pass. |
| Hourly accessibility labels repeated the chart title for each bar. | Contain the chart as a group and expose each hour with its own duration. Hide the decorative retention chevron from accessibility. | Native accessibility tree shows 24 distinct hour/duration entries. |
| Equal time read “Same than yesterday.” | Website details used a large total instead of the paired prototype statistics. | Restored domain identity, paired daily/weekly statistics, context labels, and exclusion explanation. | Actual Daily/Yesterday/Weekly detail interaction and Back-state checks pass. |
| Hourly accessibility labels repeated the chart title for each bar. | Contain the chart as a group and expose each hour with its own duration. Hide the decorative retention chevron from accessibility. | Native accessibility tree shows 24 distinct hour/duration entries. |
| Equal time reads “Same as yesterday,” with a neutral row indicator. | Equal light/dark render inspection. |
| Sub-second platform progress was capped against a one-second minimum. | Relative row bars use the actual peak, with a small numerical safety floor. | Sub-minute fixture inspection. |
| Disabled recording could still look ready to track. | Off/disconnected status is explicit; Off opens setup and the pause control is disabled while recording is off. | Genuine isolated first-run light/dark renders. |
| Weekly omitted weekday/date/Today labels and per-platform daily averages. | Restored these labels and averages, with a compact date range. | Weekly and weekly-detail renders compared with the reference. |
| Retention used a different visual control from the prototype. | A compact capsule menu now provides 7/30/90 days. Row comparison labels explicitly say yesterday. | Preferences and Daily renders inspected against the approved references. |

## Checks executed

| Area | Result and boundary |
| --- | --- |
| Core Swift tests | **21 pass**: privacy/framing, timing, switches, idle cutoff, stale snapshots, generation invalidation, exclusion boundaries, PSL/aliases, comparisons, hourly/midnight/DST boundaries, storage reopen/retention/deletion, and invalid storage location. Autumn clock fallback now explicitly verifies repeated 01:00 time shares one local bucket without losing seconds. |
| Chrome extension | **3 Node tests pass**, with strict TypeScript build. Includes hostname-only normalization, private/internal/file/malformed pages, event ordering, stale async queries, reconnect, and focus changes. Browser APIs are mocked. |
| App-model integration | **21 assertions pass** using a temporary SQLite directory and a unique preferences suite that is removed afterward. Includes restart restoration, today/yesterday/week/menu consistency, idle retention on disk, normalized/deduplicated exclusions, invalid input, pause/resume, durable deletion, preference preservation/reload, storage failure, and recovery. |
| Appearance | **6 transitions pass** in the same NSPanel: explicit Light/Dark against opposite simulated system themes, plus System under both themes. AppKit and SwiftUI agree; the Preferences route remains selected. This does not click the actual switch or change global macOS appearance. |
| Native bridge | **Pass** with actual app/helper/socket in temporary directories: framing, privacy checks, ordering, origin restriction, reconnect, app loss, and permissions. Synthetic hostnames only. |
| Recording through disk | **Pass**: actual app → helper → eligibility/accounting → SQLite, about 12 eligible synthetic seconds followed by 10 unavailable seconds. Only the eligible interval accumulates. Duplicate app launch is rejected before storage opens; a forced crash releases the lease, and the replacement restores durable totals and reconnects the existing helper without downtime backfill. The lease file is mode 0600. Native Chrome foreground is explicitly simulated. |
| Accelerated duration | **Pass**: 600 deterministic seconds across midnight, durable reopen, retention, deletion. This is not the real-browser ten-minute accuracy experiment. |
| Invalid installed-setup commands | **6 invalid cases rejected with status 64**. Saved preferences and Chrome host configuration/registration fingerprints remained unchanged. |
| Lock smoke check on installed app | **Pass for sampled interval**: aggregate seconds did not increase over 15 seconds; the native lock signal was locked at both endpoints. No browsing domains were printed or copied. Unlock/wake transitions remain untested. |
| Packaging | **Pass**: strict deep ad hoc signature check and development ZIP creation. This does not establish production signing/notarization. |
| Native UI interactions | **41 assertions pass** in the isolated sample window through native computer control. Includes periods, detail Back state, exclusions, actual Light/Dark/System controls, retention menu options, validation, Return submission, setup scrolling, recording off/on, pause/resume and Command-Shift-P, deletion Cancel/Confirm, and empty-state refresh. Quit was also exercised; the installed app remained running. |
| Native visual artifacts | **36 renders**: 16 standard light/dark panels, 2 full settings/setup content views, 16 comparison/empty fixtures, and 2 genuine isolated first-run panels. Critical comparison, first-run, Daily, detail, Weekly, and Preferences renders were inspected; renders do not prove pointer/keyboard behavior. |

## Visual comparison

Compared the native captures with `docs/media/daily-2x.png`, `preferences-dark-2x.png`, and `weekly-2x.png`, together with the prototype detail markup. The native implementation follows the 390-point panel width, rounded glass direction, system typography, split duration display, Daily/Weekly tabs, Yesterday shortcut, vector brand marks, colored progress bars, stacked comparisons, and compact footer/settings layout.

The prototype has a simulated wallpaper and browser connection, fixed dates, and illustrative zero-hour bar stubs. Native glass depends on the real desktop and system settings; empty hours remain genuinely empty. Native setup also exposes the real installation/permission steps and honestly reports Safari unavailable. Duration displays truncate whole minutes consistently; the illustrative prototype rounds some daily averages. These differences are deliberate. Live light/dark material and settings were inspected in the isolated native window; the actual switch updated the same window immediately. Exact wallpaper-dependent material pixels and the installed menu-panel placement are not certified by those captures.

| Missing baseline: no invented comparison | Equal totals: neutral comparison |
| --- | --- |
| ![Missing yesterday data, light](media/audit/missing-yesterday-light.png) | ![Equal totals, dark](media/audit/equal-dark.png) |

| More time: red plus arrow | Actual isolated first run: recording off |
| --- | --- |
| ![Higher usage, light](media/audit/higher-light.png) | ![First run, dark](media/audit/first-run-dark.png) |

All committed audit images contain synthetic activity or an empty isolated store. No screenshot of personal browsing or private activity is included.

## Interactive check results

Use `.build/SurfMeter.app/Contents/MacOS/SurfMeter --ui-audit` for sample-data interaction. This mode opens a labeled window, does not start the normal bridge, and never opens the normal activity store or preferences. Quit that audit process afterward.

| Sequence | Expected result | Current status |
| --- | --- | --- |
| Daily → Yesterday → Yesterday again | 3h 10m → 4h 2m → 3h 10m in the sample window. | **Pass** in isolated native UI. |
| Yesterday → Weekly → Daily | Seven-day view, then Daily opens today. | **Pass** in isolated native UI. |
| Open a platform from Daily/Yesterday/Weekly; go Back | Correct hourly/daily detail; Back preserves the selected period/date. | **Pass** in isolated native UI. |
| Preferences → Dark appearance off/on → Use system | The same open panel and native controls update immediately; navigation is preserved. | **Pass**: actual switch off/on and Use system; same-window light/dark screenshots inspected. |
| Retention menu → 7/30/90 days | Menu selection updates; retention persists. | **Pass**: all three actual menu choices; model suite separately verifies persistence. |
| Add valid/invalid domain, duplicate alias; remove chip | Correct normalization/error; no duplicated entry; removal works. | **Pass**: validation, normalization, removal, and Return submission; alias deduplication also passes the model suite. |
| Pause/resume from status and footer; keyboard shortcut | Controls stay consistent and no paused time accumulates. | **Pass**: footer Pause, status Resume, and Command-Shift-P twice. Eligibility exclusion passes core tests. |
| Delete activity → Cancel; then confirm in sample window | Cancel preserves totals; confirm clears them. Never run this on personal history for testing. | **Pass**: actual Cancel preserves 3h 10m; confirmation produces 0m and empty state. Durable deletion/reopen passes model checks. |
| Preferences → Connected browsers → Back; scroll setup | All setup controls reachable; Safari clearly unavailable. | **Pass**: actual route, Back, and scrolling to Safari status; recording toggle off/on and Pause disabled state checked. |
| Open/close the installed menu panel and change appearance | Correct screen placement and real material; no duplicate app or reset state. | **Tool blocked**: the menu-only panel was not exposed by the native automation service. No installed-panel placement pass is claimed. |
| Tab/Shift-Tab/Space/Enter, VoiceOver, contrast/transparency/motion settings | Controls reachable and correctly named; readable fallbacks. | **Partial**: Return submission, Command-Shift-P, and hour/duration accessibility entries pass. Full Tab order, spoken VoiceOver and system accessibility settings remain pending. |

Real-browser gates remain the ones in [Validation](validation.md): a controlled ten-minute accuracy session; real private/minimized/internal pages and multiple profiles/windows; permission loss; idle/sleep/unlock/recovery; login/reboot; performance; supported older OS/Intel; and Safari implementation. A green automated run does not close these gates.

## Reproduce

After installing extension dependencies with `cd extensions/chrome && npm ci`, run from the repository root:

```sh
./scripts/audit-native.sh
```

The script builds/tests the extension and native app, runs the isolated integration/model/theme checks, packages the ad hoc build, and writes standard/edge-case renders to a new temporary directory. Its final output gives the location. Inspect those images and perform the pending interaction table separately; the script does not declare a visual or real-browser pass automatically.
