# SurfMeter — Technology stack and architecture

Date: 2026-11-05

Status: Native foundation implemented; real-browser and OS feasibility checks remain in progress. The diagram shows the intended complete architecture, including components not implemented yet.

## Current implementation

The repository contains a Swift Package with a SwiftUI menu bar shell, shared protocol/IPC core, Swift Chrome native host, and strict TypeScript Chrome extension. Local app/helper IPC and protocol checks pass; real-browser validation and Safari packaging are pending. There is no accounting engine or persistent usage store yet.

The approved interactive UI prototype is built with HTML, CSS, and vanilla JavaScript. It runs with a local Python HTTP server, uses sample activity, and stores preview preferences in browser local storage. Browser connections and system settings are simulated.

The production direction is a native macOS app. The approved prototype provides the screen designs and interaction reference; those screens will be recreated in SwiftUI.

## Proposed stack

| Layer | Technology | Responsibility |
| --- | --- | --- |
| Application | Swift and SwiftUI | Daily/Weekly dashboard, Yesterday shortcut, platform details, preferences, and setup. |
| Menu bar | SwiftUI `MenuBarExtra`, with AppKit where needed | Today's usage label, application lifecycle, and popover presentation. |
| Appearance | Apple's system Liquid Glass APIs | Native materials and controls on supported macOS versions, with compatible material fallbacks. Honor accessibility and appearance preferences. |
| Browser extensions | TypeScript and WebExtensions | Observe the active website, selected tab, and browser-window focus. Share browser-independent logic and keep browser-specific adapters small. |
| Extension/app communication | Browser native messaging and a local Swift bridge | Deliver browser state to the app without a remote service. Safari and Chrome use different native integration mechanisms. |
| Tracking engine | Swift concurrency, AppKit, and macOS system APIs | Combine browser state with foreground-app, idle, sleep, lock, pause, and permission state; accumulate eligible time once. |
| Persistence | SwiftData, configured for local storage | Persist daily platform totals and minimal coverage metadata. The native app owns writes. |
| Preferences | SwiftUI `@AppStorage` / `UserDefaults` | Small settings such as pause state, appearance preference, and exclusions. No secrets belong here. |
| Build and dependencies | Xcode and Swift Package Manager; TypeScript compiler for extensions | Build the app, extension targets, and native messaging helper. Use dependencies only when needed. |
| Validation | Swift Testing / XCTest and browser integration checks | Verify duration accounting, grouping, rollover, persistence, and real browser behavior. |
| Distribution | Apple code signing and notarization | Prepare a distributable Mac app and the appropriate browser extension packages; finalize the delivery channel after the integration prototype. |

No backend, account system, cloud database, or cloud synchronization is planned for the MVP.

## Main components

The icon-led reference view (A) is the selected direction. It uses IBM Plex Sans typography and consistent Lucide technical symbols, alongside Safari and Chrome browser icons. The scope and meaning of connections are stated in the image.

### Icon-led reference architecture

A high-level view of the main components and primary information flow. Short labels sit below icons; browser adapters remain outside the main app boundary. This is the lightest overview for the README or an introduction to the system.

![Option A: Icon-led SurfMeter reference architecture with Safari and Chrome extensions, native adapters, a local bridge, Swift tracking engine, macOS signals, preferences, SwiftData storage, and menu bar UI.](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/diagrams/architecture-a-reference.png?v=2)

[Full-resolution PNG](diagrams/architecture-a-reference.png) · [SVG](diagrams/architecture-a-reference.svg) · [Editable diagram](diagrams/architecture-a-reference.drawio)

<details>
<summary>Earlier alternatives: C4 and layered views</summary>

### B — C4 component view

A formal component view scoped to `SurfMeter.app`. Internal components include their type, technology, and responsibility. Supporting native adapters and the local data store appear outside the application boundary. Browser extensions are described by their corresponding adapter rather than expanded at this level.

![Option B: C4 component view of SurfMeter with typed components, supporting native adapter containers, labeled relationships, and a local data store.](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/diagrams/architecture-b-c4.png)

[Full-resolution PNG](diagrams/architecture-b-c4.png) · [SVG](diagrams/architecture-b-c4.svg) · [Editable diagram](diagrams/architecture-b-c4.drawio)

### C — Layered architecture

A logical view organized into Presentation, Application, and Integration/data responsibilities. It emphasizes dependency direction and ownership. These layers are not process boundaries: the browser handlers/host still execute separately from the main app as described below.

![Option C: Layered SurfMeter architecture showing presentation, tracking logic, platform integration, persistence, and browser extensions.](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/diagrams/architecture-c-layered.png)

[Full-resolution PNG](diagrams/architecture-c-layered.png) · [SVG](diagrams/architecture-c-layered.svg) · [Editable diagram](diagrams/architecture-c-layered.drawio)

</details>

[All three pages in one diagrams.net file](diagrams/architecture-alternatives.drawio) · [Research, conventions, and regeneration](diagrams/README.md)

The extension reports browser state. The native engine determines whether that state qualifies for tracking. The extension does not independently run a second usage timer.

### Browser adapters

