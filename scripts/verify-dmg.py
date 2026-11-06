#!/usr/bin/env python3
"""Read-only artifact inspection; never opens a user's activity store."""
import json
import pathlib
import plistlib
import subprocess
import sys
import tempfile

image = pathlib.Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix="surfmeter-dmg-check-") as temp:
    mount = pathlib.Path(temp) / "image"
    subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount), str(image)], check=True, stdout=subprocess.DEVNULL)
    try:
        app = mount / "SurfMeter.app"
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        assert info["CFBundleIdentifier"] == "dev.surfmeter.app"
        version = pathlib.Path("version.txt").read_text().strip()
        assert info["CFBundleShortVersionString"] == version.split("-")[0]
        assert info["SurfMeterReleaseVersion"] == version
        assert int(info["CFBundleVersion"]) > 0
        assert (mount / "Applications").is_symlink()
        assert (mount / "Applications").readlink() == pathlib.Path("/Applications")
        assert (mount / "Start Here.html").is_file()
        for step in range(1, 5):
            assert (mount / f"setup-images/onboarding-{step}-light-2x.png").is_file()
        assert (app / "Contents/Helpers/SurfMeterNativeHost").is_file()
        assert (app / "Contents/Resources/AppIcon.icns").is_file()
        brands = app / "Contents/Resources/SurfMeter_SurfMeterApp.bundle/Contents/Resources/site-icons/brands.json"
        assert len(json.loads(brands.read_text())) >= 48
        assert (brands.parent / "simple-icons-license.txt").is_file()
        assert (brands.parent / "font-awesome-license.txt").is_file()
        manifest = json.loads((app / "Contents/Resources/ChromeExtension/manifest.json").read_text())
        assert manifest["manifest_version"] == 3
        # Do not follow the Applications symlink when inspecting artifact files.
        files = list(app.rglob("*"))
        forbidden = {"host-config.json", "preferences.plist", "activity.sqlite", "bridge.sock", "activity.lock"}
        assert not any(p.name in forbidden or p.name.endswith((".sqlite-wal", ".sqlite-shm", ".dSYM")) for p in files)
        assert set(p.name for p in mount.iterdir()) <= {"SurfMeter.app", "Applications", "Start Here.html", "setup-images", "third-party-notices.md", ".fseventsd", ".Trashes", ".Spotlight-V100"}
        print("PASS: read-only DMG mount, bundle signature/version, Applications shortcut, offline guide, screenshots, icon, helper, Chrome extension; no activity database or local configuration")
    finally:
        subprocess.run(["hdiutil", "detach", str(mount)], check=True, stdout=subprocess.DEVNULL)
