import SwiftUI
import AppKit

/// Native Liquid Glass where available, with the same shape and readable fallback.
struct DesktopGlassButtons: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.buttonStyle(.glass).buttonBorderShape(.capsule).controlSize(.regular)
        } else {
            content.buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.regular)
        }
    }
}

struct DesktopGlassProminentButton: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.buttonStyle(.glassProminent).buttonBorderShape(.capsule)
        } else {
            content.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
    }
}

struct DesktopGlassSurface: ViewModifier {
    var interactive = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background(SurfPalette(dark: scheme == .dark).solid, in: Capsule())
                .overlay(Capsule().strokeBorder(SurfPalette(dark: scheme == .dark).line, lineWidth: 1))
        } else if #available(macOS 26, *) {
            content.glassEffect(.regular.interactive(interactive), in: .capsule)
        } else {
            content.background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(scheme == .dark ? 0.16 : 0.65), lineWidth: 1))
        }
    }
}

/// Keep a clear window behind this surface so glass can sample the desktop.
struct DesktopSidebarSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder private var surface: some View {
        if reduceTransparency || contrast == .increased {
            SurfPalette(dark: scheme == .dark).solid
        } else if #available(macOS 26, *) {
            Color.clear.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
    func body(content: Content) -> some View {
        content.background {
            ZStack {
                Group {
                    if reduceTransparency || contrast == .increased {
                        SurfPalette(dark: scheme == .dark).solid
                    } else {
                        SidebarBackdrop()
                    }
                }.ignoresSafeArea(.container, edges: [.top, .bottom]).allowsHitTesting(false)
                // Only the backdrop extends into the titlebar. Keep the inset
                // glass edge below the native traffic-light controls.
                surface.padding(.horizontal, 8).padding(.vertical, 8).allowsHitTesting(false)
            }
        }
    }
}

private struct SidebarBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct DesktopPeriodPicker: View {
    @Binding var weekly: Bool
    @Environment(\.colorScheme) private var scheme
    private var palette: SurfPalette { SurfPalette(dark: scheme == .dark) }
    var body: some View {
        HStack(spacing: 3) {
            segment("Daily", value: false)
            segment("Weekly", value: true)
        }.padding(4).modifier(DesktopGlassSurface(interactive: true))
            .accessibilityElement(children: .contain).accessibilityLabel("Activity period")
    }
    private func segment(_ title: String, value: Bool) -> some View {
        Button { weekly = value } label: {
            Text(title).font(.system(size: 13, weight: weekly == value ? .semibold : .medium))
                .foregroundStyle(weekly == value ? palette.text : palette.muted)
                .frame(width: 88, height: 32)
                .background {
                    if weekly == value {
                        Capsule().fill(palette.selected)
                            .shadow(color: .black.opacity(scheme == .dark ? 0.12 : 0.06), radius: 3, y: 1)
                    }
                }.contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(weekly == value ? "Selected" : "")
            .accessibilityAddTraits(weekly == value ? .isSelected : [])
    }
}

struct DesktopDateButton: View {
    @Binding var date: Date
    let latest: Date
    let weekly: Bool
    @ViewState private var showCalendar = false
    @Environment(\.colorScheme) private var scheme
    private var palette: SurfPalette { SurfPalette(dark: scheme == .dark) }
    var body: some View {
        Button { showCalendar.toggle() } label: {
            HStack(spacing: 9) {
                Image(systemName: "calendar").font(.system(size: 13, weight: .medium))
                Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                    .font(.system(size: 13, weight: .medium)).monospacedDigit()
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            }.foregroundStyle(palette.text).padding(.horizontal, 5).padding(.vertical, 3).contentShape(Capsule())
        }
        .accessibilityLabel(weekly ? "Choose week ending date" : "Choose date")
        .accessibilityValue(date.formatted(date: .complete, time: .omitted))
        .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
            ActivityCalendar(date: $date, latest: latest, weekly: weekly) { showCalendar = false }
        }
    }
}

/// Derive selection from the displayed date so calendar and shortcuts stay in sync.
struct DesktopDateShortcut: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder var body: some View {
        if selected {
            button.modifier(DesktopGlassProminentButton())
        } else {
            button.modifier(DesktopGlassButtons())
        }
    }
    private var button: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: selected ? "checkmark.circle.fill" : symbol)
                Text(title)
            }.font(.system(size: 13, weight: selected ? .semibold : .medium))
                .padding(.vertical, 3).contentShape(Capsule())
        }.accessibilityLabel(title).accessibilityValue(selected ? "Selected" : "Not selected")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
