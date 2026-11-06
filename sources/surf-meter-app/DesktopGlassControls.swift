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
                if reduceTransparency || contrast == .increased {
                    SurfPalette(dark: scheme == .dark).solid
                } else {
                    SidebarBackdrop().allowsHitTesting(false)
                }
                surface.padding(.horizontal, 8).padding(.vertical, 8).allowsHitTesting(false)
            }.ignoresSafeArea(.container, edges: [.top, .bottom])
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
            VStack(alignment: .leading, spacing: 16) {
                Text(weekly ? "Week ending" : "Choose a day").font(.headline)
                DatePicker("Activity date", selection: $date, in: ...latest, displayedComponents: .date)
                    .datePickerStyle(.graphical).labelsHidden()
                HStack { Spacer(); Button { showCalendar = false } label: { Text("Done").foregroundStyle(palette.text) }.keyboardShortcut(.defaultAction) }
            }.padding(20).modifier(DesktopGlassButtons())
        }
    }
}
