# SurfMeter — Implementation

Updated: 2026-11-06

This is the implementation tracker for the native macOS app. The five tasks retain their acceptance dependencies; each may span multiple sessions. On 2026-11-06 the user authorized whole-app development, so independent engine, storage, and UI work proceeded while real-browser feasibility gates stayed open. The web prototype remains the approved UI reference. A native development implementation now exists; it is not a certified release.

Setup: [annotated guide](SETUP.md) · Requirements: [SRS](SRS.md) · Technical direction: [Architecture](ARCHITECTURE.md) · Run the prototype: [Development guide](DEVELOPMENT.md)

## Progress

| Task | Deliverable | Status | Depends on |
| --- | --- | --- | --- |
| 1 | Native foundation and browser feasibility | In progress | — |
| 2 | Accurate activity tracking engine | In progress | 1 |
| 3 | Local storage and usage summaries | In progress | 2 |
| 4 | Native UI and complete app integration | In progress | 3 |
| 5 | Validation, packaging, and first release | In progress | 4 |

**Next action:** Run the native app, connect Chrome through Browser setup, and record the real-browser privacy/accuracy/lifecycle matrix in [Validation](VALIDATION.md). Install full Xcode for Safari packaging. Complete production identity/signing/notarization and clean-install/performance checks before calling this a release.

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

**Evidence / handoff — 2026-11-06:** Buildable app, shared core, exact-origin Chrome helper/extension, bundled resources, same-user socket, GUI registration, reconnect action, and app launch attempt on a new helper session are implemented. The expanded app/helper synthetic tests pass. Native foreground/idle/screen/session signals are connected, with lock-specific supplemental signals still requiring validation. Real Chrome privacy/focus/recovery, multiple profiles, Safari packaging/sandbox IPC, production identities, and supported OS execution remain pending. Full Xcode is absent. See [current validation](VALIDATION.md), [historical foundation checks](FOUNDATION-VALIDATION.md), and [setup](DEVELOPMENT.md).

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

**Evidence / handoff — 2026-11-06:** `TrackingEngine`, `TrackingEligibility`, `DomainClassifier`, and `UsageLedger` are implemented and wired into the native app. Monotonic samples, idle/freshness cutoff, generation-based invalidation, pause/system/exclusion gates, domain aliases and bundled PSL, hour/midnight/DST splitting, and clock/gap resets have automated checks. A real app/helper synthetic recording test verifies accounting and database updates. Actual browser accuracy, multiple profiles, lock/session behavior, and recovery timing remain pending. See [validation](VALIDATION.md).

## Task 3 — Local storage and usage summaries

**Outcome:** Durable local usage data that powers consistent Daily, Yesterday, Weekly, and platform detail views.

**Scope**

- Resolve the hourly aggregate decision identified in the architecture: update FR-33, the data model, and retention requirements to permit the minimum aggregate data needed for FR-39, or explicitly revise that chart requirement before implementing storage. Do not store raw browsing-event history.
- Add local aggregate models behind a repository boundary (implemented using Core Data; see architecture decision). Keep the main app as the single writer and leave cloud synchronization disabled.
- Persist duration totals and minimal coverage metadata with explicit checkpoints. Handle write failures and satisfy the SRS crash-loss target.
- Build queries for today's total, yesterday's full day, the last seven local calendar days, daily averages, and per-platform details. Derive the weekly view from the same recorded data as Daily.
- Implement retention, delete-all activity, empty states, and incomplete-coverage explanations. Persist small settings through the preferences layer.

**Done when**

- Data survives app restarts; downtime adds no time, and checkpoint recovery satisfies the loss target.
- Checks cover aggregation, comparison direction, equal/zero values, rounding, midnight, partial days, retention, deletion, and storage failure handling.
- Daily totals, weekly totals, charts, and platform details agree for the same seeded records.
- Inspecting stored data and diagnostics confirms that paths, queries, page titles, content, and raw browsing history are absent.

**Evidence / handoff — 2026-11-06:** FR-33 now permits hourly aggregates; FR-39 is retained. `UsageStore` uses a programmatic Core Data/SQLite schema because CLT lacks the SwiftData macro plugin. Explicit transactions, checkpointing, retention, reopen, coverage metadata, aggregate queries, deletion, and visible storage failure/retry are implemented. Disk/reopen/retention/deletion and invalid-location checks pass; forced crash-loss and runtime disk-full recovery still need validation. No browsing-event history is persisted.

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

**Evidence / handoff — 2026-11-06:** Native Daily/Weekly tabs, Yesterday toggle, comparisons, charts/details, pause/resume, setup, exclusions, appearance, retention, confirmed deletion, login service control, and menu bar today total are implemented. A bundled Chrome extension/helper and GUI exact-origin registration remove checkout dependencies from the app path. SwiftUI renders were inspected in light/dark at 2×; captures use labeled sample data and opaque backgrounds. Actual keyboard/VoiceOver/material/contrast, login approval, and clean browser onboarding checks remain pending. Safari is explicitly shown unavailable.

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

**Evidence / handoff — 2026-11-06:** Automated core/extension checks, actual app/helper tests, native preview rendering, ad hoc signature verification, and `.build/SurfMeter-0.2.0-development.zip` packaging are available. [Validation](VALIDATION.md) separates simulated checks from outstanding real-browser acceptance. No public release, notarization, Safari package, minimum-OS/Intel guarantee, performance certification, or clean-install certification is claimed. Next: complete the manual matrix and signing prerequisites; do not mark the release Done based on development packaging.

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

## Latest session handoff — 2026-11-06

Implemented the native development app through accounting, persistence, and interface integration. Run commands and data/setup/removal locations are in [Development](DEVELOPMENT.md). Current automated and pending manual evidence is in [Validation](VALIDATION.md). All five tasks retain open acceptance gates rather than claiming Done from synthetic tests. The current checkpoint is identifiable by the Git commit titled “Build native tracking, storage, and dashboard”.
