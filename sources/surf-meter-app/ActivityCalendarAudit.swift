import Foundation

@MainActor enum ActivityCalendarAudit {
    static func verify() {
        func check(_ value: @autoclosure () -> Bool, _ name: String) {
            guard value() else { fputs("FAIL: \(name)\n", stderr); exit(1) }
            print("PASS: \(name)")
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func day(_ year: Int, _ month: Int, _ date: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: date))!
        }
        let latest = day(2026, 11, 6)
        for firstWeekday in [1,2,7] {
            calendar.firstWeekday = firstWeekday
            for month in 1...12 {
                let grid = ActivityMonth(calendar: calendar, date: day(2024, month, 15), latest: latest)
                check(grid.dates.count == 42 && calendar.component(.weekday, from: grid.dates[0]) == firstWeekday &&
                      grid.dates.filter { calendar.isDate($0, equalTo: grid.start, toGranularity: .month) }.count == calendar.range(of: .day, in: .month, for: grid.start)!.count,
                      "month \(month), week start \(firstWeekday): six aligned rows")
            }
        }
        let leap = ActivityMonth(calendar: calendar, date: day(2024,2,15), latest: latest)
        check(leap.dates.contains(day(2024,2,29)), "leap day appears in February")
        let december = ActivityMonth(calendar: calendar, date: day(2025,12,31), latest: latest)
        check(december.shifted(1) == day(2026,1,1), "month navigation crosses the year correctly")
        let current = ActivityMonth(calendar: calendar, date: latest, latest: latest)
        check(current.available(latest) && !current.available(day(2026,11,7)), "today selectable, future days disabled")
        check(!current.canGoForward, "future month navigation disabled")
        check(current.movedDay(from: latest, by: 1) == nil && current.movedDay(from: latest, by: -1) == day(2026,11,5), "keyboard steps obey the latest date")
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let march = ActivityMonth(calendar: calendar, date: day(2026,3,8), latest: latest)
        check(zip(march.dates, march.dates.dropFirst()).allSatisfy { a,b in calendar.dateComponents([.day], from: a, to: b).day == 1 }, "DST grid advances in calendar days")
    }
}
