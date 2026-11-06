import SwiftUI
import AppKit

/// Scope appearance to each native window so an already-open panel updates
/// without changing the system appearance of the menu-bar status item.
struct SurfAppearance: ViewModifier {
    let mode: String
    @Environment(\.colorScheme) private var systemScheme
    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, mode == "dark" ? .dark : mode == "light" ? .light : systemScheme)
            .background(AppearanceWindow(mode: mode).frame(width: 0, height: 0))
    }
}
private struct AppearanceWindow: NSViewRepresentable {
    let mode: String
    func makeNSView(context: Context) -> AppearanceView { AppearanceView() }
    func updateNSView(_ view: AppearanceView, context: Context) { view.mode = mode; view.apply() }
    final class AppearanceView: NSView {
        var mode = "system"
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        func apply() {
            let name: NSAppearance.Name? = mode == "dark" ? .darkAqua : mode == "light" ? .aqua : nil
            if window?.appearance?.name != name { window?.appearance = name.flatMap(NSAppearance.init(named:)) }
        }
    }
}

struct SurfPalette {
    let dark: Bool
    var text: Color { Color(hex: dark ? 0xEEF3FC : 0x202B3B) }
    var muted: Color { Color(hex: dark ? 0xB1BED2 : 0x65758B) }
    var line: Color { Color(hex: dark ? 0xCDE1FF : 0x506D93).opacity(0.12) }
    var control: Color { Color.white.opacity(dark ? 0.09 : 0.38) }
    var selected: Color { Color.white.opacity(dark ? 0.18 : 0.82) }
    var solid: Color { Color(hex: dark ? 0x263248 : 0xEDF3FC) }
    var green: Color { Color(hex: dark ? 0x83DAB1 : 0x18704E) }
    var red: Color { Color(hex: dark ? 0xFFA69B : 0xB3433E) }
    var accent: Color { Color(hex: dark ? 0x94B8FF : 0x326DF1) }
    func delta(_ seconds: Double) -> Color { abs(seconds) < 0.000_001 ? muted : seconds < 0 ? green : red }
}
extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255) }
}
struct WaveMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for y: CGFloat in [16, 20] {
            p.move(to: CGPoint(x: 3, y: y))
            p.addCurve(to: CGPoint(x: 11, y: y-9), control1: CGPoint(x: 6,y: y-7), control2: CGPoint(x: 8,y: y-9))
            p.addCurve(to: CGPoint(x: 17,y: y-2), control1: CGPoint(x: 14,y: y-9), control2: CGPoint(x: 14,y: y-2))
            p.addCurve(to: CGPoint(x: 21,y: y-7), control1: CGPoint(x: 18.5,y: y-2), control2: CGPoint(x: 19.5,y: y-4))
        }
        return p.applying(CGAffineTransform(scaleX: rect.width/24,y: rect.height/24))
    }
}
