# Native interface previews

These are the native SwiftUI views hosted in AppKit, rendered at 2× with a 780-pixel (390-point) panel width and screen-specific heights in light/dark appearance on 2026-11-06. All activity is explicitly labeled sample data. Transparency is disabled for reproducible captures; these images verify layout, not the appearance of live system glass or real browsing accuracy.

Regenerate after building:

```sh
.build/SurfMeter.app/Contents/MacOS/SurfMeter --render-previews /private/tmp/surfmeter-native-previews
cp /private/tmp/surfmeter-native-previews/native-{daily,yesterday,weekly,detail,detail-weekly,detail-yesterday,preferences,setup}-{light,dark}@2x.png docs/media/native/
```

The exporter captures only its own view bitmaps, not desktop screenshots. Long content is scrollable in the real app; these captures show the visible viewport. The running app uses system materials, with window-scoped appearance overrides and an opaque fallback for reduced transparency/increased contrast.
