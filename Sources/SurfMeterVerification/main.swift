import Foundation
import SurfMeterCore

@main
struct Verification {
    @MainActor static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/private/tmp/surfmeter-verification-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 23, minute: 55))!
        var engine = TrackingEngine(), ledger = UsageLedger()
        for second in 0...600 {
            ledger.add(engine.advance(.init(monotonic: Double(second), wall: start.addingTimeInterval(Double(second)), calendar: calendar, platform: "youtube.com")))
        }
        guard ledger.total(days: ["2026-11-05"]) == 300, ledger.total(days: ["2026-11-06"]) == 300 else { fatalError("Midnight accounting failed") }
        do { let store = try UsageStore(directory: directory); try store.save(ledger) }
        let store = try UsageStore(directory: directory)
        let restored = try store.load()
        guard restored.total(days: ["2026-11-05", "2026-11-06"]) == 600 else { fatalError("Restart recovery failed") }
        var retained = restored
        retained.retain(since: "2026-11-06")
        try store.save(retained)
        guard try store.load().total(days: ["2026-11-05"]) == 0 else { fatalError("Retention failed") }
        try store.save(UsageLedger())
        guard try store.load().buckets.isEmpty else { fatalError("Deletion failed") }
        print("PASS: 10-minute simulated tracking, midnight/hour buckets, disk recovery, retention, deletion (not a real-browser accuracy test)")
    }
}
