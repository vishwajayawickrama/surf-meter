# SurfMeter 0.2 development validation

Date: 2026-11-06. Environment: Apple Silicon, macOS 27.2 (26B123), Swift 6.4 CLT; installed Chrome 156.0.8078.80 and Safari 27.2. Browser versions are inventory, not a support certification. Full Xcode is not installed.

This is an implemented development app, not a completed release. Synthetic inputs are explicitly distinguished from real-browser evidence. The original foundation record remains in [Foundation validation](FOUNDATION-VALIDATION.md).

## Automated and artifact checks

| Check | Result | Evidence |
| --- | --- | --- |
| Native build | Pass | `./scripts/build-native.sh`; SwiftUI app, shared core, host, bundled PSL, bundled Chrome extension. |
| Swift tests | Pass | 21 tests with `./scripts/test-native.sh`. Protocol privacy/framing plus accounting, eligibility, public suffixes/aliases, boundary cases, aggregate queries, persistent reopen/retention/deletion, and invalid store location. |
| TypeScript and extension tests | Pass | Strict TypeScript 5.9.3 compile and three Node tests. Browser APIs are mocked; no real browser privacy claim follows. |
| Native bridge | Pass | `python3 scripts/verify-native-bridge.py`: actual app/helper/socket, framing, origin check, duplicate ordering, rejection, reconnect, app loss, directory/socket permissions. Synthetic hostnames only. |
| Native recording into disk | Pass | `python3 scripts/verify-recording.py`: actual app/helper/model/engine/Core Data database, about 12 synthetic eligible seconds under YouTube, then 10 seconds of unavailable snapshots add no time. Isolated data/preferences; simulated native eligibility. |
| Accelerated ten-minute session | Pass | Built `SurfMeterVerification`: 600 deterministic seconds split across midnight, store reopen, retention, deletion. Not the NFR-01 real-browser accuracy experiment. |
| Native screen rendering | Pass for layout inspection | AppKit-hosted SwiftUI light/dark renders of Daily, Yesterday, Weekly, details, Preferences, setup. Opaque, sample-data 2× captures in `docs/media/native`; not live material/accessibility testing. |
| Ad hoc packaging | Pass | `./scripts/package-app.sh`, deep strict signature verification, local development ZIP. Resource bundle and extension included. |

The preview exporter uses offscreen AppKit-hosted SwiftUI windows and captures their own view bitmaps, including native controls and scroll views. It does not take desktop screenshots. Synthetic eligibility is accepted only in an explicitly isolated test mode; normal recording requires real native/browser signals.

## Acceptance coverage

| Criteria | Current evidence | Open check |
| --- | --- | --- |
| AC-01 accurate foreground usage | Deterministic engine and integrated synthetic app recording pass | Real ten-minute browsing session within five seconds. |
| AC-02/03 foreground and no double count | Native eligibility and transition tests pass | Real apps, windows, browsers/profiles; Safari not implemented. |
| AC-04 idle | Threshold clipping/resume logic tests pass | Actual three-minute no-input experiment. |
| AC-05 sleep/lock | Native notifications and fail-closed engine gates implemented | Actual sleep, lock, unlock, startup-locked, fast user switching. Supplemental lock signals are not certified public API contracts. |
| AC-06/07/08 comparisons | Seconds-based tests plus native lower/equal/higher/missing/zero/sub-minute renders; sample platform comparisons inspected | Real recorded coverage across local days remains part of browser validation. |
| AC-09 empty state | Genuine isolated first-run renders and actual sample deletion → empty-state interaction pass | Clean-install onboarding certification remains open. |
| AC-10 midnight | Hour/day split plus accelerated disk verification pass | Real session across local midnight. |
| AC-11 domains/exclusions/private | PSL wildcards/exceptions, aliases, boundaries, exclusions, private normalization tests pass | Real private-window/focus/permission behavior for each advertised browser. |
| AC-12 restart/pause | Preferences persist, disk reopen tested, no clock backfill | Real pause/relaunch/resume; native helper automatic app launch/recovery. |
| AC-13 permission loss | Unavailable and freshness gates implemented/tested | Revoke tabs/native integration while browsing. |
| AC-14 deletion | Durable model deletion/reopen and actual sample UI Cancel/Confirm → refreshed totals pass | Runtime save-failure behavior during deletion remains untested. |
| AC-15 clock/time zone | Monotonic engine/calendar/DST tests pass; app resets on discontinuity | Actual system changes without changing historical day keys. |
| AC-16 privacy | Versioned strict fields, hostname-only bridge, aggregate-only schema, no payload logs | Inspect production store/logs after real URL/path/query session. |
| AC-17/18/19 period navigation | Actual native period/detail/Back interactions and model aggregate/menu consistency pass | Installed menu-only panel attachment is tool-blocked; real-browser totals still require accuracy validation. |

## Release gates still open

