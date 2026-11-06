import SwiftUI
import AppKit
import SurfMeterCore

@MainActor
enum PreviewExport {
    static func renderSiteIcons(directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for dark in [false, true] {
                try capture(SiteIconGallery(dark: dark).environment(\.colorScheme, dark ? .dark : .light),
                            size: NSSize(width: 1050, height: 840), dark: dark,
                            destination: directory.appendingPathComponent("site-icons-\(dark ? "dark" : "light")-2x.png"))
            }
            print("Rendered bundled website icon galleries at 2× scale.")
        } catch { fputs("Icon rendering failed: \(error)\n", stderr); exit(1) }
    }
    static func render(model: AppModel, directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for dark in [false, true] {
                model.changePreferences { $0.appearance = dark ? "dark" : "light" }
                for weekly in [false, true] {
                    try capture(DesktopView(model: model, weekly: weekly).modifier(SurfAppearance(mode: model.preferences.appearance)), size: NSSize(width: 1100, height: 780), dark: dark,
                                destination: directory.appendingPathComponent("desktop-\(weekly ? "weekly" : "daily")-\(dark ? "dark" : "light")-2x.png"))
                }
                for step in 0..<4 {
                    try capture(OnboardingView(model: model, finish: {}, step: step).modifier(SurfAppearance(mode: model.preferences.appearance)), size: NSSize(width: 580, height: 650), dark: dark,
                                destination: directory.appendingPathComponent("onboarding-\(step + 1)-\(dark ? "dark" : "light")-2x.png"))
                }
            }
            for (name, weekly, yesterday, platform, screen) in [
                ("daily", false, false, nil as String?, Screen.activity),
                ("yesterday", false, true, nil, .activity),
                ("weekly", true, false, nil, .activity),
                ("detail", false, false, "youtube.com", .activity),
                ("detail-weekly", true, false, "youtube.com", .activity),
                ("detail-yesterday", false, true, "youtube.com", .activity),
                ("preferences", false, false, nil, .preferences),
                ("setup", false, false, nil, .setup)
            ] {
                model.screen = screen
                for dark in [false, true] {
                    model.changePreferences { $0.appearance = dark ? "dark" : "light" }
                    let view = DashboardView(model: model, weekly: weekly, yesterday: yesterday, platform: platform, opaqueBackground: true)
                        .modifier(SurfAppearance(mode: model.preferences.appearance))
                    try capture(view, size: NSSize(width: 390, height: screen == .activity ? (platform != nil ? 720 : weekly ? 766 : 746) : 690), dark: dark,
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
    static func renderAudit(model: AppModel, directory: URL) {
        precondition(model.demo)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, current, previous, known) in [
                ("empty", 0.0, 0.0, false), ("missing-yesterday", 61, 0, false),
                ("lower", 60, 120, true), ("equal", 120, 120, true),
                ("higher", 180, 120, true), ("zero-yesterday", 60, 0, true),
                ("yesterday-only", 0, 120, true), ("subminute", 0.5, 1, true)
            ] {
                var ledger = UsageLedger()
                ledger.add([.init(key: .init(day: model.today, hour: 9, platform: "youtube.com"), seconds: current), .init(key: .init(day: model.yesterday, hour: 10, platform: "youtube.com"), seconds: previous)])
                if known { ledger.mark(day: model.yesterday, reason: "recorded") }
                else if name == "missing-yesterday" { ledger.mark(day: model.yesterday, reason: "partial") }
                model.replacePreviewActivity(ledger)
                for dark in [false, true] {
                    model.changePreferences { $0.appearance = dark ? "dark" : "light"; $0.enabled = name != "empty" }
                    let view = DashboardView(model: model, opaqueBackground: true).modifier(SurfAppearance(mode: model.preferences.appearance))
                    try capture(view, size: NSSize(width: 390, height: 746), dark: dark, destination: directory.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
                }
            }
            let firstRunDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("surfmeter-first-run-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: firstRunDirectory) }
            let fresh = AppModel(verificationDirectory: firstRunDirectory, startsServices: false)
            for dark in [false, true] {
                fresh.changePreferences { $0.appearance = dark ? "dark" : "light" }
                let view = DashboardView(model: fresh, opaqueBackground: true).modifier(SurfAppearance(mode: fresh.preferences.appearance))
                try capture(view, size: NSSize(width: 390, height: 746), dark: dark, destination: directory.appendingPathComponent("first-run-\(dark ? "dark" : "light").png"))
            }
            print("Rendered 16 edge-case fixture screens and 2 genuine isolated first-run screens.")
        } catch { fputs("Audit rendering failed: \(error)\n", stderr); exit(1) }
    }
    static func verifyAppearance(model: AppModel) {
        let probe = AppearanceProbe()
        // ObservedObject ensures the modifier is recomputed with preferences.
        let host = NSHostingView(rootView: AppearanceTestRoot(model: model, probe: probe))
        let panel = NSPanel(contentRect: NSRect(x: -10000, y: -10000, width: 390, height: 690), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.contentView = host; panel.orderFrontRegardless()
        model.screen = .preferences
        let originalAppearance = NSApp.appearance
        defer { NSApp.appearance = originalAppearance }
        for (mode, systemDark) in [("light", true), ("dark", false), ("light", false), ("dark", true), ("system", true), ("system", false)] {
            NSApp.appearance = NSAppearance(named: systemDark ? .darkAqua : .aqua)
            model.changePreferences { $0.appearance = mode }
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            let expected: NSAppearance.Name = mode == "system" ? NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])! : mode == "dark" ? .darkAqua : .aqua
            guard panel.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == expected,
                  (probe.scheme == .dark) == (expected == .darkAqua),
                  model.screen == .preferences,
                  !panel.isOpaque,
                  panel.backgroundColor.alphaComponent == 0,
                  panel.contentView?.layer?.masksToBounds == true,
                  panel.contentView?.layer?.cornerRadius == MenuPanelSurface.cornerRadius,
                  panel.contentView?.layer?.cornerCurve == .continuous else {
                fputs("Appearance transition failed: \(mode)\n", stderr); exit(1)
            }
            print("PASS same open panel: \(mode), simulated system \(systemDark ? "dark" : "light"), AppKit + SwiftUI agree; native backing transparent and corners clipped")
        }
        panel.orderOut(nil)
        let desktop = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 1100, height: 780), styleMask: [.titled], backing: .buffered, defer: false)
        let wasOpaque = desktop.isOpaque
        let background = desktop.backgroundColor
        desktop.contentView = NSHostingView(rootView: DesktopRoot(model: model))
        desktop.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        guard desktop.isOpaque == wasOpaque, desktop.backgroundColor == background,
              desktop.contentView?.layer?.masksToBounds != true else {
            fputs("Menu surface styling leaked into desktop window.\n", stderr); exit(1)
        }
        print("PASS: desktop retains its native backing; menu corner policy is scoped")
        desktop.orderOut(nil)
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