- **Safari:** package a Safari Web Extension with the Mac app. Its native extension handler receives messages and relays the needed state to the app.
- **Chrome:** use an extension and registered native messaging host implemented in Swift. The host relays validated browser state to the running app.
- **Shared contract:** v1 carries browser, worker session UUID, sequence, eligibility state, and optional normalized hostname. Tab/window identifiers are unnecessary for the current snapshot path and are omitted. See [protocol](BROWSER-PROTOCOL.md).
- **Connection lifecycle:** on startup or reconnection, request a current-state snapshot. Do not replay disconnected intervals as measured usage. Detect stale or disconnected integrations and stop affected attribution.

Native messaging is the extension-to-native boundary. The development Chrome host relays to the app using a private same-user Unix domain socket with framed JSON, restrictive filesystem permissions, peer UID validation, and an exclusive server lock. This path is tested with the actual app/helper and synthetic snapshots. Exact origin registration restricts extension access, but UID checks do not authenticate same-user processes by code signature. Safari sandbox compatibility, production authentication, packaging, and launch behavior remain unverified. The helper currently requires the app to be open. See [validation](FOUNDATION-VALIDATION.md).

Only the main app should write usage records. Browser adapters should not independently open and mutate the same model store. Limit native messaging access to the intended extension and validate incoming messages before accepting them.

### Tracking engine

Keep duration accounting separate from UI and browser transport so it can be tested with a deterministic clock and simulated events.

1. Receive the latest browser state and native eligibility state.
2. Close the current interval when its platform or eligibility changes.
3. Count only one active platform when the supported browser is foreground, its focused tab is eligible, and the user is active.
4. Stop on idle threshold, sleep, lock, pause, exclusion, missing access, or unavailable browser state.
5. Use elapsed time for duration measurement and local calendar boundaries for date attribution. Split intervals crossing midnight.
6. Checkpoint totals frequently enough to satisfy the SRS crash-loss target without writing on every display refresh.

Use AppKit workspace notifications for app activation and relevant lifecycle signals. Validate the appropriate system APIs for idle and lock detection during discovery. Idle detection needs elapsed time since input, not keyboard contents or a recording of input events.

### Storage and aggregation

- Persist local daily duration per normalized platform/domain and minimal coverage metadata, following the SRS retention policy.
- Compute Weekly from seven daily aggregates, including today so far. Keep today's menu bar total independent of the selected dashboard period.
- Store timestamps/day attribution consistently with the SRS time-zone policy. Preserve previously attributed days when the time zone changes.
- Keep full URLs, query strings, page titles, and browsing content out of persistent records and logs. Normalize to the required hostname/domain as early as possible.
- Configure SwiftData for local persistence without CloudKit synchronization. Save explicitly at accounting checkpoints and handle persistence failures visibly.
- Use a repository boundary around persistence so the engine can run against an in-memory store for validation.

The hourly detail shown in the prototype will require hourly aggregate data in the native implementation. Its schema and retention must be reconciled with the SRS's current daily-only persisted-data rule before implementation. Do not introduce raw browsing-event history to reproduce that chart.

## Native interface

Use `MenuBarExtra` as the starting point for the menu bar application and evaluate its window-style presentation against the approved popover. Add AppKit presentation support if required by behavior that SwiftUI alone does not cover.

Adopt system Liquid Glass for supported controls and navigation. Keep the content layer readable, and use a compatible material fallback on older supported macOS versions. The CSS material and 2× capture mode belong to the web prototype and documentation only.

The foundation targets macOS 14 to accommodate the planned SwiftData layer. Only Apple Silicon/macOS 27.2 has been exercised; the minimum-version and Intel validation gates remain open. The minimal shell uses system presentation; explicit Liquid Glass treatment and accessibility review belong to Task 4.

## Validation and release gates

| Area | Required evidence before implementation/release |
| --- | --- |
| Browser support | Active hostname, tab changes, focused window, and private-window exclusion verified in the selected Safari/Chrome versions. |
| Native lifecycle | Foreground, idle, sleep, lock, restart, and permission-loss behavior verified on the proposed minimum macOS version. |
| Local bridge | Message validation, extension identity restrictions, reconnection, stale-state handling, and app-launch behavior demonstrated. |
| Accounting | Deterministic checks for no double counting, domain boundaries, idle cutoff, midnight, clock changes, and Daily/Weekly consistency. |
| Persistence | Restart, retention, deletion, checkpoint recovery, and write-failure behavior validated. Resolve hourly aggregates before storing additional detail. |
| Interface | Native popover behavior, accessible labels, keyboard navigation, appearance changes, and material fallbacks reviewed. |
| Packaging | Code signing, notarization, extension installation, and native host registration work on a clean test installation. |

Safari and Chrome are initial targets, not a published support guarantee. Extension permissions, exact browser versions, local IPC, distribution channel, and the macOS support matrix remain discovery decisions.

## Implementation sequence

The [implementation tracker](IMPLEMENTATION.md) is the source of truth for delivery order and progress. It divides the native app into five tasks: foundation/browser feasibility, tracking engine, storage/summaries, native UI/integration, and release validation/packaging. Each task includes completion criteria and session handoff notes.

## Primary references

- [SwiftUI MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [SwiftUI glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [Apple Human Interface Guidelines: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Messaging between a Safari Web Extension and its app](https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension)
- [Chrome native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)
- [Persisting model data with SwiftData](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)
- [App activation notifications](https://developer.apple.com/documentation/appkit/nsworkspace/didactivateapplicationnotification)

See the [SRS](SRS.md) for product requirements and the [development guide](DEVELOPMENT.md) to run the current prototype.
