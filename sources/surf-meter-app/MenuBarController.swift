import AppKit
import Combine
import SwiftUI

/// Own the entire borderless window: MenuBarExtra's decorated frame can leave
/// native glass outside the custom rounded surface on newer macOS versions.
@MainActor final class MenuBarController: NSObject {
    static let shared = MenuBarController()
    private var model: AppModel?
    private var item: NSStatusItem?
    private var panel: MenuGlassPanel?
    private var host: MenuHostingView?
    private var changes: AnyCancellable?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var refreshPending = false
    private var desiredHeight: CGFloat = 746
    private var lastSymbol: String?
    private let layout = MenuPanelLayout()

    func configure(model: AppModel) { self.model = model }
    func start() {
        guard item == nil, let model else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.item = item
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateLabel()
        changes = model.objectWillChange.sink { [weak self] in
            // Published changes arrive before their values; coalesce on the next turn.
            guard let self, !self.refreshPending else { return }
            self.refreshPending = true
            DispatchQueue.main.async { [weak self] in
                self?.refreshPending = false
                self?.updateLabel()
            }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor in self?.hide() }
        }
    }
    private func updateLabel() {
        guard let model, let button = item?.button else { return }
        let title = " " + model.menuLabel
        if button.title != title { button.title = title }
        let symbol = model.preferences.paused ? "pause.circle" : "water.waves"
        if lastSymbol != symbol {
            lastSymbol = symbol
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "SurfMeter")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
        }
        button.setAccessibilityLabel("SurfMeter, today \(model.menuLabel)")
        button.toolTip = "SurfMeter · \(model.menuLabel)"
    }
    @objc private func togglePanel() {
        if NSApp.currentEvent?.type == .rightMouseUp { showContextMenu(); return }
        if panel?.isVisible == true { hide() } else { show() }
    }
    func show() {
        guard let model, let button = item?.button, let statusWindow = button.window else { return }
        guard let screen = statusWindow.screen ?? NSScreen.main else { return }
        let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let available = max(1, min(anchor.minY - 8, screen.visibleFrame.maxY - 8) - screen.visibleFrame.minY - 8)
        layout.maximumHeight = available
        if panel == nil {
            let panel = Self.makePanel(size: NSSize(width: 390, height: min(desiredHeight, available)))
            self.panel = panel
        }
        // Retain the hosting tree so Daily/Weekly and detail navigation survive dismissal.
        if host == nil {
            let host = MenuHostingView(rootView: MenuPanelRoot(model: model, layout: layout))
            host.sizingOptions = [.intrinsicContentSize]
            host.onSize = { [weak self] size in
                guard let self else { return }
                self.desiredHeight = size.height
                self.positionPanel()
            }
            self.host = host
            panel?.contentView = host
        }
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        installDismissalMonitors()
        if CommandLine.arguments.contains("--menu-audit") {
            print("Audit panel visible: \(panel?.isVisible == true), frame: \(String(describing: panel?.frame))")
            fflush(stdout)
        }
    }
    private func positionPanel() {
        guard let panel, let button = item?.button, let statusWindow = button.window,
              let screen = statusWindow.screen ?? NSScreen.main else { return }
        let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let frame = Self.frame(anchor: anchor, visible: screen.visibleFrame, desiredHeight: desiredHeight)
        if panel.frame != frame { panel.setFrame(frame, display: true); panel.invalidateShadow() }
    }
    static func makePanel(size: NSSize) -> MenuGlassPanel {
        let panel = MenuGlassPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.title = "SurfMeter menu"
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true
        return panel
    }
    static func frame(anchor: NSRect, visible: NSRect, desiredHeight: CGFloat) -> NSRect {
        let top = min(anchor.minY - 8, visible.maxY - 8)
        let height = min(desiredHeight, max(1, top - visible.minY - 8))
        let width = min(CGFloat(390), max(1, visible.width - 16))
        let x = min(max(anchor.midX - width / 2, visible.minX + 8), visible.maxX - width - 8)
        return NSRect(x: x, y: top - height, width: width, height: height)
    }
    func hide() {
        panel?.orderOut(nil)
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
    }
    private func installDismissalMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.hide(); return nil }
            } else if event.window !== self.panel && event.window !== self.item?.button?.window {
                self.hide()
            }
            return event
        }
    }
    private func showContextMenu() {
        guard let model, let button = item?.button else { return }
        hide()
        let menu = NSMenu()
        for (title, action) in [("Open SurfMeter", #selector(openDesktop)), (model.preferences.paused ? "Resume tracking" : "Pause tracking", #selector(pause)), ("Preferences…", #selector(preferences)), ("Quit SurfMeter", #selector(quit))] {
            let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            entry.target = self
            if action == #selector(pause) { entry.isEnabled = model.preferences.enabled }
        }
        menu.autoenablesItems = false
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }
    @objc private func openDesktop() { hide(); DesktopController.shared.show(model: model) }
    @objc private func pause() { model?.changePreferences { $0.paused.toggle() } }
    @objc private func preferences() { model?.screen = .preferences; show() }
    @objc private func quit() { model?.quit() }
}

final class MenuGlassPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { CommandLine.arguments.contains("--menu-audit") }
}

@MainActor final class MenuPanelLayout: ObservableObject {
    @Published var maximumHeight: CGFloat = 746
}
struct MenuPanelRoot: View {
    @ObservedObject var model: AppModel
    @ObservedObject var layout: MenuPanelLayout
    var body: some View {
        DashboardView(model: model, maximumHeight: layout.maximumHeight)
            .modifier(SurfAppearance(mode: model.preferences.appearance))
    }
}

/// Observe AppKit's intrinsic sizing directly; this also works outside a SwiftUI scene.
final class MenuHostingView: NSHostingView<MenuPanelRoot> {
    var onSize: ((CGSize) -> Void)?
    private var pending = false
    private var lastSize = CGSize.zero
    // A click should activate the control even when the panel wasn't key yet.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        scheduleSizeUpdate()
    }
    override func layout() { super.layout(); scheduleSizeUpdate() }
    private func scheduleSizeUpdate() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pending = false
            guard self.window != nil else { return }
            let size = self.fittingSize
            guard size.width > 0, size.height > 0, size != self.lastSize else { return }
            self.lastSize = size
            self.onSize?(size)
        }
    }
}
