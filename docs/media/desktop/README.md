# Desktop and first-run screenshots

These are native SwiftUI/AppKit renders at 2× resolution, with labeled sample activity. No actual browsing history is shown. Daily/Weekly desktop images are 2200 × 1560 pixels; walkthrough images are 1160 × 1300 pixels. Light and dark variants are included. Refreshed from source revision `127abbd` on 2026-11-06, including the continuous Finder-style sidebar and selected date shortcuts. Calendar layouts are 672 × 860 pixels.

Regenerate from the current built app:

```sh
.build/SurfMeter.app/Contents/MacOS/SurfMeter --render-previews /private/tmp/surfmeter-previews
cp /private/tmp/surfmeter-previews/desktop-*-2x.png docs/media/desktop/
cp /private/tmp/surfmeter-previews/onboarding-*-2x.png docs/media/desktop/
```

The screenshots are layout captures, not evidence of a connected browser. The live app uses system materials. The offline DMG guide uses the light walkthrough images; packaging uses the checked-in images after visual review.

Calendar previews use `--render-calendar` with the same output directory. Offscreen renders omit parts of the live glass compositor and native window chrome; use the running app to inspect those effects. The published Alpha 1 DMG may show an earlier UI.
