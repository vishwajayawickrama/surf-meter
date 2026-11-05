import Foundation

public struct TrackingSample: Sendable {
    public var monotonic: Double
    public var wall: Date
    public var calendar: Calendar
    public var platform: String?
    public var idleSeconds: Double
    public var validUntil: Double
    public init(monotonic: Double, wall: Date, calendar: Calendar, platform: String?, idleSeconds: Double = 0, validUntil: Double = .infinity) {
        self.monotonic = monotonic; self.wall = wall; self.calendar = calendar
        self.platform = platform; self.idleSeconds = idleSeconds; self.validUntil = validUntil
    }
}

/// Deterministic accounting. The caller resolves native/browser/pause/exclusion eligibility.
/// Every transition checkpoints the old sample, then supplies the new eligibility state.
public struct TrackingEngine: Sendable {
    private var previous: TrackingSample?
    public let idleThreshold: Double
    public let maximumGap: Double
    public init(idleThreshold: Double = 60, maximumGap: Double = 5) {
        self.idleThreshold = idleThreshold; self.maximumGap = maximumGap
    }
    public mutating func reset() { previous = nil }

    public mutating func advance(_ sample: TrackingSample) -> [UsageSlice] {
        defer { previous = sample }
        guard let previous, let platform = previous.platform else { return [] }
        let elapsed = sample.monotonic - previous.monotonic
        guard elapsed.isFinite, elapsed > 0, elapsed <= maximumGap,
              previous.idleSeconds.isFinite, previous.idleSeconds >= 0 else { return [] }
        let eligible = max(0, min(elapsed, idleThreshold - previous.idleSeconds, previous.validUntil - previous.monotonic))
        return LocalDay.split(start: previous.wall, seconds: eligible, platform: platform, calendar: previous.calendar)
    }
}

public struct BrowserSnapshot: Sendable {
    public let message: BrowserState
    public let received: Double
    public let foregroundGeneration: UInt64
    public init(message: BrowserState, received: Double, foregroundGeneration: UInt64) {
        self.message = message; self.received = received; self.foregroundGeneration = foregroundGeneration
    }
}

public struct TrackingEligibility: Sendable {
    public var foreground: Browser?
    public var generation: UInt64 = 0
    public var enabled = false
    public var paused = false
    public var systemActive = true
    public var excluded: [String] = []
    public var freshness: Double = 7
    public init() {}
    public func platform(at now: Double, snapshots: [Browser: BrowserSnapshot], classifier: DomainClassifier) -> (platform: String?, deadline: Double) {
        guard enabled, !paused, systemActive, let foreground, let snapshot = snapshots[foreground],
              snapshot.foregroundGeneration == generation, now >= snapshot.received, now < snapshot.received + freshness,
              snapshot.message.state == .active, let hostname = snapshot.message.hostname,
              !excluded.contains(where: { DomainClassifier.matches(hostname, domain: $0) || classifier.platform(for: hostname) == $0 }) else { return (nil, now) }
        return (classifier.platform(for: hostname), snapshot.received + freshness)
    }
}
