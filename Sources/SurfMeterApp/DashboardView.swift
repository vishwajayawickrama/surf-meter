import SwiftUI
import Charts
import SurfMeterCore

typealias ViewState<Value> = SwiftUI.State<Value>

private enum Period: String, CaseIterable { case daily = "Daily", weekly = "Weekly" }

struct DashboardView: View {
    @ObservedObject var model: AppModel
    let opaqueBackground: Bool
    @ViewState private var period: Period = .daily
    @ViewState private var yesterday = false
    @ViewState private var selectedPlatform: String?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    private let accent = Color(red: 0.26, green: 0.44, blue: 0.76)
    init(model: AppModel, weekly: Bool = false, yesterday: Bool = false, platform: String? = nil, opaqueBackground: Bool = false) {
        self.model = model
        self.opaqueBackground = opaqueBackground
        _period = State(initialValue: weekly ? .weekly : .daily)
        _yesterday = State(initialValue: yesterday)
        _selectedPlatform = State(initialValue: platform)
    }
    private var days: [String] { period == .weekly ? model.week : [yesterday ? model.yesterday : model.today] }
    private var compare: [String] { period == .daily && !yesterday ? [model.yesterday] : [] }
    private var total: Double { model.ledger.total(days: days, platform: selectedPlatform) }
    private var rows: [UsageRow] { model.ledger.rows(days: days, compare: compare) }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 16)
            Divider().opacity(0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error = model.storageError { errorBanner(error) }
                    if let error = model.bridgeError { errorBanner(error) }
                    if model.screen == .preferences { PreferencesView(model: model) }
                    else if model.screen == .setup { BrowserSetupView(model: model) }
                    else { activity }
                }.padding(22)
            }
            .frame(height: 548)
            Divider().opacity(0.4)
            footer.padding(.horizontal, 22).padding(.vertical, 15)
        }
        .frame(width: 414, height: 660)
        .background {
            if opaqueBackground || reduceTransparency || contrast == .increased { Color(nsColor: .windowBackgroundColor) }
            else { Rectangle().fill(.regularMaterial) }
        }
        .tint(accent)
    }

    private var header: some View {
        HStack {
            Image(systemName: "water.waves").font(.system(size: 23, weight: .medium)).foregroundStyle(accent)
            Text("SurfMeter").font(.system(size: 17, weight: .semibold, design: .rounded))
            Spacer()
            Button { model.changePreferences { $0.paused.toggle() } } label: {
                HStack(spacing: 5) {
                    Image(systemName: model.preferences.paused ? "pause.fill" : "circle.fill").font(.system(size: 6))
                    Text(model.demo ? "Preview" : model.preferences.paused ? "Paused" : model.status.hasPrefix("Tracking") ? "Tracking" : "Ready")
                        .font(.system(size: 11, weight: .medium))
                }.padding(.horizontal, 10).padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .modifier(GlassControl(forceOpaque: opaqueBackground))
            .help(model.preferences.paused ? "Resume tracking" : "Pause tracking")
            .accessibilityLabel(model.preferences.paused ? "Resume tracking" : "Pause tracking")
        }
    }

    @ViewBuilder private var activity: some View {
        if let id = selectedPlatform {
            Button { selectedPlatform = nil } label: { Label("Back to \(period.rawValue.lowercased())", systemImage: "chevron.left") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                PlatformIcon(platform: .named(id), size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Platform.named(id).name).font(.title3.weight(.semibold))
                    Text(period == .weekly ? "This week" : yesterday ? "Yesterday" : "Today so far").foregroundStyle(.secondary)
                }
            }
            totalBlock
            if period == .weekly { weeklyChart(platform: id) } else { hourlyChart(platform: id) }
            if period == .weekly {
                LabeledContent("Daily average", value: UsageFormat.duration(total / 7)).font(.callout)
            }
            Button { _ = model.addExclusion(id); selectedPlatform = nil } label: { Label("Exclude this website", systemImage: "eye.slash") }
                .buttonStyle(.bordered)
            coverageNote
        } else {
            HStack(spacing: 3) {
                ForEach(Period.allCases, id: \.self) { item in
                    Button {
                        period = item
                        if item == .daily { yesterday = false }
                    } label: {
                        Text(item.rawValue).font(.system(size: 13, weight: period == item ? .semibold : .regular))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background {
                                if period == item { Capsule().fill(Color(nsColor: .controlBackgroundColor)).shadow(color: .black.opacity(0.07), radius: 3, y: 1) }
                            }
                    }.buttonStyle(.plain).accessibilityValue(period == item ? "Selected" : "")
                }
            }.padding(4).background(Color.primary.opacity(0.06), in: Capsule())
                .accessibilityElement(children: .contain).accessibilityLabel("Activity period")
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(period == .weekly ? "Your week" : yesterday ? "Yesterday" : "Today so far")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                    if period == .weekly { Text(dateRange).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if period == .daily {
                    Button { yesterday.toggle() } label: { Label(yesterday ? "Back to today" : "Yesterday", systemImage: "clock.arrow.circlepath") }
                        .font(.caption).buttonStyle(.bordered).clipShape(Capsule())
                }
            }
            totalBlock
            if period == .weekly { weeklyChart(platform: nil) }
            if rows.isEmpty { emptyState }
            else {
                HStack {
                    Text("WEBSITES").tracking(1)
                    Spacer()
                    Text(period == .weekly ? "7 DAYS" : yesterday ? "FULL DAY" : "TODAY / YESTERDAY").tracking(0.7)
                }.font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        Button { selectedPlatform = row.id } label: { platformRow(row) }.buttonStyle(.plain)
                        if row.id != rows.last?.id { Divider().opacity(0.35).padding(.leading, 46) }
                    }
                }
            }
            coverageNote
            if !model.preferences.enabled && !model.demo {
                Button("Set up browser tracking") { model.screen = .setup }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }
        }
    }

    private var totalBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.demo { Text(model.status).font(.caption2).foregroundStyle(.secondary) }
            Text(UsageFormat.duration(total))
                .font(.system(size: 42, weight: .light, design: .rounded)).monospacedDigit()
                .accessibilityLabel("Tracked time \(UsageFormat.duration(total))")
            if period == .weekly {
                Text("\(UsageFormat.duration(total / 7)) daily average · today is partial").font(.caption).foregroundStyle(.secondary)
            } else if !yesterday {
                let previous = model.ledger.total(days: [model.yesterday], platform: selectedPlatform)
                HStack(spacing: 8) {
                    Text("Yesterday \(UsageFormat.duration(previous))").foregroundStyle(.secondary)
                    if model.ledger.coverage[model.yesterday] != nil || previous > 0 || total > 0 {
                        Text(UsageFormat.change(total - previous)).foregroundStyle(deltaColor(total - previous))
                    }
                }.font(.caption)
                Text("Compared with yesterday’s full day").font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                Text("Full calendar day · recorded activity").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func platformRow(_ row: UsageRow) -> some View {
        HStack(spacing: 11) {
            PlatformIcon(platform: row.platform, size: 34)
            VStack(alignment: .leading, spacing: 5) {
                Text(row.platform.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                GeometryReader { geometry in
                    Capsule().fill(accent.opacity(0.12)).overlay(alignment: .leading) {
                        Capsule().fill(accent.opacity(0.7)).frame(width: max(0, geometry.size.width * row.seconds / max(1, rows.first?.seconds ?? 1)))
                    }
                }.frame(height: 3).frame(maxWidth: 112).accessibilityHidden(true)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 5) {
                    Text(UsageFormat.duration(row.seconds)).fontWeight(.medium)
                    if !compare.isEmpty { Text("/ \(UsageFormat.duration(row.comparison))").foregroundStyle(.secondary) }
                }.font(.system(size: 11)).monospacedDigit()
                if !compare.isEmpty {
                    Text(UsageFormat.change(row.delta)).font(.system(size: 10)).foregroundStyle(deltaColor(row.delta))
                }
            }
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open website details")
    }

    private func weeklyChart(platform: String?) -> some View {
        Chart(Array(model.week.enumerated()), id: \.offset) { item in
            BarMark(x: .value("Day", item.element), y: .value("Minutes", model.ledger.total(days: [item.element], platform: platform) / 60))
                .foregroundStyle(item.element == model.today ? accent : accent.opacity(0.4)).cornerRadius(4)
                .accessibilityLabel(item.element).accessibilityValue(UsageFormat.duration(model.ledger.total(days: [item.element], platform: platform)))
        }
        .chartXAxis {
            AxisMarks(values: model.week) { value in
                AxisValueLabel { if let day = value.as(String.self) { Text(String(day.suffix(2))).font(.system(size: 9)) } }
            }
        }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
        .chartYScale(domain: 0...max(1, model.week.map { model.ledger.total(days: [$0], platform: platform) / 60 }.max() ?? 1))
        .frame(height: 120)
        .accessibilityLabel("Daily minutes over the last seven days")
    }

    private func hourlyChart(platform: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By hour").font(.subheadline.weight(.medium))
            Chart(0..<24, id: \.self) { hour in
                BarMark(x: .value("Hour", hour), y: .value("Minutes", model.ledger.total(days: days, platform: platform, hour: hour) / 60))
                    .foregroundStyle(accent.opacity(0.7)).cornerRadius(2)
            }
            .chartXScale(domain: 0...23)
            .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 23]) }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
            .frame(height: 150)
            Text("Local clock hours. Repeated daylight-saving hours are combined.").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "water.waves").font(.system(size: 30, weight: .light)).foregroundStyle(accent.opacity(0.8))
            Text("A little awareness starts here").font(.headline)
            Text(model.preferences.enabled ? "Eligible browsing will appear here. Open Chrome with SurfMeter’s extension connected." : "Connect Chrome to see where your browsing time goes. Activity stays on this Mac.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    private var coverageNote: some View {
        VStack(alignment: .leading, spacing: 5) {
            if model.demo { Label("Sample activity · preview only", systemImage: "eye").foregroundStyle(.secondary) }
            if period == .daily && !yesterday && model.ledger.coverage[model.yesterday] == nil && model.ledger.total(days: [model.yesterday]) == 0 {
                Text("No data recorded yesterday.")
            }
            if (days + compare).contains(where: { !(model.ledger.coverage[$0] ?? []).subtracting(["recorded"]).isEmpty }) || period == .weekly {
                Text("Partial coverage. Pauses, setup, or disconnected periods may be missing. No record does not mean no browsing.")
            }
        }.font(.system(size: 10)).foregroundStyle(.secondary)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button { model.changePreferences { $0.paused.toggle() } } label: {
                Label(model.preferences.paused ? "Resume tracking" : "Pause tracking", systemImage: model.preferences.paused ? "play" : "pause")
            }.buttonStyle(.plain).font(.caption).keyboardShortcut("p", modifiers: [.command, .shift])
            Spacer()
            Button { selectedPlatform = nil; model.screen = model.screen == .activity ? .setup : .activity } label: { Image(systemName: model.screen == .activity ? "globe" : "house") }
                .buttonStyle(.plain).help(model.screen == .activity ? "Browser setup" : "Activity").accessibilityLabel("Browser setup or return to activity")
            Button { selectedPlatform = nil; model.screen = model.screen == .preferences ? .activity : .preferences } label: { Image(systemName: "gearshape") }
                .buttonStyle(.plain).help("Preferences").accessibilityLabel("Preferences")
            Button { model.quit() } label: { Image(systemName: "power") }.buttonStyle(.plain).help("Quit SurfMeter").accessibilityLabel("Quit SurfMeter")
        }.foregroundStyle(.secondary)
    }
    private var dateRange: String { "\(model.week.first ?? "") – \(model.today)" }
    private func deltaColor(_ delta: Double) -> Color {
        if abs(delta) < 0.000_001 { return .secondary }
        if delta < 0 { return colorScheme == .dark ? Color(red: 0.50, green: 0.85, blue: 0.68) : Color(red: 0.10, green: 0.43, blue: 0.29) }
        return colorScheme == .dark ? Color(red: 0.98, green: 0.61, blue: 0.58) : Color(red: 0.70, green: 0.21, blue: 0.20)
    }
    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle").font(.caption)
            Button("Retry saving") { model.retryStorage() }.font(.caption)
        }.padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PlatformIcon: View {
    let platform: Platform
    let size: CGFloat
    private var color: Color { Color(red: Double((platform.hex >> 16) & 255) / 255, green: Double((platform.hex >> 8) & 255) / 255, blue: Double(platform.hex & 255) / 255) }
    var body: some View {
        Image(systemName: platform.symbol).font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(color).frame(width: size, height: size)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.29))
            .accessibilityHidden(true)
    }
}

private struct GlassControl: ViewModifier {
    var forceOpaque = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26, *), !reduceTransparency, !forceOpaque, contrast != .increased {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(Color.primary.opacity(0.06), in: Capsule())
        }
    }
}
