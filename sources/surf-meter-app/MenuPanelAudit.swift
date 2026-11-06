import AppKit
import SwiftUI

/// Capture the entire AppKit frame, including any backing outside SwiftUI's clip.
@MainActor enum MenuPanelAudit {
    static func verify(directory: URL) {
        _ = NSApplication.shared
        func check(_ value: @autoclosure () -> Bool, _ name: String) {
            guard value() else { fputs("FAIL: \(name)\n", stderr); exit(1) }
            print("PASS: \(name)")
        }
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { fputs("Could not create audit output.\n", stderr); exit(1) }
        for (name, visible, anchor) in [
            ("right edge", NSRect(x: 0,y: 50,width: 1440,height: 820), NSRect(x: 1410,y: 870,width: 24,height: 24)),
            ("left edge", NSRect(x: 0,y: 50,width: 1440,height: 820), NSRect(x: 2,y: 870,width: 24,height: 24)),
            ("short display", NSRect(x: 0,y: 40,width: 1280,height: 660), NSRect(x: 900,y: 700,width: 24,height: 24)),
            ("negative origin", NSRect(x: -1920,y: 0,width: 1920,height: 1050), NSRect(x: -30,y: 1050,width: 24,height: 24)),
            ("upper display", NSRect(x: 0,y: 950,width: 1440,height: 850), NSRect(x: 900,y: 1800,width: 24,height: 24))
        ] {
            for height: CGFloat in [690, 720, 746, 766] {
                let frame = MenuBarController.frame(anchor: anchor, visible: visible, desiredHeight: height)
                check(visible.contains(frame) && frame.maxY <= anchor.minY - 8 && frame.height <= height, "\(name), \(Int(height))pt stays inside display")
            }
        }
        let model = AppModel(demo: true)
        let layout = MenuPanelLayout()
        var measured = CGSize.zero
        let panel = MenuBarController.makePanel(size: NSSize(width: 390, height: 746))
        panel.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        let host = MenuHostingView(rootView: MenuPanelRoot(model: model, layout: layout))
        host.sizingOptions = [.intrinsicContentSize]
        host.onSize = { measured = $0 }
        check(host.acceptsFirstMouse(for: nil), "menu controls accept the first click before activation")
        panel.contentView = host
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }
        for dark in [false, true] {
            model.changePreferences { $0.appearance = dark ? "dark" : "light" }
            for (name, screen, expected) in [("daily", Screen.activity, 746.0), ("preferences", .preferences, 690.0), ("setup", .setup, 690.0)] {
                model.screen = screen
                panel.setContentSize(NSSize(width: 390, height: expected))
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.2))
                host.displayIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                check(abs(measured.height - expected) < 1, "\(name) reports its actual panel height")
                check(panel.styleMask == .borderless && !panel.isOpaque && panel.backgroundColor.alphaComponent == 0, "\(name) has no decorated or opaque outer window")
                guard let frame = host.superview else { fputs("Missing native frame view.\n", stderr); exit(1) }
                frame.layoutSubtreeIfNeeded()
                let size = frame.bounds.size
                check(abs(size.width-390) < 1 && abs(size.height-expected) < 1, "native frame has no extra container padding")
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width*2), pixelsHigh: Int(size.height*2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                bitmap.size = size
                frame.cacheDisplay(in: frame.bounds, to: bitmap)
                let w = bitmap.pixelsWide, h = bitmap.pixelsHigh
                for (x,y) in [(0,0),(w-1,0),(0,h-1),(w-1,h-1),(8,8),(w-9,8),(8,h-9),(w-9,h-9)] {
                    check((bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 1) < 0.05, "native frame corner \(x),\(y) is transparent")
                }
                check((bitmap.colorAt(x: w/2, y: 20)?.alphaComponent ?? 0) > 0.5, "panel interior still renders")
                let url = directory.appendingPathComponent("menu-frame-\(name)-\(dark ? "dark" : "light")-2x.png")
                try! bitmap.representation(using: .png, properties: [:])!.write(to: url)
            }
        }
        layout.maximumHeight = 540
        model.screen = .activity
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        check(abs(measured.height-540) < 1, "short-screen layout clamps height without dropping header/footer")
        print("Verified full native frame pixels and menu geometry, using sample data only.")
    }
}
