# README media

These assets show SurfMeter’s interactive browser prototype using sample activity. They are not recordings of a finished native macOS app or live browsing data.

## Assets

- `cover-2x.png`: 2800 × 1880 typeset cover with an unscaled screenshot of Daily.
- `daily-2x.png`, `yesterday-2x.png`, `weekly-2x.png`, `daily-dark-2x.png`, `preferences-dark-2x.png`: 900 × 1800 screenshots focused on the popover and its menu bar context.
- `activity-tour-2x.gif`: a 12-second loop through Daily, Yesterday, Weekly, and weekly platform detail.
- `appearance-tour-2x.gif`: a 6-second loop through the light and dark Daily views.

The GIFs hold each captured state for three seconds; they are UI state walkthroughs, not continuous screen recordings. Static images are linked in the main README for readers who prefer no animation. Both GIFs loop indefinitely. They retain the full 2× capture resolution and use error-diffusion dithering to reduce visible banding within the GIF format’s 256-color limit.

## Rebuild

Start the prototype using the development guide. At a 1280-pixel browser viewport width, open `http://127.0.0.1:5173/?capture=retina` and capture full-page screenshots of these states, in this order, as JPEG files in a temporary directory:

1. `01-daily.jpg`: light appearance, Daily, today.
2. `02-yesterday.jpg`: light appearance, Yesterday selected.
3. `03-weekly.jpg`: light appearance, Weekly.
4. `04-detail.jpg`: YouTube selected from Weekly.
5. `05-daily-dark.jpg`: dark appearance, Daily, today.
6. `06-preferences-dark.jpg`: dark appearance, Preferences.

Use the original sample data with tracking unpaused. Keep the page at its top before capturing. The capture-only query renders the same 1280-pixel layout at 2×, so full-page images must be 2560 pixels wide. It does not enlarge an existing screenshot. The crop in the script assumes the current layout at that width; adjust it if the layout changes. The normal preview does not use this capture styling.

```sh
python3 scripts/build-readme-media.py /path/to/captures
```

The script uses FFmpeg to crop the UI, compose the cover, and create palette-optimized GIFs. It does not upscale screenshots. On macOS, the cover uses the system Arial font. Captures supplied by the browser tool are JPEG; the 2× render gives text and icons twice as many pixels in each dimension, and derived PNG files preserve those captured pixels without further JPEG compression.

Review the output visually after rebuilding and check that the interface, labels, and complete popover remain visible. Generated files are committed so GitHub can display them without a separate hosting service.
