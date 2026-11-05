# SurfMeter — Implementation

Updated: 2026-11-05

This is the implementation tracker for the native macOS app. Work through the five tasks in order; a task may span multiple sessions. The existing web prototype is the approved UI reference, not a completed native implementation.

Requirements: [SRS](SRS.md) · Technical direction: [Architecture](ARCHITECTURE.md) · Run the prototype: [Development guide](DEVELOPMENT.md)

## Progress

| Task | Deliverable | Status | Depends on |
| --- | --- | --- | --- |
| 1 | Native foundation and browser feasibility | In progress | — |
| 2 | Accurate activity tracking engine | Not started | 1 |
| 3 | Local storage and usage summaries | Not started | 2 |
| 4 | Native UI and complete app integration | Not started | 3 |
| 5 | Validation, packaging, and first release | Not started | 4 |

**Next action:** Load the Chrome extension and register its actual extension ID, then record real-browser checks. Install full Xcode to package and validate Safari; finish native lifecycle and launch/recovery validation before Task 2.

## Task 1 — Native foundation and browser feasibility

**Outcome:** A buildable Mac menu bar app and evidence that the proposed browser integrations can support accurate, private tracking.

**Scope**

- Inspect the installed toolchain and record build prerequisites. Create the native Swift/SwiftUI app, a shared Swift package for core logic, and the browser extension/helper structure.
- Add a minimal `MenuBarExtra` shell with a connection status view. Keep this shell functional and simple until Task 4 recreates the approved design.
- Define a small, versioned browser-state message contract shared by the TypeScript extensions and Swift adapters. Normalize to a hostname and avoid sending page content, titles, or URL paths/queries.
- Prove a connection from one browser through its native adapter to the running app, then validate the Safari and Chrome adapters, permission requirements, private-window exclusion, focus/tab changes, and reconnection behavior.
- Select and demonstrate the local IPC path from the Safari native handler and Chrome native messaging host to the main app. Validate message identity restrictions and app-launch behavior.
- Verify the OS signals needed for foreground app, idle, sleep, and lock detection. Record the proposed minimum macOS version, supported browser versions, signing/extension prerequisites, and any concrete limitations.

**Done when**

- A fresh checkout can build and launch the menu bar shell using documented commands or Xcode steps.
- Real browser state reaches the app through the intended native bridge; no timers or database writes run inside the extensions.
- Safari and Chrome have a recorded pass/fail result for the required signals, private-window exclusion, and connection recovery. Any support reduction is explicitly resolved in the SRS before moving on.
- The architecture and development guide describe the chosen bridge, permissions, support matrix, and reproducible integration checks. A dependency requiring user setup is recorded as pending, not as a passed check.

**Evidence / handoff — 2026-11-05:** Native Swift Package foundation added: `SurfMeterCore`, `SurfMeterApp` (`MenuBarExtra`), and `SurfMeterNativeHost`. Strict TypeScript Chrome extension, versioned hostname-only contract, same-user Unix socket IPC, ad hoc app bundling, exact-origin registration preparation, and reproducible checks are implemented. Build succeeded on macOS 27.2 / Swift 6.4 CLT. Six Swift tests, three extension tests, and a real app/helper IPC test with synthetic data passed. See [validation record](FOUNDATION-VALIDATION.md), [protocol](BROWSER-PROTOCOL.md), and [setup](DEVELOPMENT.md). Real Chrome events, Safari packaging/IPC, minimum OS execution, screen lock, manual native UI/OS signals, and app-launch/recovery behavior remain pending. Full Xcode is absent. No accounting or database exists yet. Next: complete the real Chrome matrix with its installed extension ID; then Safari and OS feasibility. This task is not Done.

## Task 2 — Accurate activity tracking engine

**Outcome:** A native engine that attributes eligible elapsed time to exactly one platform.

**Scope**

- Implement the engine independently of SwiftUI and persistence, using injected clocks and an in-memory sink for verification.
- Combine browser state with the native foreground app, idle threshold, sleep/lock state, pause state, exclusions, and integration health.
- Handle tab, domain, window, and browser changes without double counting. Stop attribution when state becomes unavailable or stale; reconcile current state after reconnecting without inventing usage for gaps.
- Implement platform aliases, public-suffix-aware domain grouping, and exclusion matching with hostname boundaries. Ignore unsupported URL schemes and private browsing.
- Measure duration with elapsed time and split intervals at local day boundaries. Handle clock/time-zone changes, restart, and resume according to the SRS.

**Done when**

- Deterministic tests cover tab/app switches, competing browsers, idle cutoff, sleep/lock, pause, exclusions, private/internal pages, stale state, disconnect/reconnect, midnight, and clock/time-zone changes.
- Domain checks distinguish platform subdomains from lookalikes and unrelated sites under public suffixes.
- A controlled real-browser session demonstrates attribution within the SRS accuracy target. Record any failing case rather than relaxing the target silently.

**Evidence / handoff:** Not started. Record test commands, observed accuracy, and remaining edge cases here.

