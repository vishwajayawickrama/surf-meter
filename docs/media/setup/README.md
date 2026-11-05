# Annotated setup screenshots

Used by [the setup guide](../../SETUP.md). Eight figures are supplied as readable 2× PNG exports and self-contained SVGs. The SVGs embed their source PNGs, so annotations remain editable without broken image references.

## What the images show

- **01 and 07:** actual AppKit-hosted SurfMeter SwiftUI views from `../native`, with explicitly labeled sample activity. These are UI layout renders, not proof of real Chrome recording.
- **03 and 05:** actual `BrowserSetupView` content rendered in full, then shown in two cropped regions so controls below the popover's scroll fold are visible. Recording is off and the connection is waiting. The preview model deliberately disables side-effecting buttons.
- **06:** full native `PreferencesView` content; preview login control is disabled.
- **02, 04, and 08:** Google's Chrome tutorial screenshots. Their example extension is **Hello Extensions**, not SurfMeter. The guide and callouts tell readers to use their own SurfMeter card/ID. Chrome UI can differ by version.

The native sources were rendered on 2026-11-06 with opaque backgrounds for reproducibility. No desktop, private browser tabs, personal account UI, live browsing activity, or fabricated connected state appears in the figures. Recording, login settings, browser permissions, and the user's normal database were not changed to produce them.

## Source attribution

Google, **Chrome for Developers — Hello World extension**. [Tutorial](https://developer.chrome.com/docs/extensions/get-started/tutorial/hello-world). The page licenses its content under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/), except where otherwise noted. Retain this attribution when reusing the annotated figures.

| Local source | Original asset |
| --- | --- |
| `sources/chrome-extensions.png` | [Extensions page](https://developer.chrome.com/static/docs/extensions/get-started/tutorial/hello-world/image/extensions-page-e0d64d89a6acf.png) |
| `sources/chrome-pin.png` | [Pinning the extension](https://developer.chrome.com/static/docs/extensions/get-started/tutorial/hello-world/image/pinning-extension-215cb97773ab6.png) |
| `sources/chrome-reload.png` | [Reload an extension](https://developer.chrome.com/static/docs/extensions/get-started/tutorial/hello-world/image/reload-extension-241cc5378fffb.png) |

**Changes:** screenshot placement/scaling, numbered highlights, explanatory callouts, titles, and source labels were added in a separate vector layout. Some native source borders/regions are cropped for presentation. Original screenshots are preserved; example names and IDs were not replaced to imitate a live SurfMeter installation. Original Chrome screenshots already contain Google's green/orange highlights. Exporting the figure at 2× does not add detail beyond each source image's original resolution.

## Regenerate

From the repository root on macOS:

```sh
./scripts/build-native.sh
.build/SurfMeter.app/Contents/MacOS/SurfMeter --render-previews /private/tmp/surfmeter-setup-sources
cp /private/tmp/surfmeter-setup-sources/native-setup-content-light@2x.png docs/media/setup/sources/
cp /private/tmp/surfmeter-setup-sources/native-preferences-content-light@2x.png docs/media/setup/sources/
swift -module-cache-path /private/tmp/surfmeter-swift-cache scripts/render-setup-guide.swift
```

The first command expects the extension build prerequisites described in [Development](../../DEVELOPMENT.md). The native exporter uses an isolated demo model; it does not connect a browser, enable login, delete records, or access the normal activity store. It now emits full setup/preferences content in addition to the existing popover previews.

`annotations.json` defines the source, display width, optional pixel crop, and numbered rectangle/title/explanation for each figure. Coordinates use original source pixels, including for cropped figures. The Swift renderer validates crop and annotation bounds, writes PNG/SVG pairs, and preserves the original screenshot pixels in the SVG.

When UI layout changes, refresh the source renders and adjust annotation rectangles. Review every generated PNG for correct targets, unobscured labels, readable text, and clipping. Verify all guide links after moving/renaming images. No native activity engine or browser functionality test is needed for annotation-only changes.
