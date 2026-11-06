import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    var finish: () -> Void
    @ViewState var step = 0
    @Environment(\.colorScheme) private var scheme
    private let titles = ["Welcome to SurfMeter", "Give SurfMeter a home", "Connect your browser", "Make it yours"]
    private var mountedImage: Bool { Bundle.main.bundleURL.path.hasPrefix("/Volumes/") }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("SURFMETER SETUP").font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary)
                Spacer()
                Text("\(step + 1) of 4").font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(step + 1), total: 4).tint(Color(hex: 0x326DF1))
            Text(titles[step]).font(.system(size: 28, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch step {
                    case 0:
                        Image(systemName: "water.waves").font(.system(size: 56, weight: .light)).foregroundStyle(Color(hex: 0x326DF1)).padding(.vertical, 18)
                        Text("Your browsing. A little clearer.").font(.title2.weight(.medium))
                        Text("Check your day in the menu bar, or open this window for the bigger picture. Compare websites, revisit yesterday, and see your week.")
                        Label("Activity stays on this Mac. No account required.", systemImage: "lock.shield")
                        Text("Recording starts off on a new install. The browser extension reads the active tab URL and sends only its hostname to this Mac app. SurfMeter stores hourly website totals, without URL paths, page titles, or browsing content.").font(.callout).foregroundStyle(.secondary)
                    case 1:
                        Label("Install in Applications", systemImage: "folder.badge.plus").font(.title3.weight(.semibold))
                        Text("If you downloaded a disk image, quit this copy, drag SurfMeter into Applications, eject the image, then open SurfMeter from Applications. Connect Chrome only after moving the app to its permanent location.")
                        Text(mountedImage ? "This copy is running from a disk image. Move it before continuing." : "This copy is not running from a disk image.")
                            .font(.callout).foregroundStyle(mountedImage ? .orange : .secondary)
                        Button("Show Applications") { NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true)) }.disabled(model.demo)
                        Text("This is a development build with ad hoc signing. It is not notarized. Safari recording is not included. Only install builds from a source you trust.").font(.callout).foregroundStyle(.secondary)
                    case 2:
                        if mountedImage { Text("Move SurfMeter to Applications and reopen it before connecting Chrome.").foregroundStyle(.orange) }
                        BrowserSetupView(model: model, showsBack: false).disabled(mountedImage)
                    default:
                        Text("Choose when SurfMeter is available. You can change these settings later in Preferences.")
                        Toggle("Launch SurfMeter at login", isOn: Binding(get: { model.loginEnabled }, set: { model.toggleLogin($0) })).disabled(model.demo || mountedImage)
                        if let message = model.loginMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                        Picker("Appearance", selection: Binding(get: { model.preferences.appearance }, set: { value in model.changePreferences { $0.appearance = value } })) {
                            Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                        }.pickerStyle(.segmented)
                        Text(model.preferences.enabled ? "Recording is enabled. Time counts only while Chrome has an eligible active page and your Mac is in use." : "Recording is off. Connect Chrome and enable recording in Browser setup whenever you are ready.").font(.callout)
                        Label("Closing the window keeps SurfMeter in your menu bar. Use Quit SurfMeter to stop the app.", systemImage: "menubar.rectangle").font(.callout).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
            }
            Divider()
            HStack {
                Button("Set up later") { model.completeOnboarding(); finish() }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                if step > 0 { Button("Back") { step -= 1 } }
                Button(step == 3 ? "Open SurfMeter" : "Continue") {
                    if step < 3 { step += 1 } else { model.completeOnboarding(); finish() }
                }.modifier(DesktopGlassProminentButton()).keyboardShortcut(.defaultAction)
                    .disabled(mountedImage && step == 1)
            }
        }.padding(32).frame(width: 580, height: 650)
            .modifier(DesktopGlassButtons())
            .foregroundStyle(SurfPalette(dark: scheme == .dark).text)
            .background(scheme == .dark ? Color(hex: 0x182337) : Color(hex: 0xF3F6FC))
    }
}
