import AppKit
import SwiftUI

/// The desktop and status panel share one model, lease, bridge and store.
@MainActor final class DesktopController: NSObject, NSWindowDelegate {
    static let shared = DesktopController()
    private var window: NSWindow?
    private weak var model: AppModel?

    func configure(model: AppModel) { self.model = model }
    func show(model: AppModel? = nil) {
        guard let model = model ?? self.model else { return }
        MenuBarController.shared.hide()
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 780),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "SurfMeter"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 900, height: 680)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: DesktopRoot(model: model))
            window.center()
            self.window = window
        }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) {
        model?.checkpoint()
        NSApp.setActivationPolicy(.accessory)
    }
}

@MainActor final class SurfMeterDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        MenuBarController.shared.start()
        guard !args.contains("--menu-audit"), !args.contains("--bridge-directory"), !args.contains("--background") else { return }
        // Login and native-host launches stay quiet. A normal Finder launch opens the app.
        let login = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem))?.booleanValue ?? false
        if !login { DesktopController.shared.show() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DesktopController.shared.show()
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct DesktopRoot: View {
    @ObservedObject var model: AppModel
    var body: some View { DesktopView(model: model).modifier(SurfAppearance(mode: model.preferences.appearance)) }
}