- Real Chrome single/multiple window and profile behavior, minimized/private/internal pages, permission loss, worker suspension, reconnect/relaunch latency, and measured attribution accuracy.
- Full Xcode, a packaged Safari Web Extension/handler, sandbox-compatible IPC, privacy matrix, and browser support decisions. Safari is explicitly unavailable in the app; the SRS retains it as a target.
- Production IPC authentication/code-signature identities, Developer ID signing, notarization, distribution channel, clean installation/onboarding/removal, and update process. Current UID checks are a development boundary.
- macOS 14 and Intel execution. macOS 27.2/Apple Silicon is the only exercised machine configuration.
- Real login-item enable/approval/disable behavior, settings persistence across bundle relocation, and actual keyboard/VoiceOver/contrast/transparency/motion checks. Native fallbacks and accessible names are implemented; they are not manually certified.
- Thirty-minute CPU/memory measurement, dashboard-open latency, forced-crash checkpoint-loss measurement, disk-full/write-failure/retry behavior. Invalid-path failure is tested, but is not a substitute for a runtime disk-full experiment.

## Reproduction order

1. Follow [Development](DEVELOPMENT.md) to compile the extension and app and run tests.
2. Open the app, connect the unpacked Chrome extension using its actual ID, and explicitly enable recording. Do not use `--demo` or `--simulate-chrome` for real-browser validation.
3. Record results, durations, browser/OS versions, app revision, and failures against the table above. Fix failures before marking a task Done; do not turn a pending manual check into a pass based on synthetic tests.

## Local installation smoke check — 2026-11-06

The development app was installed under `/Applications`, its bundled Chrome extension was loaded through Chrome's normal extension manager with user approval, and an exact-origin native registration was installed. Chrome reported the bridge connected and live activity reached the local aggregate store. With Chrome not foreground at both ends of a subsequent 12-second check, the recorded aggregate did not increase. This is a local connection/eligibility smoke check, not the controlled NFR-01 accuracy experiment or the private-window/lifecycle matrix.

The user explicitly opted into recording and launch at login. The installed app's setup command saved enabled/unpaused recording while preserving other preferences; `SMAppService` reported login enabled on this Mac. Cold-login/reboot, production signing, and clean-install approval behavior remain separate checks. Chrome's toolbar pin was on and local-file access was turned off. No personal browsing domains or installation screenshots are committed to the repository.

Node.js LTS/npm were installed for the local build. The expanded native build and 20 Swift tests passed. The installed setup command also rejected malformed IDs/unknown flags with exit status 64 before configuration changes. The command runs before the activity model, so it does not become a second database writer or bridge server.

## Prototype alignment and appearance regression — 2026-11-06

The native panel now uses the approved prototype’s 390-point width, system typography, split duration display, daily hourly chart, vector platform marks, platform-colored progress bars, stacked comparisons, and Preferences layout. Light/dark captures of all six screens were refreshed at 2×; setup annotations now follow Preferences → Connected browsers. Real connection and coverage states remain distinct from the prototype’s sample states.

`--verify-appearance` passed Light → Dark → Light → Dark → System in the same open NSPanel. It checks window effective appearance, the SwiftUI color scheme, and preservation of the Preferences route. A window-scoped AppKit override replaces presentation-level `preferredColorScheme`; system mode clears the override. The menu bar itself retains macOS appearance. This is an isolated AppKit-hosted regression check, not certification of every accessibility setting or live glass rendering condition. All 20 Swift tests also passed after the UI changes.

The revised build was installed at `/Applications/SurfMeter.app` and relaunched. A before/after check confirmed unchanged saved preferences and preserved aggregate activity; the existing bundled-extension location and native registration were retained.

## Rigorous development audit — 2026-11-06

See [the audit report](QA-AUDIT.md) for findings, evidence, native screenshots, reproduction commands, and pending interaction checks. The repeatable `scripts/audit-native.sh` passes 21 Swift tests (including autumn DST fallback), 3 extension tests, 21 isolated app-model assertions, 6 same-panel appearance transitions, bridge and recording integration, the accelerated ten-minute scenario, and packaging. It also renders 36 native panels/content/edge cases for separate visual review.

The audit fixed idle retention not persisting deletions immediately, missing-baseline comparisons, an incorrectly wired bridge retry action, equal-time wording, tiny-duration progress, disabled-recording status, and weekly display omissions. Six invalid setup commands were also rejected without changing preferences or Chrome registration. An installed-app lock smoke check observed unchanged aggregate seconds across 15 seconds with the lock signal set at both endpoints.

Native computer control initially reported the Mac locked on two attempts. Once available, the isolated native window passed 41 interaction assertions, including the actual theme switch, navigation, retention menu, exclusions, keyboard shortcuts/Return submission, recording controls, and deletion confirmation/cancel. Light/dark live window material was inspected and the hourly accessibility entries corrected. Installed menu-panel placement, full accessibility settings, and the real-browser acceptance matrix remain separate checks.

A final single-writer review found that the existing socket lock did not protect Core Data from a second unconnected model. A new integration assertion reproduced the old behavior: the duplicate remained running until the three-second test timeout. The fix acquires a separate private activity writer lease before opening Core Data and exits duplicate launches with status 75. The normal setup command still runs before the model and does not acquire a store or bridge.

The strengthened restart check continues unavailable input beyond the replacement app's ten-second checkpoint before comparing SQLite totals; it therefore checks a fresh durable save. Duplicate rejection, forced-crash lease release, helper reuse, and no-backfill assertions pass. The installed build was updated afterward: preferences and aggregate history were preserved, and one installed process was verified to own the activity writer lease.
