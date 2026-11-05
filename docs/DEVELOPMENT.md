# Developing SurfMeter

A planned macOS menu bar app that tracks active browser time by website or platform and compares today's usage with yesterday's.

## Project status

Requirements and interactive UI prototype. Browser tracking is not implemented yet.

See the [Software Requirements Specification](SRS.md) for the proposed MVP, tracking rules, privacy requirements, and acceptance criteria.

## Native implementation direction

The proposed production stack is **Swift + SwiftUI**, `MenuBarExtra`, native Liquid Glass materials, **TypeScript browser extensions**, browser native messaging, and **local SwiftData persistence**. Xcode and Swift Package Manager will support the native app and helper targets. The MVP does not require a backend or account.

See [Technology stack and architecture](ARCHITECTURE.md) for the component flow, browser-specific adapters, tracking engine, storage boundaries, and integration decisions still to validate. These technologies describe the intended native app; the runnable repository currently contains the web prototype below.

Follow the [five-task implementation tracker](IMPLEMENTATION.md) for delivery order, completion criteria, current progress, and handoff notes between sessions. Start with Task 1; native implementation has not started yet.

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
