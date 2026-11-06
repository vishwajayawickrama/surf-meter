import Foundation

public struct BucketKey: Hashable, Codable, Sendable {
    public let day: String
    public let hour: Int
    public let platform: String
    public init(day: String, hour: Int, platform: String) { self.day = day; self.hour = hour; self.platform = platform }
    public var id: String { "\(day)|\(hour)|\(platform)" }
}

public struct UsageSlice: Equatable, Sendable {
    public let key: BucketKey
    public let seconds: Double
    public init(key: BucketKey, seconds: Double) { self.key = key; self.seconds = seconds }
}

public enum LocalDay {
    public static func key(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    public static func recent(_ count: Int, now: Date, calendar: Calendar) -> [String] {
        (0..<count).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }.map { key($0, calendar: calendar) }
    }
    public static func split(start: Date, seconds: Double, platform: String, calendar: Calendar) -> [UsageSlice] {
        guard seconds.isFinite, seconds > 0 else { return [] }
        var cursor = start
        let end = start.addingTimeInterval(seconds)
        var slices: [UsageSlice] = []
        while cursor < end {
            let boundary = calendar.dateInterval(of: .hour, for: cursor)?.end ?? end
            let next = min(end, boundary)
            guard next > cursor else { break }
            slices.append(.init(key: .init(day: key(cursor, calendar: calendar), hour: calendar.component(.hour, from: cursor), platform: platform), seconds: next.timeIntervalSince(cursor)))
            cursor = next
        }
        return slices
    }
}

public struct UsageRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let seconds: Double
    public let comparison: Double
    public var platform: Platform { .named(id) }
    public var delta: Double { seconds - comparison }
}

public struct UsageLedger: Sendable {
    public var buckets: [BucketKey: Double] = [:]
    public var coverage: [String: Set<String>] = [:]
    public init() {}
    public mutating func add(_ slices: [UsageSlice]) {
        for slice in slices where slice.seconds.isFinite && slice.seconds > 0 {
            buckets[slice.key, default: 0] += slice.seconds
        }
    }
    public mutating func mark(day: String, reason: String) { coverage[day, default: []].insert(reason) }
    public mutating func retain(since day: String) {
        buckets = buckets.filter { $0.key.day >= day }
        coverage = coverage.filter { $0.key >= day }
    }
    public func total(days: [String], platform: String? = nil, hour: Int? = nil) -> Double {
        let days = Set(days)
        return buckets.reduce(0) { total, entry in
            total + (days.contains(entry.key.day) && (platform == nil || entry.key.platform == platform) && (hour == nil || entry.key.hour == hour) ? entry.value : 0)
        }
    }
    public func rows(days: [String], compare: [String] = []) -> [UsageRow] {
        let relevant = Set(days + compare)
        let platforms = Set(buckets.keys.filter { relevant.contains($0.day) }.map(\.platform))
        return platforms.map { UsageRow(id: $0, seconds: total(days: days, platform: $0), comparison: total(days: compare, platform: $0)) }
            .sorted { $0.seconds == $1.seconds ? $0.platform.name.localizedStandardCompare($1.platform.name) == .orderedAscending : $0.seconds > $1.seconds }
    }
}

public enum UsageFormat {
    public static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0m" }
        if seconds < 60 { return "<1m" }
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes)m" : minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
    public static func change(_ delta: Double) -> String {
        if abs(delta) < 0.000_001 { return "Same" }
        return "\(delta < 0 ? "↓" : "↑") \(duration(abs(delta))) \(delta < 0 ? "less" : "more")"
    }
}
