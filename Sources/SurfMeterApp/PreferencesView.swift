import SwiftUI
import SurfMeterCore

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @ViewState private var domain = ""
    @ViewState private var exclusionError: String?
    @ViewState private var confirmDelete = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Preferences").font(.title2.weight(.semibold))
            Text("Make SurfMeter feel at home.").font(.callout).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 15) {
                Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { model.toggleLogin($0) }))
                    .disabled(model.demo)
                if let message = model.loginMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                Picker("Appearance", selection: Binding(get: { model.preferences.appearance }, set: { value in model.changePreferences { $0.appearance = value } })) {
                    Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                }
                Picker("Keep activity", selection: Binding(get: { model.preferences.retention }, set: { value in model.changePreferences { $0.retention = value } })) {
                    Text("7 days").tag(7); Text("30 days").tag(30); Text("90 days").tag(90)
                }
                Text("Only active browsing counts. Recording pauses after 60 seconds without input.").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Excluded websites").font(.headline)
                Text("A domain also excludes its subdomains. Platform exclusions cover their aliases.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("example.com", text: $domain).textFieldStyle(.roundedBorder).onSubmit(add)
                        .accessibilityLabel("Website domain to exclude")
                    Button("Add", action: add).disabled(domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let exclusionError { Text(exclusionError).font(.caption).foregroundStyle(.red) }
                if model.preferences.excluded.isEmpty { Text("No websites excluded").font(.caption).foregroundStyle(.secondary) }
                ForEach(model.preferences.excluded, id: \.self) { item in
                    HStack {
                        Text(item).font(.callout); Spacer()
                        Button { model.changePreferences { $0.excluded.removeAll { $0 == item } } } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Remove exclusion for \(item)")
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Label("Local by design", systemImage: "lock.shield").font(.headline)
                Text("Hourly website totals stay on this Mac. No account, cloud sync, full URLs, page titles, or browsing content.").font(.caption).foregroundStyle(.secondary)
                Button("Delete all activity", role: .destructive) { confirmDelete = true }.buttonStyle(.bordered)
                Text("Existing totals remain when you exclude a website. Deletion clears all recorded days.").font(.caption2).foregroundStyle(.secondary)
            }
            Text("SurfMeter 0.2 · Development build").font(.caption2).foregroundStyle(.tertiary)
        }
        .alert("Delete all activity?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete activity", role: .destructive) { model.deleteActivity() }
        } message: { Text("This permanently clears all recorded website totals from this Mac. Your preferences remain. New activity can accumulate while tracking is enabled.") }
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
            Text("Browser setup").font(.title2.weight(.semibold))
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
