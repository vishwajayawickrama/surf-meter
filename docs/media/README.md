# README media

Refreshed on 2026-11-06 from the native app at source revision `127abbd`. All activity is labeled sample data; no recorded browser history is used. These images show the current development UI, which can be newer than the published Alpha 1 DMG.

## Assets

- `cover-2x.png`: 2400 × 1880 cover containing the original 2200 × 1560 desktop render without upscaling.
- `daily-2x.png`, `yesterday-2x.png`, `weekly-2x.png`, `daily-dark-2x.png`: current 780 × 1532 native menu layouts.
- `preferences-dark-2x.png`: current 780 × 1380 preferences layout.
- `activity-tour-2x.gif`: Daily, Yesterday, Weekly and weekly platform detail; 12 seconds.
- `appearance-tour-2x.gif`: Daily in light and dark; six seconds.
- `desktop/`: current desktop, calendar and onboarding renders in both appearances.
- `native/`: current menu layouts; icon galleries are maintained separately.

The GIFs hold each state for three seconds and loop indefinitely. They are state tours, not continuous screen recordings. Frames retain the original 2× resolution; shorter detail views are padded, never stretched. GIF palette optimization uses error-diffusion dithering; linked PNG stills preserve full color.

These are AppKit/SwiftUI layout renders. Offscreen capture omits parts of the live Liquid Glass compositor and does not reproduce desktop-dependent translucency or native window chrome. View the running app for those effects. They are not evidence of connected-browser accuracy.

## Rebuild

Build the current app, then render in isolated sample mode and compose the media:

```sh
SURFMETER_BUILD_CONFIGURATION=release ./scripts/build-native.sh
.build/SurfMeter.app/Contents/MacOS/SurfMeter --render-previews /private/tmp/surfmeter-readme-current
.build/SurfMeter.app/Contents/MacOS/SurfMeter --render-calendar /private/tmp/surfmeter-readme-current
python3 scripts/build-readme-media.py /private/tmp/surfmeter-readme-current
cp /private/tmp/surfmeter-readme-current/calendar-*-2x.png docs/media/desktop/
```

The composition script requires FFmpeg and the macOS system Arial font. It replaces the README cover, menu stills, native/desktop/onboarding galleries and both GIFs. Calendar images are copied separately. Review output visually before committing. Historical audit evidence and annotated setup captures are kept separately and are not overwritten by this workflow.