## Task 3 — Local storage and usage summaries

**Outcome:** Durable local usage data that powers consistent Daily, Yesterday, Weekly, and platform detail views.

**Scope**

- Resolve the hourly aggregate decision identified in the architecture: update FR-33, the data model, and retention requirements to permit the minimum aggregate data needed for FR-39, or explicitly revise that chart requirement before implementing storage. Do not store raw browsing-event history.
- Add local SwiftData models behind a repository boundary. Keep the main app as the single writer and leave cloud synchronization disabled.
- Persist duration totals and minimal coverage metadata with explicit checkpoints. Handle write failures and satisfy the SRS crash-loss target.
- Build queries for today's total, yesterday's full day, the last seven local calendar days, daily averages, and per-platform details. Derive the weekly view from the same recorded data as Daily.
- Implement retention, delete-all activity, empty states, and incomplete-coverage explanations. Persist small settings through the preferences layer.

**Done when**

- Data survives app restarts; downtime adds no time, and checkpoint recovery satisfies the loss target.
- Checks cover aggregation, comparison direction, equal/zero values, rounding, midnight, partial days, retention, deletion, and storage failure handling.
- Daily totals, weekly totals, charts, and platform details agree for the same seeded records.
- Inspecting stored data and diagnostics confirms that paths, queries, page titles, content, and raw browsing history are absent.

**Evidence / handoff:** Not started. Record schema decisions, query/storage checks, and recovery results here.

## Task 4 — Native UI and complete app integration

**Outcome:** A usable native SurfMeter app that presents real tracked activity through the approved interface.

**Scope**

- Recreate the approved Daily/Weekly tabs, Yesterday shortcut, platform rows/details, charts, and today's menu bar total in SwiftUI.
- Adopt native Liquid Glass where supported, with readable content and compatible material fallbacks. Honor light/dark appearance, Reduce Transparency, Increase Contrast, Reduce Motion, keyboard navigation, and VoiceOver.
- Connect the UI to the native engine and persistent summaries. Preserve the selected period on return from details, and keep the menu bar total tied to today.
- Implement real browser setup, permission/connection recovery, pause/resume, exclusions, retention preference, confirmed deletion, launch at login, and quit.
- Show first-run, empty, paused, unavailable, incomplete-coverage, and persistence-error states with clear recovery actions. Keep sample data explicitly separated from real tracking.

**Done when**

- A user can install/connect a supported browser, browse, view recorded usage, pause/resume, exclude a domain, and delete activity through the native app.
- Daily, Yesterday, Weekly, and details behave as specified and update from real records.
- The native screens have been visually reviewed against the prototype in light and dark appearances; accessibility and material fallbacks have been exercised.
- Launch-at-login and connection/permission recovery have been verified on the chosen support matrix, with reproducible steps documented.

**Evidence / handoff:** Not started. Record end-to-end steps, native screenshots, and outstanding UI or permission issues here.

## Task 5 — Validation, packaging, and first release

**Outcome:** A verified first release that can be installed and used outside the development environment.

**Scope**

- Run every SRS acceptance criterion against the finished app. Record the app revision, hardware, macOS/browser versions, procedure, and result for each relevant check.
- Measure attribution accuracy, dashboard latency, CPU, memory, and checkpoint recovery against the SRS targets. Correct failures before calling the release ready.
- Verify data collection boundaries, private-window exclusion, permission loss, retention/deletion, and no account/backend dependency.
- Finalize the distribution channel. Configure signing, notarization, browser extension packaging, native host registration, and an installable artifact.
- Validate installation, onboarding, reconnect/relaunch, and removal on a clean test environment. Treat unavailable signing credentials or distribution access as pending prerequisites.
- Update the README with native screenshots, actual supported versions, installation steps, known limitations, and release status. Publish the versioned release artifacts when the release gates pass.

**Done when**

- Required acceptance criteria and quality targets pass with recorded evidence; unresolved issues are explicitly resolved or documented in an agreed scope revision.
- A signed/notarized app and required extension artifacts can be installed using the documented instructions on a clean supported Mac.
- Release documentation represents the native app's verified capabilities and distinguishes any remaining prototype-only behavior.
- The release version, commit, artifact location, and validation results are recorded below.

**Evidence / handoff:** Not started. Record the acceptance report, performance results, installation evidence, and release links here.

## Continuing across sessions

At the end of each implementation session, update the relevant task's status and its evidence/handoff paragraph. Use **Not started**, **In progress**, **Blocked**, or **Done**. Mark a task Done only when its completion criteria have been met and verified.

Leave enough context for the next session to resume without reconstructing the previous chat:

```text
Session date:
Current task and status:
Completed changes and commit:
Build/test/manual checks and results:
Decisions and documentation updated:
Known failures or external prerequisites:
Exact next action:
```

Keep the five task IDs stable. Add detail within the appropriate task rather than creating another top-level task. Update the SRS or architecture when implementation evidence changes a requirement or technical decision.
