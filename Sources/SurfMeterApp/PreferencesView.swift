import SwiftUI
import SurfMeterCore

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @ViewState private var domain = ""
    @ViewState private var exclusionError: String?
    @ViewState private var confirmDelete = false
    @Environment(\.colorScheme) private var scheme
    private var palette: SurfPalette { SurfPalette(dark: scheme == .dark) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button { model.screen = .activity } label: { Image(systemName: "chevron.left").frame(width: 29, height: 29).background(palette.control, in: Circle()) }
                    .buttonStyle(.plain).accessibilityLabel("Back to activity")
                Text("Preferences").font(.system(size: 18, weight: .semibold))
            }.padding(.bottom, 25)
            section("MAKE IT YOURS")
            setting("Launch at login", subtitle: "A little awareness, from the moment you start.") {
                Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { model.toggleLogin($0) })).labelsHidden().toggleStyle(.switch).controlSize(.mini).disabled(model.demo)
            }
            if let message = model.loginMessage { Text(message).font(.system(size: 9)).foregroundStyle(palette.muted) }
            setting("Dark appearance", subtitle: "A softer glow after hours.") {
                VStack(alignment: .trailing, spacing: 5) {
                    Toggle("Dark appearance", isOn: Binding(get: { model.preferences.appearance == "dark" || (model.preferences.appearance == "system" && scheme == .dark) }, set: { value in model.changePreferences { $0.appearance = value ? "dark" : "light" } })).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                    Button(model.preferences.appearance == "system" ? "Following system" : "Use system") { model.changePreferences { $0.appearance = "system" } }
                        .buttonStyle(.plain).font(.system(size: 8)).foregroundStyle(palette.muted)
                }
            }
            Button { model.screen = .setup } label: {
                HStack { Label("Connected browsers", systemImage: "globe"); Spacer(); Text(model.hasConnection ? "1 connected" : "Set up").foregroundStyle(palette.muted); Image(systemName: "chevron.right").font(.system(size: 8)) }
                    .font(.system(size: 11)).padding(.vertical, 16).contentShape(Rectangle())
            }.buttonStyle(.plain)
            section("YOUR DATA").padding(.top, 18)
            setting("Keep daily totals", subtitle: "Older activity is removed automatically.") {
                Picker("Keep daily totals", selection: Binding(get: { model.preferences.retention }, set: { value in model.changePreferences { $0.retention = value } })) {
                    Text("7 days").tag(7); Text("30 days").tag(30); Text("90 days").tag(90)
                }.labelsHidden().frame(width: 88).controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("Excluded websites").font(.system(size: 11, weight: .medium))
                Text("These domains and their subdomains won’t count. Existing totals remain.").font(.system(size: 9)).foregroundStyle(palette.muted)
                HStack {
                    TextField("e.g. work.example.com", text: $domain).textFieldStyle(.plain).onSubmit(add).accessibilityLabel("Website domain to exclude")
                    Button("Add", action: add).buttonStyle(.plain).disabled(domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.font(.system(size: 10)).padding(10).background(palette.control, in: Capsule())
                if let exclusionError { Text(exclusionError).font(.system(size: 9)).foregroundStyle(palette.red) }
                ForEach(model.preferences.excluded, id: \.self) { item in
                    HStack { Text(item); Spacer(); Button { model.changePreferences { $0.excluded.removeAll { $0 == item } } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Remove exclusion for \(item)") }
                        .font(.system(size: 10)).padding(8).background(palette.control, in: Capsule())
                }
            }.padding(.vertical, 15)
            Button("Delete all activity…", role: .destructive) { confirmDelete = true }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(palette.red).padding(.vertical, 12)
            Label("Your activity stays on this Mac. No account, cloud sync, full URLs, page titles, or browsing content.", systemImage: "lock.shield")
                .font(.system(size: 9)).foregroundStyle(palette.muted).fixedSize(horizontal: false, vertical: true).padding(.top, 15)
            HStack { Text("SurfMeter 0.2 · Development build"); Spacer(); Button("Quit SurfMeter") { model.quit() }.buttonStyle(.plain) }.font(.system(size: 8)).foregroundStyle(palette.muted).padding(.top, 20)
        }
        .alert("Delete all activity?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete activity", role: .destructive) { model.deleteActivity() }
        } message: { Text("This permanently clears all recorded website totals from this Mac. Your preferences remain. New activity can accumulate while tracking is enabled.") }
    }
    private func section(_ title: String) -> some View { Text(title).font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(palette.muted).padding(.bottom, 10) }
    private func setting<Control: View>(_ title: String, subtitle: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 11, weight: .medium)); Text(subtitle).font(.system(size: 9)).foregroundStyle(palette.muted) }
            Spacer(minLength: 10); control()
        }.padding(.vertical, 13).overlay(alignment: .bottom) { Rectangle().fill(palette.line).frame(height: 1) }
    }
    private func add() {
        if model.addExclusion(domain) { domain = ""; exclusionError = nil }
        else { exclusionError = "Enter a domain such as example.com, without a URL path." }
    }
}

struct BrowserSetupView: View {
    @ObservedObject var model: AppModel
    @ViewState private var extensionID = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Button { model.screen = .preferences } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain).accessibilityLabel("Back to preferences"); Text("Browser setup").font(.system(size: 18, weight: .semibold)) }
            Text("Your browser tells SurfMeter which website is active. The Mac app decides when time counts.").font(.callout).foregroundStyle(.secondary)
            HStack {
                Image(systemName: "globe").font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Google Chrome").font(.headline)
                    Text(model.hasConnection ? "Connected" : "Waiting for extension").font(.caption).foregroundStyle(model.hasConnection ? .green : .secondary)
                }
                Spacer()
                Image(systemName: model.hasConnection ? "checkmark.circle.fill" : "link").foregroundStyle(model.hasConnection ? .green : .secondary)
            }.padding(14).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            Text("DEVELOPMENT SETUP").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
            Text("1. Open chrome://extensions. Turn on Developer mode and choose Load unpacked.").font(.callout)
            Button("Show Chrome extension folder") { model.revealExtension() }.disabled(model.demo)
            Text("2. Load the dist folder, then paste its extension ID below to register the local connection.").font(.callout)
            TextField("32-letter extension ID", text: $extensionID).textFieldStyle(.roundedBorder).accessibilityLabel("Chrome extension ID")
            Button("Connect Chrome") { model.registerChrome(extensionID.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .buttonStyle(.bordered).disabled(model.demo)
            if let message = model.setupMessage { Text(message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
            Text("3. Open a normal web page in Chrome, then click the SurfMeter extension button. Once connected, enable recording below.").font(.callout)
            Toggle("Record eligible Chrome activity", isOn: Binding(get: { model.preferences.enabled }, set: { value in model.changePreferences { $0.enabled = value } }))
                .disabled(!model.hasConnection && !model.preferences.enabled && !model.demo)
            Text("The extension reads the active tab URL and sends only its hostname locally. Incognito access is disabled. No page content or URL paths are stored. This development build still needs real-browser privacy, accuracy, and lock/recovery validation.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack {
                Image(systemName: "safari").font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Safari").font(.headline)
                    Text("Not enabled · Xcode packaging required").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Safari support is in development. It does not record activity in this build.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
