# Architecture diagrams

`components.png` is the main component architecture embedded in [ARCHITECTURE.md](../ARCHITECTURE.md). It is rendered at **2560 × 2880** so labels stay sharp on high-density displays. `components.svg` is the matching vector image for zooming and editing.

The diagram shows the proposed native app, not the existing HTML/CSS/JavaScript prototype. Browser integrations, local IPC, permissions, and platform support remain subject to Task 1 in the [implementation tracker](../IMPLEMENTATION.md).

## Regenerate

From the repository root on macOS with the Swift toolchain installed:

```sh
swift -module-cache-path /private/tmp/surfmeter-swift-cache scripts/render-architecture.swift
```

The renderer uses AppKit, CoreGraphics, and CoreText; it has no third-party dependencies. Layout, labels, colors, and arrows are defined in `scripts/render-architecture.swift`. Both PNG and SVG are generated from the same drawing commands. The PNG is drawn at 2× resolution rather than enlarged from an existing bitmap.

After changing the architecture, update the renderer, regenerate both files, and inspect the PNG for label clipping, arrow overlaps, and readability. Commit the renderer and generated assets together.
