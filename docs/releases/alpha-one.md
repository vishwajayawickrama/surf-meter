# SurfMeter 0.1.1 — Alpha 1

Release: `v0.1.1-alpha.1` · Apple Silicon · macOS development prerelease

SurfMeter opens as a full Mac app alongside its menu bar panel.

- Daily and Weekly views with date browsing, a dedicated Yesterday button, larger charts, website search, and per-platform chart selection.
- Shared activity and preferences across the window and menu panel. Closing the window keeps the menu bar app running.
- A revisitable four-step first-run walkthrough for installation, Chrome connection, recording consent, login behavior and appearance.
- A self-contained DMG with the app, bundled Chrome extension/native helper, and an offline illustrated installation guide. No Swift, Xcode, Node, npm or Python needed to run it.

### Install

Download the arm64 DMG and its SHA-256 checksum below. Open the image, drag SurfMeter to Applications, eject the image and launch the installed app. Follow the walkthrough to load the bundled Chrome extension, register its extension ID and explicitly enable recording. Quit an older copy before replacing it; existing history and preferences are retained.

[Installation and walkthrough](https://github.com/vishwajayawickrama/surf-meter/blob/main/docs/distribution.md) · [Annotated setup guide](https://github.com/vishwajayawickrama/surf-meter/blob/main/docs/setup.md)

### Development prerelease limitations

**Apple Silicon only. Ad hoc signed and not notarized.** macOS may block this build under Gatekeeper. Verify the source and follow Apple's guidance linked in the installation guide; do not disable system protections globally. Developer ID signing/notarization is still pending. macOS 14 is the deployment target, not a tested minimum-OS guarantee.

Chrome setup remains manual. Safari recording is unavailable. Real-browser accuracy/privacy, other OS/architecture combinations and a separate clean Mac remain release gates. Known CPU and charged-memory issues from the earlier build are documented in [Resource measurements](https://github.com/vishwajayawickrama/surf-meter/blob/main/docs/performance.md); this desktop build has not received a new 30-minute benchmark.

### Validation

Passed 21 core tests, three extension tests, nine resource-tooling tests, app/helper protocol and synthetic recording/recovery checks, 25 isolated model assertions, and six appearance transitions. Native desktop/walkthrough interactions were checked using sample data. The optimized DMG was verified and mounted read-only to check the signature, resources, guide and absence of local activity/configuration files.
