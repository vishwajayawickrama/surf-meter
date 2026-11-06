# Desktop and first-run screenshots

These are native SwiftUI/AppKit renders at 2× resolution, with labeled sample activity. No actual browsing history is shown. Daily/Weekly desktop images are 2200 × 1560 pixels; walkthrough images are 1160 × 1300 pixels. Light and dark variants are included.

Regenerate from the current built app:

```sh
.build/SurfMeter.app/Contents/MacOS/SurfMeter --render-previews /private/tmp/surfmeter-previews
cp /private/tmp/surfmeter-previews/desktop-*-2x.png docs/media/desktop/
cp /private/tmp/surfmeter-previews/onboarding-*-2x.png docs/media/desktop/
```

The screenshots are layout captures, not evidence of a connected browser. The live app uses system materials. The offline DMG guide uses the light walkthrough images; packaging uses the checked-in images after visual review.
