<div align="center">

# SurfMeter

### Your browsing. A little clearer.

A quiet place in your Mac’s menu bar for where your time goes.

[Try the Mac app](#try-the-native-development-build) · [Explore the prototype](#try-the-first-look) · [Screenshots](#a-closer-look) · [Roadmap](#whats-next)

</div>

![SurfMeter — a translucent menu bar dashboard showing daily website usage and changes from yesterday](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/cover-2x.png)

> **Native development build available.** SurfMeter now has a SwiftUI dashboard, Chrome tracking engine, and local aggregate storage. Real-browser accuracy/privacy certification, Safari, and signed distribution are still in progress. The original hero and GIFs show the interactive UI prototype; native previews below use labeled sample data.

## Know where the hours went

A few minutes on YouTube. A quick scroll through Instagram. Another Reddit tab. SurfMeter is being built to make those little moments visible, right where you can check them: your menu bar.

- **Today, at a glance.** See time per platform, with yesterday’s total beside it. Green means less time; red means more. Arrows make the change clear, too.
- **Yesterday, one click away.** A dedicated button inside Daily lets you revisit the full day without losing your place.
- **Your week, in perspective.** A seven-day chart, platform totals, and daily averages show the bigger picture. Today’s partial day is clearly labeled.
- **Look a little closer.** Open a platform to explore its hourly or daily breakdown. Details follow the period you’re viewing.
- **Make room for your preferences.** Explore light and dark appearances, pause/resume, and website exclusions in the preview.

## Take a look around

<p align="center">
  <img src="https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/activity-tour-2x.gif" alt="Animated prototype walkthrough cycling through Daily, Yesterday, Weekly, and YouTube’s weekly detail" width="45%">
  &nbsp;
  <img src="https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/appearance-tour-2x.gif" alt="Animated comparison of SurfMeter’s light and dark appearances" width="45%">
</p>

*Activity walkthrough (left) · Light and dark appearances (right). Rendered at 2× resolution using sample data. Prefer still images? Open the screenshots below.*

## A closer look

<details>
<summary><strong>Open the screenshot gallery</strong></summary>
<br>

| Daily | Weekly |
| :---: | :---: |
| [![Daily usage with a Yesterday button and platform comparisons](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/daily-2x.png)](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/daily-2x.png) | [![Seven-day usage chart, platform totals, and daily averages](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/weekly-2x.png)](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/weekly-2x.png) |

| Yesterday | Dark preferences |
| :---: | :---: |
| [![Yesterday’s full-day browsing totals](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/yesterday-2x.png)](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/yesterday-2x.png) | [![SurfMeter preferences in dark appearance](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/preferences-dark-2x.png)](https://raw.githubusercontent.com/vishwajayawickrama/surf-meter/main/docs/media/preferences-dark-2x.png) |

Click any screenshot to view it at full size.

</details>

## Made for a quieter kind of awareness

The visual direction takes inspiration from Apple’s Liquid Glass: a floating translucent panel, softly lit edges, and simple controls that leave the numbers easy to read. The preview includes light and dark appearances, keyboard navigation, and CSS fallbacks for reduced transparency, increased contrast, and reduced motion.

The planned native app puts privacy at the center: active-tab timing, local storage, private-window exclusions, and no account required. These are implementation requirements, not claims of tracking functionality in this first look.

## Try the native development build

Build the Chrome extension, then the Mac app:

```sh
cd extensions/chrome
npm ci
npm run build
cd ../..
./scripts/build-native.sh
open .build/SurfMeter.app
```

Requires macOS 14+, Swift 6, and Node/npm to build. Open **Browser setup** in the app, load its bundled Chrome extension, paste the extension ID, connect, and enable recording. Safari is not enabled yet. See the [complete setup guide](docs/DEVELOPMENT.md) and [tested capabilities and remaining gates](docs/VALIDATION.md).

The native app includes Daily/Weekly views, Yesterday, website details, green/red comparisons, pause/resume, exclusions, retention, confirmed deletion, and appearance preferences. Activity stays in a local aggregate store; there is no backend or account. A self-contained, ad hoc signed development archive can be built with `./scripts/package-app.sh`; it is not a notarized release.

<p align="center">
  <img src="docs/media/native/native-daily-light@2x.png" alt="Native SwiftUI daily dashboard using labeled preview data" width="42%">
  &nbsp;
  <img src="docs/media/native/native-weekly-dark@2x.png" alt="Native SwiftUI weekly dashboard in dark appearance using labeled preview data" width="42%">
</p>

*Native SwiftUI previews at 2× resolution. Sample activity, with transparency disabled for reproducible captures. Live system materials appear in the running Mac app.*

## Try the first look

You only need Python 3 and a browser. No packages, account, or build step.

```sh
git clone https://github.com/vishwajayawickrama/surf-meter.git
cd surf-meter
python3 -m http.server 5173 --bind 127.0.0.1 --directory prototype
```

Open **[localhost:5173](http://127.0.0.1:5173/)** and click around. Start with Daily, try Yesterday, then switch to Weekly. The left navigation opens Preferences and Browser setup; **Reset demo** restores the original sample data.

The browser connections, activity, and system settings are simulated. Preview preferences are stored in your browser’s local storage. The desktop frame and left navigation are design-review tools around the planned menu bar interface.

## What’s next

Try the [native development build](docs/DEVELOPMENT.md#native-foundation), or read the [current validation results](docs/FOUNDATION-VALIDATION.md). The native app now includes accounting, persistence, and the dashboard. Original marketing GIFs remain the web prototype; the native previews are labeled separately.

Native implementation is organized into [five tasks](docs/IMPLEMENTATION.md), with completion criteria and handoff notes for work across sessions.

- [ ] Native foundation and browser feasibility
- [ ] Accurate activity tracking engine
- [ ] Local storage and usage summaries
- [ ] Native UI and complete app integration
- [ ] Validation, packaging, and first release

Want to shape the next iteration? [Open an issue](https://github.com/vishwajayawickrama/surf-meter/issues) with feedback on the interface or how you’d use SurfMeter.

---

[Implementation](docs/IMPLEMENTATION.md) · [Requirements](docs/SRS.md) · [Technology stack and architecture](docs/ARCHITECTURE.md) · [Development guide](docs/DEVELOPMENT.md) · [Media and capture notes](docs/media/README.md)
