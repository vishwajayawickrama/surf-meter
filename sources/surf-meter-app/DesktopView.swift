import SwiftUI
import Charts
import SurfMeterCore

struct DesktopView: View {
    @ObservedObject var model: AppModel
    @ViewState private var page = "activity"
    @ViewState private var weekly = false
    @ViewState private var date = Date()
    @ViewState private var search = ""
    @ViewState private var platform: String?
    @ViewState private var onboarding = false
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var scheme
    private var palette: SurfPalette { SurfPalette(dark: scheme == .dark) }
    private var day: String { LocalDay.key(date, calendar: model.calendar) }
    private var days: [String] { weekly ? LocalDay.recent(7, now: date, calendar: model.calendar) : [day] }
    private var previous: [String] {
        let prior = model.calendar.date(byAdding: .day, value: weekly ? -7 : -1, to: date) ?? date
        return LocalDay.recent(weekly ? 7 : 1, now: prior, calendar: model.calendar)
    }
    private var rows: [UsageRow] {
        model.ledger.rows(days: days, compare: previous).filter {
            search.isEmpty || $0.platform.displayName.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search)
        }
    }
    private var total: Double { model.ledger.total(days: days, platform: platform) }
    private var comparison: Double { model.ledger.total(days: previous, platform: platform) }
    private var hasComparison: Bool {
        // Partial setup coverage alone cannot establish a recorded baseline.
        model.ledger.total(days: previous) > 0 || previous.allSatisfy { model.ledger.coverage[$0]?.contains("recorded") == true }
    }

    init(model: AppModel, weekly: Bool = false, platform: String? = nil) {
        self.model = model
        _weekly = ViewState(wrappedValue: weekly)
        _platform = ViewState(wrappedValue: platform)
    }
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 215)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    if page == "preferences" {
                        PreferencesView(model: model, onBack: { page = "activity" }, onSetup: { page = "setup" }).frame(maxWidth: 650)
                    } else if page == "setup" {
                        BrowserSetupView(model: model, onBack: { page = "activity" })
                            .frame(maxWidth: 650)
                        Button("Open setup walkthrough") { onboarding = true }
                    } else { activity }
                }.padding(32).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(palette.text)
        .modifier(DesktopGlassButtons())
        .background {
            ZStack {
                (scheme == .dark ? Color(hex: 0x121D30) : Color(hex: 0xEEF3FB))
                LinearGradient(colors: [palette.accent.opacity(0.09), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }.ignoresSafeArea(.container, edges: .top)
        }
        .onAppear { date = model.now; onboarding = model.needsOnboarding }
        .sheet(isPresented: $onboarding) { OnboardingView(model: model) { onboarding = false }
            .modifier(SurfAppearance(mode: model.preferences.appearance)) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) { WaveMark().stroke(palette.accent, style: StrokeStyle(lineWidth: 2.7, lineCap: .round)).frame(width: 28, height: 23); Text("SurfMeter").font(.system(size: 19, weight: .semibold)) }
                .padding(.bottom, 34)
            nav("Activity", symbol: "chart.bar.xaxis", value: "activity")
            nav("Browser setup", symbol: "globe", value: "setup")
            nav("Preferences", symbol: "slider.horizontal.3", value: "preferences")
            Spacer()
            Label(model.demo ? "Sample activity" : !model.preferences.enabled ? "Recording is off" : model.preferences.paused ? "Recording paused" : model.hasConnection ? "Chrome connected" : "Chrome disconnected", systemImage: "circle.fill")
                .font(.system(size: 11)).foregroundStyle(palette.muted)
            Text("Your activity stays on this Mac.").font(.system(size: 11)).foregroundStyle(palette.muted).padding(.bottom, 10)
            Button { model.changePreferences { $0.paused.toggle() } } label: {
                Text(model.preferences.paused ? "Resume tracking" : "Pause tracking").foregroundStyle(palette.text)
            }
                .disabled(!model.preferences.enabled).controlSize(.small)
            Button("Setup walkthrough") { onboarding = true }.buttonStyle(.plain).font(.system(size: 11)).padding(.top, 12)
        }.padding(22).padding(.top, 16).background(.ultraThinMaterial)
    }
    private func nav(_ title: String, symbol: String, value: String) -> some View {
        Button { page = value } label: {
            Label(title, systemImage: symbol).font(.system(size: 13, weight: page == value ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading).padding(11)
                .background(page == value ? palette.selected : .clear, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
    private var activity: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A little perspective.").font(.system(size: 28, weight: .semibold))
                    Text(model.demo ? "Preview · sample data" : "Recorded browser time, by website.").font(.callout).foregroundStyle(palette.muted)
                }
                Spacer()
                DesktopPeriodPicker(weekly: $weekly)
            }
            HStack {
                DesktopDateButton(date: $date, latest: model.now, weekly: weekly)
                Spacer()
                if !weekly {
                    Button { date = model.calendar.date(byAdding: .day, value: -1, to: model.now) ?? model.now } label: {
                        Label("Yesterday", systemImage: "clock.arrow.circlepath").font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text).padding(.vertical, 3)
                    }
                }
                Button { date = model.now } label: {
                    Label("Today", systemImage: "calendar.badge.clock").font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text).padding(.vertical, 3)
                }
            }.font(.callout)
            if let error = model.storageError { issue(error) { model.retryStorage() } }
            if let error = model.bridgeError { issue(error) { model.retryBridge() } }
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(platform.map { Platform.named($0).displayName } ?? "All websites").font(.headline)
                        Text(UsageFormat.duration(total)).font(.system(size: 42, weight: .semibold, design: .rounded)).monospacedDigit()
                        if hasComparison {
                            Text("\(UsageFormat.change(total - comparison)) than \(weekly ? "previous 7 days" : "previous day")")
                                .font(.callout).foregroundStyle(deltaColor(total - comparison))
                        } else { Text("No recorded comparison yet").font(.callout).foregroundStyle(palette.muted) }
                    }
                    Spacer()
                    if platform != nil { Button("All websites") { platform = nil } }
                    VStack(alignment: .trailing, spacing: 7) {
                        Text(weekly ? "DAILY AVERAGE" : "PREVIOUS DAY").font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(palette.muted)
                        Text(weekly ? UsageFormat.duration(total / 7) : hasComparison ? UsageFormat.duration(comparison) : "—").font(.title2).monospacedDigit()
                    }
                }
                timeline.frame(height: 180)
                Text("\(weekly ? "Seven calendar days ending on the selected date." : "Time by local hour.") Totals can be partial when recording is off, paused, idle, locked, or disconnected. Today is still in progress.")
                    .font(.caption).foregroundStyle(palette.muted)
            }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            HStack {
                Text("Websites").font(.title3.weight(.semibold)); Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(palette.muted)
                    TextField("Search websites", text: $search, prompt: Text("Search websites").foregroundStyle(palette.muted)).textFieldStyle(.plain)
                        .focused($searchFocused).accessibilityLabel("Search websites")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(palette.muted) }
                            .buttonStyle(.plain).accessibilityLabel("Clear website search")
                    }
                }.font(.system(size: 12)).padding(.horizontal, 13).padding(.vertical, 10)
                    .frame(width: 220).modifier(DesktopGlassSurface())
                    .overlay(Capsule().strokeBorder(searchFocused ? palette.accent.opacity(0.65) : .clear, lineWidth: 2))
            }
            VStack(spacing: 0) {
                HStack { Text("WEBSITE"); Spacer(); Text(weekly ? "7 DAYS / AVERAGE" : "TIME / PREVIOUS DAY"); Text("CHANGE").frame(width: 120, alignment: .trailing) }
                    .font(.system(size: 9, weight: .medium)).tracking(0.7).foregroundStyle(palette.muted).padding(.bottom, 12)
                if rows.isEmpty {
                    VStack(spacing: 9) {
                        Text(search.isEmpty ? "No activity for these dates" : "No matching websites").font(.headline)
                        Text(search.isEmpty ? "Choose another date, or keep Chrome connected with recording enabled to collect time. Older totals may have expired under your retention setting." : "Try another website name or domain.").font(.callout).foregroundStyle(palette.muted)
                        if search.isEmpty { Button("Browser setup") { page = "setup" } }
                    }.frame(maxWidth: .infinity).padding(25)
                }
                ForEach(rows) { row in
                    Button { platform = platform == row.id ? nil : row.id } label: {
                        HStack(spacing: 12) {
                            PlatformIcon(platform: row.platform, size: 35)
                            VStack(alignment: .leading, spacing: 4) { Text(row.platform.displayName).font(.system(size: 13, weight: .medium)); Text(row.id).font(.caption).foregroundStyle(palette.muted) }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(UsageFormat.duration(row.seconds)).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                                Text(weekly ? "\(UsageFormat.duration(row.seconds / 7)) / day" : hasComparison ? UsageFormat.duration(row.comparison) : "No baseline").font(.caption).foregroundStyle(palette.muted)
                            }
                            Text(hasComparison ? UsageFormat.change(row.delta) : "—").font(.caption).foregroundStyle(hasComparison ? deltaColor(row.delta) : palette.muted).frame(width: 120, alignment: .trailing)
                        }.padding(.vertical, 13).padding(.horizontal, 8).contentShape(Rectangle())
                            .background(platform == row.id ? palette.control : .clear, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).accessibilityLabel("\(row.platform.displayName), \(UsageFormat.duration(row.seconds)). Show breakdown.")
                    Divider()
                }
            }
            if let platform {
                HStack {
                    Label("\(Platform.named(platform).displayName) · selected in chart", systemImage: "chart.bar")
                    Spacer()
                    let excluded = model.preferences.excluded.contains(platform)
                    Button(excluded ? "Include in future tracking" : "Exclude from future tracking") {
                        model.changePreferences { prefs in
                            if excluded { prefs.excluded.removeAll { $0 == platform } } else { prefs.excluded.append(platform) }
                        }
                    }
                }.font(.caption)
            }
        }
    }
    private var timeline: some View {
        Group {
            if weekly {
                Chart(days, id: \.self) { key in
                    BarMark(x: .value("Day", String(key.suffix(5))), y: .value("Minutes", model.ledger.total(days: [key], platform: platform) / 60))
                        .foregroundStyle(palette.accent.gradient).cornerRadius(4)
                }.chartXAxisLabel("Date (month-day)")
            } else {
                Chart(Array(0..<24), id: \.self) { hour in
                    BarMark(x: .value("Hour", hour), y: .value("Minutes", model.ledger.total(days: days, platform: platform, hour: hour) / 60))
                        .foregroundStyle(palette.accent.gradient).cornerRadius(3)
                }.chartXScale(domain: -0.5...23.5)
                    .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 23]) }
                    .chartXAxisLabel("Hour (0–23)")
            }
        }.chartYAxisLabel("Minutes")
    }
    private func deltaColor(_ value: Double) -> Color { abs(value) < 0.000001 ? palette.muted : value < 0 ? palette.green : palette.red }
    private func issue(_ message: String, action: @escaping () -> Void) -> some View {
        HStack { Label(message, systemImage: "exclamationmark.triangle"); Spacer(); Button("Retry", action: action) }.font(.caption).padding(12).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
