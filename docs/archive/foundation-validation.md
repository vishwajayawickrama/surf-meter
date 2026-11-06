# Native foundation validation

Historical foundation session: 2026-11-05. For the expanded 2026-11-06 app, see [Current validation](../validation.md). Task 1 remains **In progress**. Synthetic tests prove the native path works; they do not certify Safari/Chrome integration or accurate time accounting.

## Environment

- Apple Silicon Mac; macOS 27.2 (26B123).
- Apple Swift 6.4, Command Line Tools. Full Xcode is absent.
- Installed Safari 27.2; Google Chrome 156.0.8078.80. Installed versions are not a verified support guarantee.
- Deployment target: macOS 14 for the foundation (SwiftData planned in Task 3). macOS 14 execution and Intel builds are unverified.
- The feasibility check used the pinned TypeScript 5.9.3 compiler with npm integrity verification. Current development uses Node and `npm ci` as described in the development guide.

## Recorded checks

| Check | Result | Evidence / limit |
| --- | --- | --- |
| Native build and ad hoc app signing | Pass | `./scripts/build-native.sh` produces `.build/SurfMeter.app`. CLT linker emits missing optional developer-directory search-path warnings, but succeeds. |
| Protocol unit tests | Pass | Six Swift Testing tests: roundtrip, URL/domain rejection, excluded-state privacy, unknown fields/version/sequence, framing/EOF, truncation/size limits. |
| TypeScript compile | Pass | TypeScript 5.9.3 strict mode; emitted worker modules. |
| Extension logic checks | Pass | Three Node tests: hostname normalization, private/internal/background exclusion, focus events, stale query suppression, reconnect, sequence continuity. Browser APIs are mocked. |
| Actual app/helper IPC | Pass | `python3 scripts/verify-native-bridge.py`: built SwiftUI app, real helper stdin/stdout and Unix socket, fragmented frames, duplicate rejection, invalid payload/browser rejection, helper reconnect, missing app negative reply, wrong-origin rejection, 0700/0600 permissions. Uses synthetic `example.com`, no browser history. |
| Native menu bar appearance / interaction | Pending | App launches during IPC test; manual visual inspection still required. |
| Foreground and idle signals | Implemented, manual checks pending | AppKit activation notifications; `CGEventSource.secondsSinceLastEventType`, no input contents collected. |
| Sleep/wake | Implemented, manual checks pending | NSWorkspace notifications clear snapshots. No actual sleep test performed. |
| Screen lock / session switching | Pending | No validated lock detector yet; must fail closed before accounting ships. |
| Real Chrome tab/window/private behavior | Pending | Requires loading unpacked extension and registering its exact extension ID. Private exclusion tests above are synthetic. |
| Chrome suspension, restart, app launch, permission loss, multi-profile | Pending | Current helper requires app open; retry delay is not yet an accepted latency result. One-profile development path only. |
| Real Safari and sandbox-compatible IPC | Pending | Needs full Xcode and packaged Safari Web Extension. No Safari handler is claimed implemented. |
| Production authentication, signing, notarization | Pending | Development ad hoc signing only; UID validation is not code-signature authentication. |

## Reproduce

Follow [Development](../development.md) for build, tests, and Chrome setup. A constrained coding sandbox may need approval to launch the native UI and bind the local socket. The integration test cleans up the app, helper, and temporary socket directory when finished.

Swift 6.4 CLT's default build system omitted the Swift Testing macro plugin. `scripts/test-native.sh` supplies the installed plugin path explicitly when using CLT and disables XCTest (not installed here). The six tests then pass. Initial XCTest and unconfigured Swift Testing attempts failed; those failures were toolchain setup issues and are not reported as passes.

## Next validation session

1. Load the unpacked Chrome extension and use its actual ID to register the host. Start SurfMeter, click the extension action, and verify a real hostname appears.
2. Exercise tab switches, two windows, minimized windows, private windows, internal pages, browser/app restart, permission revocation, and worker suspension. Record observed states and recovery times here.
3. Install full Xcode, package Safari, prove the sandbox-safe handler-to-app path, and run the same browser matrix.
4. Inspect native UI and validate foreground, idle, sleep/wake, lock/session, app-launch behavior, and minimum macOS version. Resolve failures before marking Task 1 Done or releasing browser support. Independent engine/storage/UI work was subsequently authorized on 2026-11-06.
