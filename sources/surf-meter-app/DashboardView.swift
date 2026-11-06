import SwiftUI
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
    private var palette: SurfPalette { SurfPalette(dark: colorScheme == .dark) }
    private var accent: Color { palette.accent }
    init(model: AppModel, weekly: Bool = false, yesterday: Bool = false, platform: String? = nil, opaqueBackground: Bool = false) {
        self.model = model
        self.opaqueBackground = opaqueBackground
        _period = State(initialValue: weekly ? .weekly : .daily)
        _yesterday = State(initialValue: yesterday)
        _selectedPlatform = State(initialValue: platform)
    }
    private var days: [String] { period == .weekly ? model.week : [yesterday ? model.yesterday : model.today] }
    private var hasComparison: Bool { model.ledger.coverage[model.yesterday]?.contains("recorded") == true || model.ledger.total(days: [model.yesterday]) > 0 }
    private var compare: [String] { period == .daily && !yesterday && hasComparison ? [model.yesterday] : [] }
    private var total: Double { model.ledger.total(days: days, platform: selectedPlatform) }
    private var rows: [UsageRow] { model.ledger.rows(days: days, compare: compare) }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 23).padding(.top, 22).padding(.bottom, 19)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let error = model.storageError { errorBanner(error, button: "Retry saving", action: model.retryStorage) }
                    if let error = model.bridgeError { errorBanner(error, button: "Retry connection", action: model.retryBridge) }
                    if model.screen == .preferences { PreferencesView(model: model) }
                    else if model.screen == .setup { BrowserSetupView(model: model) }
                    else { activity }
                }.padding(.horizontal, 23).padding(.bottom, 18)
            }
            .frame(maxHeight: .infinity)
            Rectangle().fill(palette.line).frame(height: 1).padding(.horizontal, 23)
            footer.padding(.horizontal, 23).padding(.vertical, 15)
        }
        .frame(width: 390, height: model.screen == .activity ? (selectedPlatform != nil ? 720 : period == .weekly ? 766 : 746) : 690)
        .background {
            if opaqueBackground || reduceTransparency || contrast == .increased { palette.solid }
            else { Rectangle().fill(.ultraThinMaterial).overlay(palette.solid.opacity(colorScheme == .dark ? 0.78 : 0.66)) }
        }
        .foregroundStyle(palette.text)
        .clipShape(RoundedRectangle(cornerRadius: MenuPanelSurface.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MenuPanelSurface.cornerRadius, style: .continuous).strokeBorder(.white.opacity(colorScheme == .dark ? 0.21 : 0.78), lineWidth: 1))
        .tint(accent)
        .modifier(MenuPanelSurface())
    }

    private var header: some View {
        HStack {
            WaveMark().stroke(accent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round)).frame(width: 21, height: 21)
            Text("SurfMeter").font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                if !model.preferences.enabled { model.screen = .setup }
                else { model.changePreferences { $0.paused.toggle() } }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: model.preferences.paused ? "pause.fill" : "circle.fill").font(.system(size: 6)).foregroundStyle(model.preferences.paused || !model.preferences.enabled || (!model.hasConnection && !model.demo) ? palette.muted : palette.green)
                    Text(model.demo ? "Preview" : !model.preferences.enabled ? "Off" : model.preferences.paused ? "Paused" : model.status.hasPrefix("Tracking") ? "Tracking" : model.hasConnection ? "Ready" : "Disconnected")
                        .font(.system(size: 9, weight: .medium))
                }.padding(.horizontal, 10).padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(palette.control, in: Capsule())
            .help(model.status)
            .accessibilityLabel(!model.preferences.enabled ? "Set up browser tracking" : model.preferences.paused ? "Resume tracking" : "Pause tracking")
        }
    }

    @ViewBuilder private var activity: some View {
        if let id = selectedPlatform {
            HStack(spacing: 10) {
                Button { selectedPlatform = nil } label: { Image(systemName: "chevron.left").frame(width: 29, height: 29).background(palette.control, in: Circle()) }
                    .buttonStyle(.plain).accessibilityLabel("Back to \(period.rawValue.lowercased())")
                Text("Website activity").font(.system(size: 18, weight: .semibold))
            }.padding(.bottom, 7)
            HStack(spacing: 12) {
                PlatformIcon(platform: .named(id), size: 41)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Platform.named(id).name).font(.system(size: 17, weight: .semibold))
                    Text(id).font(.system(size: 10)).foregroundStyle(palette.muted)
                }
            }
            HStack(spacing: 0) {
                detailStat(period == .weekly ? "Last 7 days" : yesterday ? "Yesterday" : "Today", value: UsageFormat.duration(total))
                Rectangle().fill(palette.line).frame(width: 1, height: 38)
                detailStat(period == .weekly ? "Daily average" : yesterday ? "Today" : "Yesterday", value: period == .weekly ? UsageFormat.duration(total / 7) : !yesterday && !hasComparison ? "No data" : UsageFormat.duration(model.ledger.total(days: [yesterday ? model.today : model.yesterday], platform: id)))
            }.padding(.vertical, 15).background(palette.control, in: RoundedRectangle(cornerRadius: 12))
            if period == .weekly { Text("\(dateRange) · includes today so far").font(.system(size: 9)).foregroundStyle(palette.muted) }
            else if !yesterday && hasComparison {
                let delta = total - model.ledger.total(days: [model.yesterday], platform: id)
                Text("\(UsageFormat.change(delta)) \(abs(delta) < 0.000_001 ? "as" : "than") yesterday’s full day")
                    .font(.system(size: 10)).foregroundStyle(palette.delta(delta))
            } else if yesterday { Text("Yesterday’s complete calendar day").font(.system(size: 9)).foregroundStyle(palette.muted) }
            Text(period == .weekly ? "Your week, day by day" : yesterday ? "Yesterday, hour by hour" : "Today, hour by hour")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(palette.muted)
            if period == .weekly { weeklyChart(platform: id) } else { hourlyChart(platform: id) }
            Button {
                if model.preferences.excluded.contains(id) { model.changePreferences { $0.excluded.removeAll { $0 == id } } }
                else { _ = model.addExclusion(id) }
            } label: { Label(model.preferences.excluded.contains(id) ? "Include this website" : "Exclude this website", systemImage: model.preferences.excluded.contains(id) ? "eye" : "eye.slash")
                    .font(.system(size: 11)).padding(10).background(palette.control, in: Capsule()) }
                .buttonStyle(.plain)
            Text("Excluding a website stops future tracking. Your existing totals stay in place.").font(.system(size: 9)).foregroundStyle(palette.muted)
            coverageNote
        } else {
            HStack(spacing: 3) {
                ForEach(Period.allCases, id: \.self) { item in
                    Button {
                        period = item
                        if item == .daily { yesterday = false }
                    } label: {
                        Text(item.rawValue).font(.system(size: 11, weight: period == item ? .semibold : .regular))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background {
                                if period == item { Capsule().fill(palette.selected).shadow(color: .black.opacity(0.07), radius: 3, y: 1) }
                            }
                    }.buttonStyle(.plain).accessibilityValue(period == item ? "Selected" : "")
                }
            }.padding(4).background(Color(hex: colorScheme == .dark ? 0xB9D1FF : 0x6D8DB7).opacity(colorScheme == .dark ? 0.09 : 0.08), in: Capsule())
                .accessibilityElement(children: .contain).accessibilityLabel("Activity period")
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(period == .weekly ? "Last 7 days" : "\(yesterday ? "Yesterday" : "Today") · \(displayDate)")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
                Spacer()
                if period == .weekly { Text(dateRange).font(.system(size: 9)).foregroundStyle(palette.muted) }
                if period == .daily {
                    Button { yesterday.toggle() } label: { Label("Yesterday", systemImage: "clock.arrow.circlepath") }
                        .font(.system(size: 9)).buttonStyle(.plain).padding(.horizontal, 9).padding(.vertical, 6).background(yesterday ? palette.selected : palette.control, in: Capsule()).accessibilityValue(yesterday ? "Selected; activate to return to today" : "")
                }
            }
            totalBlock
            if period == .weekly { weeklyChart(platform: nil) } else { hourlyChart(platform: nil) }
            if rows.isEmpty { emptyState }
            else {
                HStack {
                    Text("YOUR PLATFORMS").tracking(1)
                    Spacer()
                    Text(period == .weekly ? "7 DAYS" : yesterday ? "FULL DAY" : hasComparison ? "vs. yesterday ⓘ" : "TODAY").tracking(0.7)
                }.font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        Button { selectedPlatform = row.id } label: { platformRow(row) }.buttonStyle(.plain)
                        if row.id != rows.last?.id { Divider().opacity(0.35) }
                    }
                }
            }
            coverageNote
            if !model.preferences.enabled {
                Button("Set up browser tracking") { model.screen = .setup }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }
        }
    }

    private func detailStat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 9)).foregroundStyle(palette.muted)
            Text(value).font(.system(size: 24, weight: .semibold)).tracking(-0.7).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
    }

    private var totalBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                let minutes = Int(total / 60)
                if minutes >= 60 {
                    Text("\(minutes / 60)").font(.system(size: 46, weight: .semibold)).tracking(-2.6)
                    Text("h").font(.system(size: 22)).foregroundStyle(palette.muted)
                }
                Text(total > 0 && minutes == 0 ? "<1" : "\(minutes % 60)").font(.system(size: 46, weight: .semibold)).tracking(-2.6)
                Text("m").font(.system(size: 22)).foregroundStyle(palette.muted)
            }.monospacedDigit().accessibilityElement(children: .ignore)
                .accessibilityLabel("Tracked time \(UsageFormat.duration(total))")
            if period == .weekly {
                Text("\(UsageFormat.duration(total / 7)) daily average · today is partial")
                    .foregroundStyle(palette.muted)
            } else if !yesterday {
                let previous = model.ledger.total(days: [model.yesterday], platform: selectedPlatform)
                if hasComparison {
                    HStack(spacing: 4) {
                        Text(UsageFormat.change(total - previous)).foregroundStyle(palette.delta(total - previous))
                        Text(abs(total - previous) < 0.000_001 ? "as yesterday" : "than yesterday").foregroundStyle(palette.muted)
                    }
                }
            } else { Text("Full calendar day · recorded activity").foregroundStyle(palette.muted) }
        }.font(.system(size: 10))
    }

    private func platformRow(_ row: UsageRow) -> some View {
        HStack(spacing: 11) {
            PlatformIcon(platform: row.platform, size: 31)
            VStack(alignment: .leading, spacing: 5) {
                Text(row.platform.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                GeometryReader { geometry in
                    Capsule().fill(Color(hex: row.platform.hex).opacity(0.12)).overlay(alignment: .leading) {
                        Capsule().fill(Color(hex: row.platform.hex).opacity(0.75)).frame(width: max(0, geometry.size.width * row.seconds / max(0.000_001, rows.first?.seconds ?? 1)))
                    }
                }.frame(height: 3).frame(maxWidth: 112).accessibilityHidden(true)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 5) {
                Text(UsageFormat.duration(row.seconds)).font(.system(size: 11, weight: .semibold))
                if !compare.isEmpty { Text("\(UsageFormat.duration(row.comparison)) yesterday").font(.system(size: 9)).foregroundStyle(palette.muted) }
                else if period == .weekly { Text("\(UsageFormat.duration(row.seconds / 7)) / day").font(.system(size: 9)).foregroundStyle(palette.muted) }
            }.monospacedDigit()
            if !compare.isEmpty {
                Text(abs(row.delta) < 0.000_001 ? "—" : "\(row.delta < 0 ? "↓" : "↑") \(UsageFormat.duration(abs(row.delta)))")
                    .font(.system(size: 9)).foregroundStyle(palette.delta(row.delta)).frame(width: 62)
                    .accessibilityLabel(UsageFormat.change(row.delta))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open website details")
    }

    private func weeklyChart(platform: String?) -> some View {
        let values = model.week.map { model.ledger.total(days: [$0], platform: platform) }
        let peak = max(1, values.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 9) {
            ForEach(Array(model.week.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 7) {
                    Text(UsageFormat.duration(values[index])).font(.system(size: 8)).foregroundStyle(palette.muted)
                    VStack { Spacer(minLength: 0); RoundedRectangle(cornerRadius: 4).fill(accent.opacity(day == model.today ? 0.85 : 0.4)).frame(width: 22, height: 66 * values[index] / peak) }.frame(height: 66).frame(width: 22).background(palette.control, in: RoundedRectangle(cornerRadius: 4))
                    Text(weekDate(index, format: "EEE")).font(.system(size: 9, weight: day == model.today ? .semibold : .regular))
                        .foregroundStyle(day == model.today ? accent : palette.text)
                    Text(day == model.today ? "Today" : weekDate(index, format: "d MMM"))
                        .font(.system(size: 7)).foregroundStyle(day == model.today ? accent : palette.muted)
                }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day), \(UsageFormat.duration(values[index]))")
            }
        }.padding(.top, 2)
    }
    private func hourlyChart(platform: String?) -> some View {
        let values = (0..<24).map { model.ledger.total(days: days, platform: platform, hour: $0) }
        let peak = max(1, values.max() ?? 1)
        return VStack(spacing: 7) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<24, id: \.self) { hour in
                    RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.48))
                        .frame(maxWidth: .infinity).frame(height: 67 * values[hour] / peak)
                        .accessibilityElement(children: .ignore).accessibilityLabel("\(hour):00, \(UsageFormat.duration(values[hour]))")
                }
            }.frame(height: 67, alignment: .bottom)
                .background(alignment: .bottom) { Rectangle().fill(palette.line).frame(height: 1) }
            HStack { ForEach(["00:00", "06:00", "12:00", "18:00", "24:00"], id: \.self) { label in
                Text(label); if label != "24:00" { Spacer() }
            }}.font(.system(size: 8, design: .monospaced)).foregroundStyle(palette.muted)
        }.padding(.top, 2).accessibilityElement(children: .contain).accessibilityLabel("Activity by local clock hour")
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
            if period == .daily && !yesterday && !hasComparison {
                Text("No data recorded yesterday.")
            }
            if (days + compare).contains(where: { !(model.ledger.coverage[$0] ?? []).subtracting(["recorded"]).isEmpty }) || period == .weekly {
                Text("Partial coverage. Pauses, setup, or disconnected periods may be missing. No record does not mean no browsing.")
            }
        }.font(.system(size: 9)).foregroundStyle(palette.muted)
    }

    private var footer: some View {
        HStack {
            Button { model.changePreferences { $0.paused.toggle() } } label: {
                Label(model.preferences.paused ? "Resume tracking" : "Pause tracking", systemImage: model.preferences.paused ? "play" : "pause")
                    .font(.system(size: 10)).padding(.horizontal, 11).padding(.vertical, 8)
                    .background(palette.control, in: Capsule())
            }.buttonStyle(.plain).keyboardShortcut("p", modifiers: [.command, .shift]).disabled(!model.preferences.enabled)
            Spacer()
            Button { DesktopController.shared.show(model: model) } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 29, height: 29).background(palette.control, in: Circle())
            }.buttonStyle(.plain).help("Open detailed view").accessibilityLabel("Open detailed view")
            Button { selectedPlatform = nil; model.screen = model.screen == .preferences ? .activity : .preferences } label: {
                Image(systemName: "gearshape").font(.system(size: 13)).frame(width: 29, height: 29).background(palette.control, in: Circle())
            }.buttonStyle(.plain).help("Preferences").accessibilityLabel("Preferences")
                .contextMenu {
                    Button("Browser setup") { model.screen = .setup }
                    Button("Quit SurfMeter") { model.quit() }
                }
        }.foregroundStyle(palette.muted)
    }
    private var displayDate: String {
        let formatter = DateFormatter(); formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: yesterday ? (model.calendar.date(byAdding: .day, value: -1, to: model.now) ?? model.now) : model.now)
    }
    private func weekDate(_ index: Int, format: String) -> String {
        let formatter = DateFormatter(); formatter.calendar = model.calendar; formatter.dateFormat = format
        let date = model.calendar.date(byAdding: .day, value: index - 6, to: model.now) ?? model.now
        return formatter.string(from: date)
    }
    private var dateRange: String { "\(weekDate(0, format: "d MMM")) – \(weekDate(6, format: "d MMM"))".uppercased() }
    private func errorBanner(_ message: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle").font(.caption)
            Button(button, action: action).font(.caption)
        }.padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PlatformIcon: View {
    let platform: Platform
    let size: CGFloat
    private var color: Color { Color(red: Double((platform.hex >> 16) & 255) / 255, green: Double((platform.hex >> 8) & 255) / 255, blue: Double(platform.hex & 255) / 255) }
    var body: some View {
        BrandMark(id: platform.id, fallback: platform.symbol).frame(width: size * 0.65, height: size * 0.65)
            .foregroundStyle(color).frame(width: size, height: size)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.29))
            .accessibilityHidden(true)
    }
}
