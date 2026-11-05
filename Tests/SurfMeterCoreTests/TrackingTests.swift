import Foundation
import Testing
@testable import SurfMeterCore

struct TrackingTests {
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value
    }
    var start: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 23, minute: 59, second: 59))! }
    func sample(_ second: Double, platform: String? = "youtube.com", idle: Double = 0, deadline: Double = .infinity) -> TrackingSample {
        .init(monotonic: second, wall: start.addingTimeInterval(second), calendar: calendar, platform: platform, idleSeconds: idle, validUntil: deadline)
    }
    func sum(_ slices: [UsageSlice]) -> Double { slices.reduce(0) { $0 + $1.seconds } }

    @Test func switchesAccountExactlyOnce() {
        var engine = TrackingEngine()
        #expect(engine.advance(sample(0)).isEmpty)
        #expect(sum(engine.advance(sample(1, platform: "reddit.com"))) == 1)
        let slices = engine.advance(sample(2, platform: nil))
        #expect(slices.first?.key.platform == "reddit.com")
        #expect(sum(slices) == 1)
        #expect(engine.advance(sample(3, platform: nil)).isEmpty)
        #expect(engine.advance(sample(4)).isEmpty)
        #expect(sum(engine.advance(sample(5))) == 1)
    }
    @Test func idleCutoffDoesNotBackfillOnInput() {
        var engine = TrackingEngine()
        _ = engine.advance(sample(0, idle: 59.5))
        #expect(sum(engine.advance(sample(1, idle: 60.5))) == 0.5)
        #expect(engine.advance(sample(2, idle: 90)).isEmpty)
        #expect(engine.advance(sample(3, idle: 0)).isEmpty)
        #expect(sum(engine.advance(sample(4, idle: 1))) == 1)
    }
    @Test func staleStateClosesAtItsDeadline() {
        var engine = TrackingEngine()
        _ = engine.advance(sample(0, deadline: 0.25))
        #expect(sum(engine.advance(sample(1, platform: nil))) == 0.25)
        #expect(engine.advance(sample(2, platform: nil)).isEmpty)
    }
    @Test func midnightAndHourlyBucketsSplit() {
        var engine = TrackingEngine()
        _ = engine.advance(sample(0))
        let slices = engine.advance(sample(2))
        #expect(slices.count == 2)
        #expect(slices.map(\.key.day) == ["2026-11-05", "2026-11-06"])
        #expect(slices.map(\.key.hour) == [23, 0])
        #expect(sum(slices) == 2)
    }
    @Test func gapsRestartAndBackwardMonotonicTimeAddNothing() {
        var engine = TrackingEngine()
        _ = engine.advance(sample(0))
        #expect(engine.advance(sample(1000, platform: nil)).isEmpty)
        #expect(engine.advance(sample(1)).isEmpty)
        engine.reset()
        #expect(engine.advance(sample(4000)).isEmpty)
    }
    @Test func wallClockAndTimeZoneDoNotInflateDurationOrRewritePast() {
        var engine = TrackingEngine()
        _ = engine.advance(sample(0))
        var changed = sample(1)
        changed.wall = start.addingTimeInterval(86400)
        changed.calendar.timeZone = TimeZone(secondsFromGMT: 3600)!
        let slices = engine.advance(changed)
        #expect(sum(slices) == 1)
        #expect(slices.first?.key.day == "2026-11-05")
        let next = TrackingSample(monotonic: 2, wall: changed.wall.addingTimeInterval(1), calendar: changed.calendar, platform: "youtube.com")
        #expect(sum(engine.advance(next)) == 1)
    }
    @Test func pauseSleepLockAndBackgroundGateEligibility() throws {
        let classifier = try DomainClassifier.bundled()
        var eligibility = TrackingEligibility()
        eligibility.enabled = true; eligibility.foreground = .chrome
        let message = BrowserState(browser: .chrome, sessionID: UUID(), sequence: 1, state: .active, hostname: "www.youtube.com")
        let snapshots = [Browser.chrome: BrowserSnapshot(message: message, received: 0, foregroundGeneration: 0)]
        #expect(eligibility.platform(at: 1, snapshots: snapshots, classifier: classifier).platform == "youtube.com")
        eligibility.paused = true
        #expect(eligibility.platform(at: 1, snapshots: snapshots, classifier: classifier).platform == nil)
        eligibility.paused = false; eligibility.systemActive = false
        #expect(eligibility.platform(at: 1, snapshots: snapshots, classifier: classifier).platform == nil)
        eligibility.systemActive = true; eligibility.foreground = .safari
        #expect(eligibility.platform(at: 1, snapshots: snapshots, classifier: classifier).platform == nil)
        eligibility.foreground = .chrome; eligibility.generation = 1
        #expect(eligibility.platform(at: 1, snapshots: snapshots, classifier: classifier).platform == nil)
        eligibility.generation = 0
        #expect(eligibility.platform(at: 8, snapshots: snapshots, classifier: classifier).platform == nil)
        eligibility.excluded = ["youtube.com"]
        #expect(eligibility.platform(at: 1, snapshots: snapshots, classifier: classifier).platform == nil)
    }
    @Test func privateAndUnavailableNeverQualify() throws {
        let classifier = try DomainClassifier.bundled()
        var eligibility = TrackingEligibility(); eligibility.enabled = true; eligibility.foreground = .chrome
        for state in [ActivityState.inactive, .unavailable] {
            let message = BrowserState(browser: .chrome, sessionID: UUID(), sequence: 0, state: state)
            #expect(eligibility.platform(at: 1, snapshots: [.chrome: .init(message: message, received: 0, foregroundGeneration: 0)], classifier: classifier).platform == nil)
        }
    }
    @Test func publicSuffixWildcardsExceptionsAndAliases() throws {
        let classifier = try DomainClassifier.bundled()
        #expect(classifier.platform(for: "m.youtube.com") == "youtube.com")
        #expect(classifier.platform(for: "youtube.com.example.org") == "example.org")
        #expect(classifier.platform(for: "mobile.twitter.com") == "x.com")
        #expect(classifier.platform(for: "youtu.be") == "youtube.com")
        #expect(classifier.platform(for: "news.example.co.uk") == "example.co.uk")
        #expect(classifier.platform(for: "a.alice.github.io") == "alice.github.io")
        #expect(classifier.platform(for: "b.bob.github.io") == "bob.github.io")
        #expect(classifier.registrableDomain("a.b.ck") == "a.b.ck")
        #expect(classifier.registrableDomain("a.www.ck") == "www.ck")
        #expect(!DomainClassifier.matches("notyoutube.com", domain: "youtube.com"))
        #expect(DomainClassifier.exclusion("https://example.org/private") == nil)
    }
    @Test func comparisonsUseSecondsBeforeRoundingAndIncludeYesterdayOnlyRows() {
        var ledger = UsageLedger()
        ledger.add([.init(key: .init(day: "2026-11-05", hour: 1, platform: "reddit.com"), seconds: 60)])
        let rows = ledger.rows(days: ["2026-11-06"], compare: ["2026-11-05"])
        #expect(rows.count == 1)
        #expect(rows[0].seconds == 0 && rows[0].delta == -60)
        #expect(UsageFormat.duration(1) == "<1m")
        #expect(UsageFormat.change(-0.5) == "↓ <1m less")
        #expect(UsageFormat.change(0) == "Same")
        #expect(UsageFormat.change(120) == "↑ 2m more")
    }
    @Test func dstDaysUseCalendarBoundaries() {
        var calendar = self.calendar
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 59, second: 59))!
        let slices = LocalDay.split(start: start, seconds: 2, platform: "example.org", calendar: calendar)
        #expect(sum(slices) == 2)
        #expect(slices.map(\.key.hour) == [1, 3])
    }
    @MainActor @Test func storageSurvivesReopenRetentionAndDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sm-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        var ledger = UsageLedger()
        ledger.add([.init(key: .init(day: "2026-11-05", hour: 1, platform: "youtube.com"), seconds: 90), .init(key: .init(day: "2026-11-06", hour: 2, platform: "reddit.com"), seconds: 45)])
        ledger.mark(day: "2026-11-05", reason: "paused")
        do { let store = try UsageStore(directory: directory); try store.save(ledger) }
        let store = try UsageStore(directory: directory)
        #expect(try store.load().total(days: ["2026-11-05"]) == 90)
        #expect(try store.load().coverage["2026-11-05"] == ["paused"])
        ledger.retain(since: "2026-11-06")
        try store.save(ledger)
        #expect(try store.load().total(days: ["2026-11-05"]) == 0)
        try store.save(UsageLedger())
        #expect(try store.load().buckets.isEmpty)
    }
    @Test func weeklyQueriesAndRetentionAgree() {
        var ledger = UsageLedger()
        let days = LocalDay.recent(8, now: start, calendar: calendar)
        for day in days {
            ledger.add([.init(key: .init(day: day, hour: 1, platform: "reddit.com"), seconds: 60), .init(key: .init(day: day, hour: 2, platform: "youtube.com"), seconds: 120)])
        }
        let week = Array(days.suffix(7))
        #expect(ledger.total(days: week) == 1260)
        #expect(ledger.rows(days: week).reduce(0) { $0 + $1.seconds } == 1260)
        #expect(ledger.total(days: week) / 7 == 180)
        ledger.retain(since: week[0])
        #expect(ledger.total(days: [days[0]]) == 0)
        #expect(ledger.total(days: week) == 1260)
    }
    @MainActor @Test func invalidStorageLocationFailsWithoutReplacingTheFile() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("sm-invalid-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        let marker = Data("preserve this file".utf8)
        try marker.write(to: file)
        #expect(throws: (any Error).self) { _ = try UsageStore(directory: file) }
        #expect(try Data(contentsOf: file) == marker)
    }

}
