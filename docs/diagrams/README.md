# Architecture diagrams

The icon-led reference architecture (A) is the selected visual direction in [architecture.md](../architecture.md). B and C are retained as collapsed comparisons.

| Option | View | PNG size | Best use |
| --- | --- | --- | --- |
| A (selected) | Icon-led reference architecture | 2800 × 1640 | Quick overview of components and main information flow. |
| B | C4 component view | 2560 × 2120 | Technical documentation of the native app's components and interfaces. |
| C | Layered architecture | 2560 × 1960 | Understanding logical responsibilities and dependency direction. |

## Files

Each `architecture-a-reference`, `architecture-b-c4`, and `architecture-c-layered` variant has a `.png`, `.svg`, and `.drawio` file. `architecture-alternatives.drawio` contains all three variants as separate pages. Icons are embedded in the SVG and diagrams.net files; exported images do not need external icon hosting.

Open a `.drawio` file in diagrams.net or its desktop editor to edit the shapes, labels, icons, and routes. PNG/SVG exports are generated locally; the XML files are validated during review.

## Research and design conventions

- **Icon-led reference diagrams:** [AWS's published architecture conventions](https://github.com/aws/aws-networking-best-practices/blob/main/content/community/conventions.md) recommend short, centered labels below icons, a neutral background, consistent connectors, and keeping diagrams simple. Option A adopts these presentation principles for local Mac components; icons represent their actual browser or application role.
- **C4 component notation:** [C4 notation guidance](https://c4model.com/diagrams/notation) calls for a stated scope, a key, element types, responsibilities, technologies, and specific directed relationships. The [component-view guidance](https://c4model.com/diagrams/component) scopes the view to a single container, with supporting containers connected to its components. Option B follows that scope around the native app.
- **Layered responsibility view:** Option C groups UI, application logic, and platform/persistence adapters. Its solid arrows indicate calls/dependencies between layers; its dashed browser connections indicate incoming messages. It is deliberately not a process-deployment diagram.
- **Editable delivery:** [draw.io's architecture documentation](https://www.drawio.com/docs/diagram-types/aws-diagrams/) describes icon libraries, grouping, routing, and documentation exports. All three alternatives have editable source files alongside their image exports.

The comparison varies layout, notation, information density, and shape treatment rather than only changing colors. The browser/IPC integration remains subject to Task 1 in the [implementation tracker](../implementation.md).

## Regenerate

From the repository root on macOS with the Swift toolchain installed:

```sh
swift -module-cache-path /private/tmp/surfmeter-swift-cache scripts/render-architecture.swift
```

The renderer uses AppKit, CoreGraphics, and CoreText. It generates the PNGs at 2× resolution, vector SVGs with embedded icons, individual diagrams.net documents, and a three-page comparison document. The renderer defines the layout. Running it after manually editing a `.drawio` file will restore that defined layout; export PNG/SVG directly from your editor if you choose to maintain the editor file instead.

After regeneration, review each PNG at normal reading size for label collisions, routes crossing text, missing icons, and clipped content. Check the XML for all SVG/draw.io outputs. These are diagram/documentation checks, not validation of the future native app.

## Icon sources

- Safari application icon: Apple, extracted from the installed Safari app.
- Chrome application icon: Google, extracted from the installed Chrome app.
- Swift, extension, connector, CPU, monitor, window, and settings symbols: Apple's [SF Symbols](https://developer.apple.com/sf-symbols/), rendered at high resolution. The Swift symbol uses its recognizable orange treatment.
- Database cylinders use conventional diagram notation.

Cached icons are committed under `icons/`, so regeneration normally does not require Safari or Chrome to be installed. Rebuilding a missing browser icon requires the app in `/Applications`; rebuilding a missing system symbol requires the macOS symbol library. Browser marks remain those of their respective owners.


## Selected view: typography and icons

Option A uses [IBM Plex Sans](https://github.com/IBM/plex), with regular component labels and medium-weight large headings. The original font files and SIL Open Font License are in `fonts/`. Fonts are registered for the renderer process; the script does not install fonts into macOS. Its SVG embeds the required font faces, and its PNG already contains the rendered typography. For matching typography while manually editing the diagrams.net file, install the bundled regular/medium fonts locally or select them in an editor that supports font loading.

The selected view uses [Lucide](https://lucide.dev/) icons for application services:

| Role | Icon |
| --- | --- |
| Safari native handler | Application window |
| Chrome native host | Terminal window |
| Local IPC bridge | Left/right message exchange |
| Tracking engine | CPU |
| Preferences | Horizontal sliders |
| macOS state | Monitor |
| Menu bar UI | Window with a top panel |

Upstream SVGs and the Lucide license are in `icons/lucide/`. The renderer uses a neutral color and a 1.5-unit stroke for a consistent diagram scale. It renders the selected SVG primitives directly into PNG and preserves vector geometry in the SVG export. The browser icons and conventional database cylinder remain unchanged. B/C retain the earlier SF Symbols treatment for comparison.
