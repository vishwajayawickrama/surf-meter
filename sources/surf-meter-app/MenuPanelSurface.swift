import AppKit
import SwiftUI

/// Scope the transparent backing to the menu panel. The desktop keeps its
/// standard window surface. Clipping SwiftUI alone leaves opaque native corners.
struct MenuPanelSurface: ViewModifier {
    static let cornerRadius: CGFloat = 26
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.containerBackground(.clear, for: .window)
                .background(MenuPanelWindow().frame(width: 0, height: 0))
        } else {
            content.background(MenuPanelWindow().frame(width: 0, height: 0))
        }
    }
}

private struct MenuPanelWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> SurfaceView { SurfaceView() }
    func updateNSView(_ view: SurfaceView, context: Context) { view.apply() }

    final class SurfaceView: NSView {
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        func apply() {
            guard let window, let content = window.contentView else { return }
            var changed = false
            if window.isOpaque { window.isOpaque = false; changed = true }
            if window.backgroundColor.alphaComponent != 0 { window.backgroundColor = .clear; changed = true }
            if !content.wantsLayer { content.wantsLayer = true }
            if let layer = content.layer,
               layer.cornerRadius != MenuPanelSurface.cornerRadius || layer.cornerCurve != .continuous || !layer.masksToBounds {
                layer.cornerRadius = MenuPanelSurface.cornerRadius
                layer.cornerCurve = .continuous
                layer.masksToBounds = true
                changed = true
            }
            // Timer-driven activity updates must not recalculate the shadow.
            if changed { window.invalidateShadow() }
        }
    }
}
