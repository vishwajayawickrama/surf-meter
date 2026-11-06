import SwiftUI

/// Calendar arithmetic follows local calendar days, including DST and locale week starts.
struct ActivityMonth {
    var calendar: Calendar
    var date: Date
    var latest: Date
    var start: Date { calendar.dateInterval(of: .month, for: date)!.start }
    var dates: [Date] {
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let first = calendar.date(byAdding: .day, value: -offset, to: start)!
        return (0..<42).map { calendar.date(byAdding: .day, value: $0, to: first)! }
    }
    var weekdays: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }
    func shifted(_ value: Int) -> Date { calendar.date(byAdding: .month, value: value, to: start)! }
    func available(_ date: Date) -> Bool { calendar.startOfDay(for: date) <= calendar.startOfDay(for: latest) }
    var canGoForward: Bool { available(shifted(1)) }
    func movedDay(from date: Date, by offset: Int) -> Date? {
        guard let next = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)), available(next) else { return nil }
        return next
    }
    var title: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: start)
    }
}

struct ActivityCalendar: View {
    @Binding var date: Date
    let latest: Date
    let weekly: Bool
    let calendar: Calendar
    var done: () -> Void
    @ViewState private var month: Date
    @ViewState private var hovered: Date?
    @FocusState private var focusedDay: Date?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.layoutDirection) private var layoutDirection
    private var palette: SurfPalette { SurfPalette(dark: scheme == .dark) }
    private var grid: ActivityMonth { ActivityMonth(calendar: calendar, date: month, latest: latest) }

    init(date: Binding<Date>, latest: Date, weekly: Bool, calendar: Calendar = .autoupdatingCurrent, done: @escaping () -> Void) {
        _date = date
        self.latest = latest; self.weekly = weekly; self.calendar = calendar; self.done = done
        _month = ViewState(wrappedValue: calendar.dateInterval(of: .month, for: date.wrappedValue)!.start)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(weekly ? "WEEK ENDING" : "CHOOSE A DAY").font(.system(size: 10, weight: .semibold)).tracking(1.1).foregroundStyle(palette.muted)
                    Text(grid.title).font(.system(size: 20, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85).accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 8)
                monthButton("chevron.backward", title: "Previous month", disabled: false) { month = grid.shifted(-1); focusedDay = month }
                monthButton("chevron.forward", title: "Next month", disabled: !grid.canGoForward) { month = grid.shifted(1); focusedDay = month }
            }
            VStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(grid.weekdays[index]).font(.system(size: 10, weight: .medium)).foregroundStyle(palette.muted)
                            .frame(maxWidth: .infinity).accessibilityHidden(true)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(grid.dates, id: \.self) { day in dayButton(day) }
                }
            }
            Rectangle().fill(palette.line).frame(height: 1)
            HStack {
                Button {
                    date = calendar.startOfDay(for: latest)
                    focusedDay = date
                    month = calendar.dateInterval(of: .month, for: latest)!.start
                } label: { Label("Today", systemImage: "calendar.badge.clock").foregroundStyle(palette.text) }
                Spacer()
                Button(action: done) { Text("Done").fontWeight(.semibold) }
                    .modifier(DesktopGlassProminentButton()).keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 336).foregroundStyle(palette.text)
            .background(palette.solid).modifier(DesktopGlassButtons())
            .onAppear { focusedDay = calendar.startOfDay(for: date) }
            .onMoveCommand { direction in
                let step: Int
                switch direction { case .left: step = layoutDirection == .rightToLeft ? 1 : -1; case .right: step = layoutDirection == .rightToLeft ? -1 : 1; case .up: step = -7; case .down: step = 7; default: return }
                guard let next = grid.movedDay(from: focusedDay ?? date, by: step) else { return }
                date = next
                month = calendar.dateInterval(of: .month, for: next)!.start
                focusedDay = next
            }
    }
    private func monthButton(_ symbol: String, title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.text)
                .frame(width: 30, height: 30).background(palette.control, in: Circle()).contentShape(Circle())
        }.buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.3 : 1).accessibilityLabel(title).help(title)
    }
    private func dayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: date)
        let today = calendar.isDate(day, inSameDayAs: latest)
        let currentMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let enabled = grid.available(day)
        let rangeStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: date))!
        let inWeek = weekly && day >= rangeStart && day <= calendar.startOfDay(for: date)
        return Button {
            date = calendar.startOfDay(for: day)
            focusedDay = date
            if !currentMonth { month = calendar.dateInterval(of: .month, for: day)!.start }
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 13, weight: selected || today ? .semibold : .regular)).monospacedDigit()
                .foregroundStyle(selected ? Color.white : currentMonth ? palette.text : palette.muted)
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(inWeek && !selected ? palette.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9))
                .background {
                    if selected { Circle().fill(palette.accent).frame(width: 36, height: 36) }
                    else if hovered == day && enabled { Circle().fill(palette.control).frame(width: 36, height: 36) }
                }
                .overlay { if today && !selected { Circle().strokeBorder(palette.accent, lineWidth: 1.5).frame(width: 34, height: 34) } }
                .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!enabled)
            .focusable()
            .focused($focusedDay, equals: day)
            .onHover { hovered = $0 ? day : nil }
            .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + (today ? ", today" : ""))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
