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
                    model.changePreferences { $0.appearance = dark ? "dark" : "light" }
                    let view = DashboardView(model: model, weekly: weekly, yesterday: yesterday, platform: platform, opaqueBackground: true)
                        .modifier(SurfAppearance(mode: model.preferences.appearance))
                    try capture(view, size: NSSize(width: 390, height: screen == .activity ? (platform != nil ? 620 : weekly ? 766 : 746) : 690), dark: dark,
                                destination: directory.appendingPathComponent("native-\(name)-\(dark ? "dark" : "light")@2x.png"))
                }
            }
            // Full native content avoids hiding setup controls below the popover's scroll fold.
            // Demo model only: no normal preferences, browser registration, or activity are touched.
            model.changePreferences { $0.enabled = false; $0.paused = false; $0.appearance = "light" }
            for (name, view) in [
                ("setup-content", AnyView(BrowserSetupView(model: model))),
                ("preferences-content", AnyView(PreferencesView(model: model)))
            ] {
                let content = view.padding(22).frame(width: 390).fixedSize(horizontal: false, vertical: true)
                    .background(SurfPalette(dark: false).solid)
                    .environment(\.colorScheme, .light)
                try capture(content, dark: false, destination: directory.appendingPathComponent("native-\(name)-light@2x.png"))
            }
            print("Rendered native SwiftUI previews with sample data at 2× scale.")
        } catch {
            FileHandle.standardError.write(Data("Native preview rendering failed.\n".utf8)); exit(1)
        }
    }
    static func verifyAppearance(model: AppModel) {
        let probe = AppearanceProbe()
        // ObservedObject ensures the modifier is recomputed with preferences.
        let host = NSHostingView(rootView: AppearanceTestRoot(model: model, probe: probe))
        let panel = NSPanel(contentRect: NSRect(x: -10000, y: -10000, width: 390, height: 690), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.contentView = host; panel.orderFrontRegardless()
        model.screen = .preferences
        for mode in ["light", "dark", "light", "dark", "system"] {
            model.changePreferences { $0.appearance = mode }
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            let expected: NSAppearance.Name = mode == "system" ? NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])! : mode == "dark" ? .darkAqua : .aqua
            guard panel.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expected,
                  (probe.scheme == .dark) == (expected == .darkAqua),
                  model.screen == .preferences else {
                fputs("Appearance transition failed: \(mode)\n", stderr); exit(1)
            }
            print("PASS same open panel: \(mode), AppKit + SwiftUI agree")
        }
        panel.orderOut(nil)
    }
    private static func capture<V: View>(_ view: V, size: NSSize? = nil, dark: Bool, destination: URL) throws {
        let host = NSHostingView(rootView: view)
        let measured = size ?? host.fittingSize
        let fitted = NSSize(width: measured.width, height: ceil(measured.height))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: fitted), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        host.displayIfNeeded()
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(fitted.width * 2), pixelsHigh: Int(fitted.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { throw NSError(domain: "PreviewExport", code: 1) }
        bitmap.size = fitted
        host.cacheDisplay(in: host.bounds, to: bitmap)
        window.orderOut(nil)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "PreviewExport", code: 2) }
        try data.write(to: destination)
    }

}

@MainActor private final class AppearanceProbe { var scheme: ColorScheme? }
private struct SchemeProbe: NSViewRepresentable {
    let probe: AppearanceProbe
    @Environment(\.colorScheme) var scheme
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) { probe.scheme = scheme }
}
private struct AppearanceTestRoot: View {
    @ObservedObject var model: AppModel
    let probe: AppearanceProbe
    var body: some View {
        DashboardView(model: model, opaqueBackground: true)
            .background(SchemeProbe(probe: probe))
            .modifier(SurfAppearance(mode: model.preferences.appearance))
    }
}
