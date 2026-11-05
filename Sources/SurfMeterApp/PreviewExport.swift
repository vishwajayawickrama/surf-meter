import SwiftUI
import AppKit

@MainActor
enum PreviewExport {
    static func render(model: AppModel, directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, weekly, yesterday, platform, screen) in [
                ("daily", false, false, nil as String?, Screen.activity),
                ("yesterday", false, true, nil, .activity),
                ("weekly", true, false, nil, .activity),
                ("detail", false, false, "youtube.com", .activity),
                ("preferences", false, false, nil, .preferences),
                ("setup", false, false, nil, .setup)
            ] {
                model.screen = screen
                for dark in [false, true] {
                    let view = DashboardView(model: model, weekly: weekly, yesterday: yesterday, platform: platform, opaqueBackground: true)
                        .environment(\.colorScheme, dark ? .dark : .light)
                    let host = NSHostingView(rootView: view)
                    let size = NSSize(width: 414, height: 660)
                    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                    window.contentView = host
                    window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
                    window.orderFrontRegardless()
                    host.layoutSubtreeIfNeeded()
                    RunLoop.main.run(until: Date().addingTimeInterval(0.12))
                    host.displayIfNeeded()
                    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 828, pixelsHigh: 1320, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { throw NSError(domain: "PreviewExport", code: 1) }
                    bitmap.size = size
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    window.orderOut(nil)
                    guard let data = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "PreviewExport", code: 2) }
                    try data.write(to: directory.appendingPathComponent("native-\(name)-\(dark ? "dark" : "light")@2x.png"))
                }
            }
            print("Rendered native SwiftUI previews with sample data at 2× scale.")
        } catch {
            FileHandle.standardError.write(Data("Native preview rendering failed.\n".utf8)); exit(1)
        }
    }
}
