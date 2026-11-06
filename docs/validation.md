# SurfMeter 0.2 development validation

Date: 2026-11-06. Environment: Apple Silicon, macOS 27.2 (26B123), Swift 6.4 CLT; installed Chrome 156.0.8078.80 and Safari 27.2. Browser versions are inventory, not a support certification. Full Xcode is not installed.

This is an implemented development app, not a completed release. Synthetic inputs are explicitly distinguished from real-browser evidence. The original foundation record remains in [Foundation validation](archive/foundation-validation.md).

## Automated and artifact checks

| Check | Result | Evidence |
| --- | --- | --- |
| Native build | Pass | `./scripts/build-native.sh`; SwiftUI app, shared core, host, bundled PSL, bundled Chrome extension. |
| Swift tests | Pass | 21 tests with `./scripts/test-native.sh`. Protocol privacy/framing plus accounting, eligibility, public suffixes/aliases, boundary cases, aggregate queries, persistent reopen/retention/deletion, and invalid store location. |
| TypeScript and extension tests | Pass | Strict TypeScript 5.9.3 compile and three Node tests. Browser APIs are mocked; no real browser privacy claim follows. |
| Native bridge | Pass | `python3 scripts/verify-native-bridge.py`: actual app/helper/socket, framing, origin check, duplicate ordering, rejection, reconnect, app loss, directory/socket permissions. Synthetic hostnames only. |
| Native recording into disk | Pass | `python3 scripts/verify-recording.py`: actual app/helper/model/engine/Core Data database, about 12 synthetic eligible seconds under YouTube, unavailable intervals add no time, duplicate startup is rejected, and crash/restart checks preserve checkpointed totals without backfill. Isolated data/preferences; simulated native eligibility. |
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

1. Follow [Development](development.md) to compile the extension and app and run tests.
2. Open the app, connect the unpacked Chrome extension using its actual ID, and explicitly enable recording. Do not use `--demo` or `--simulate-chrome` for real-browser validation.
3. Record results, durations, browser/OS versions, app revision, and failures against the table above. Fix failures before marking a task Done; do not turn a pending manual check into a pass based on synthetic tests.

## Audit evidence

The [functional and visual audit](qa-audit.md) contains the findings and detailed reproduction evidence. Its current baseline includes 21 Swift tests, 3 extension tests, 21 isolated model assertions, 6 same-panel appearance transitions, 41 sample-window UI assertions, bridge/recording integration, duplicate-writer rejection, forced-crash lease release, checkpointed restart recovery, and ad hoc packaging. The exporter supplies 36 native panels/content/edge cases for visual review.

A local installation smoke check exercised Chrome-to-store recording, no increase during a background interval, and a sampled locked interval. These checks are narrower than the controlled accuracy, privacy, and lifecycle matrix. Invalid setup arguments were rejected without configuration changes. Actual menu-panel placement remains tool-blocked; full accessibility and browser/system acceptance remain open.

The writer lease is acquired before Core Data opens. A second service-enabled process exits with status 75 instead of checkpointing stale totals. The crash/restart check continues unavailable input beyond the replacement's ten-second checkpoint before comparing SQLite totals. User-facing collection and login remain opt-in.

## Repository maintenance

The source/test directories use explicit kebab-case Swift Package paths. Markdown links, exact path casing, heading anchors, and publication hygiene are checked by `python3 scripts/check-repo.py`; the full audit runs this check before building. `--history` additionally scans reachable text blobs for common credential and machine-specific path patterns. The cleanup check found no matches, preserved upstream notices/data, and passed the full native/extension audit after the directory moves.
