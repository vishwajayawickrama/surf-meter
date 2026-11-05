# Native interface previews

These are the native SwiftUI views hosted in AppKit, rendered at 828×1320 (2×) in light/dark appearance on 2026-11-06. All activity is explicitly labeled sample data. Transparency is disabled for reproducible captures; these images verify layout, not the appearance of live system glass or real browsing accuracy.

Regenerate after building:

```sh
.build/SurfMeter.app/Contents/MacOS/SurfMeter --render-previews /private/tmp/surfmeter-native-previews
cp /private/tmp/surfmeter-native-previews/*.png docs/media/native/
```

The exporter captures only its own view bitmaps, not desktop screenshots. Long content is scrollable in the real app; these captures show the visible viewport. The running app uses system materials, with native glass controls where available and an opaque fallback for reduced transparency/increased contrast.
