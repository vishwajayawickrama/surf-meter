import SwiftUI
import AppKit
import ServiceManagement
import SurfMeterCore

struct Preferences: Codable {
    var enabled = false
    var paused = false
    var excluded: [String] = []
    var retention = 30
    var appearance = "system"
}

enum Screen { case activity, preferences, setup }

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var ledger = UsageLedger()
    @Published private(set) var preferences: Preferences
    @Published private(set) var snapshots: [Browser: BrowserSnapshot] = [:]
    @Published var storageError: String?
    @Published var setupMessage: String?
    @Published var bridgeError: String?
    @Published var status = "Set up your browser"
    @Published var screen: Screen = .activity
    @Published var now = Date()
    @Published var loginEnabled = false
    @Published var loginMessage: String?
    let demo: Bool
    let simulation: Bool
    private let classifier: DomainClassifier?
    private var engine = TrackingEngine()
    private var store: UsageStore?
    private var eligibility = TrackingEligibility()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var distributed: [NSObjectProtocol] = []
    private let defaults: UserDefaults?
    private var lastSave = ProcessInfo.processInfo.systemUptime
    private var dirty = false
    private var sleeping = false
    private var screenAsleep = false
    private var sessionInactive = false
    private var locked = false
    private var lastZone = TimeZone.current.identifier
    private var lastWall = Date()
    private var lastMono = ProcessInfo.processInfo.systemUptime
    private let bridgeDirectory: URL

    var calendar: Calendar { Calendar.autoupdatingCurrent }
    var today: String { LocalDay.key(now, calendar: calendar) }
    var yesterday: String { LocalDay.recent(2, now: now, calendar: calendar)[0] }
    var week: [String] { LocalDay.recent(7, now: now, calendar: calendar) }
    var todayTotal: Double { ledger.total(days: [today]) }
    var menuLabel: String { preferences.paused ? "Paused" : UsageFormat.duration(todayTotal) }
    var hasConnection: Bool { snapshots[.chrome].map { ProcessInfo.processInfo.systemUptime - $0.received < 3 } ?? false }
    var colorScheme: ColorScheme? { preferences.appearance == "light" ? .light : preferences.appearance == "dark" ? .dark : nil }

    init(demo: Bool = false) {
        self.demo = demo
        let args = CommandLine.arguments
        let isolated = args.firstIndex(of: "--bridge-directory").flatMap { args.indices.contains($0 + 1) ? URL(fileURLWithPath: args[$0 + 1]) : nil }
        simulation = isolated != nil && args.contains("--simulate-chrome")
        bridgeDirectory = isolated ?? LocalBridge.defaultDirectory
        defaults = demo || isolated != nil ? nil : .standard
        preferences = defaults?.data(forKey: "preferences").flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
        classifier = try? DomainClassifier.bundled()
        if simulation { preferences.enabled = true }
        if demo {
            seedPreview()
            status = "Preview · sample activity"
            return
        }
        do {
            store = try UsageStore(directory: bridgeDirectory.appendingPathComponent("Data"))
            ledger = try store!.load()
            prune()
            ledger.mark(day: today, reason: "partial")
            dirty = true
        } catch { storageError = "Activity storage could not open. Recording is stopped. Quit and reopen, or check disk access." }
        loginEnabled = SMAppService.mainApp.status == .enabled
        refreshEligibility()
        if !simulation { installObservers() }
        startBridge()
        pulse()
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pulse() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func record() {
        guard !demo else { return }
        now = Date()
        let mono = ProcessInfo.processInfo.systemUptime
        // Unexpected scheduling gaps and clock/zone jumps cannot generate synthetic usage.
        if mono - lastMono > 5 || lastZone != TimeZone.current.identifier || abs(now.timeIntervalSince(lastWall) - (mono - lastMono)) > 2 {
            engine.reset()
            snapshots.removeAll()
            ledger.mark(day: today, reason: "interrupted")
            dirty = true
        }
        lastMono = mono; lastWall = now; lastZone = TimeZone.current.identifier
        let resolved = classifier.map { eligibility.platform(at: mono, snapshots: snapshots, classifier: $0) } ?? (platform: nil, deadline: mono)
        let idle = simulation ? 0 : CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        let slices = engine.advance(.init(monotonic: mono, wall: now, calendar: calendar, platform: storageError == nil ? resolved.platform : nil, idleSeconds: idle, validUntil: resolved.deadline))
        if !slices.isEmpty {
            ledger.add(slices)
            for slice in slices { ledger.mark(day: slice.key.day, reason: "recorded") }
            dirty = true
        }
        if !preferences.enabled { status = "Set up your browser" }
        else if preferences.paused { status = "Paused"; mark("paused") }
        else if storageError != nil { status = "Storage unavailable"; mark("storage") }
        else if !eligibility.systemActive { status = "Screen inactive" }
        else if idle >= 60 { status = "Idle" }
        else if let platform = resolved.platform { status = "Tracking \(Platform.named(platform).name)" }
        else if eligibility.foreground == .chrome && !hasConnection { status = "Chrome disconnected"; mark("unavailable") }
        else { status = "Waiting for active browsing" }
        if simulation { status = "Simulation · " + status }
    }

    private func pulse() {
        refreshEligibility()
        record()
        if ProcessInfo.processInfo.systemUptime - lastSave >= 10 { checkpoint() }
    }

    private func mark(_ reason: String) {
        if ledger.coverage[today]?.contains(reason) != true { ledger.mark(day: today, reason: reason); dirty = true }
    }

    private func refreshEligibility() {
        eligibility.foreground = simulation || NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.google.Chrome" ? .chrome : nil
        eligibility.enabled = preferences.enabled
        eligibility.paused = preferences.paused
        eligibility.excluded = preferences.excluded
        eligibility.freshness = 2
        // CGSession screen-lock key is a supplemental OS signal, pending release validation.
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        let onConsole = session?[kCGSessionOnConsoleKey as String] as? Bool ?? false
        let dictionaryLocked = session?["CGSSessionScreenIsLocked"] as? Bool ?? false
        eligibility.systemActive = simulation || (onConsole && !dictionaryLocked && !locked && !sleeping && !screenAsleep && !sessionInactive)
    }

    private func transition(_ change: () -> Void, invalidate: Bool = false) {
        record()
        change()
        if invalidate { eligibility.generation &+= 1; snapshots.removeAll() }
        refreshEligibility()
        record()
    }

    private func installObservers() {
        distributed.append(DistributedNotificationCenter.default().addObserver(forName: SetupCommand.preferencesChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, let defaults = self.defaults else { return }
                defaults.synchronize()
                guard let data = defaults.data(forKey: "preferences"), let saved = try? JSONDecoder().decode(Preferences.self, from: data) else { return }
                self.transition({ self.preferences = saved }, invalidate: true)
                self.loginEnabled = SMAppService.mainApp.status == .enabled
                self.checkpoint()
            }
        })
        let center = NSWorkspace.shared.notificationCenter
        func observe(_ name: Notification.Name, _ handler: @escaping () -> Void) {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in Task { @MainActor in handler() } })
        }
        observe(NSWorkspace.didActivateApplicationNotification) { [weak self] in
            self?.transition({}, invalidate: true)
        }
        observe(NSWorkspace.willSleepNotification) { [weak self] in
            guard let self else { return }; self.transition({ self.sleeping = true }, invalidate: true); self.checkpoint()
        }
        observe(NSWorkspace.didWakeNotification) { [weak self] in
            guard let self else { return }; self.transition({ self.sleeping = false }, invalidate: true)
        }
        observe(NSWorkspace.screensDidSleepNotification) { [weak self] in
            guard let self else { return }; self.transition({ self.screenAsleep = true }, invalidate: true); self.checkpoint()
        }
        observe(NSWorkspace.screensDidWakeNotification) { [weak self] in
            guard let self else { return }; self.transition({ self.screenAsleep = false }, invalidate: true)
        }
        observe(NSWorkspace.sessionDidResignActiveNotification) { [weak self] in
            guard let self else { return }; self.transition({ self.sessionInactive = true }, invalidate: true); self.checkpoint()
        }
        observe(NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] in
            guard let self else { return }; self.transition({ self.sessionInactive = false }, invalidate: true)
        }
        for (name, value) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            distributed.append(DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }; self.transition({ self.locked = value }, invalidate: true); self.checkpoint()
                }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.record(); self?.checkpoint() }
        })
    }

    private func startBridge() {
        let directory = bridgeDirectory
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try LocalBridge.serve(directory: directory) { message in
                    DispatchQueue.main.sync {
                        guard let self, message.browser == .chrome else { return false }
                        if let prior = self.snapshots[message.browser], prior.message.sessionID == message.sessionID,
                           message.sequence <= prior.message.sequence { return false }
                        self.record()
                        self.snapshots[message.browser] = .init(message: message, received: ProcessInfo.processInfo.systemUptime, foregroundGeneration: self.eligibility.generation)
                        self.refreshEligibility()
                        self.record()
                        return true
                    }
                }
            } catch {
                DispatchQueue.main.async { self?.bridgeError = "Browser bridge unavailable. Quit any other SurfMeter instance and reopen." }
            }
        }
    }

    func changePreferences(_ edit: (inout Preferences) -> Void) {
        if demo { edit(&preferences); return }
        transition { edit(&preferences) }
        if let data = try? JSONEncoder().encode(preferences) { defaults?.set(data, forKey: "preferences") }
        checkpoint()
    }
    func addExclusion(_ input: String) -> Bool {
        guard let normalized = DomainClassifier.exclusion(input) else { return false }
        let mapped = classifier?.platform(for: normalized) ?? normalized
        let domain = Platform.catalog.contains(where: { $0.id == mapped }) ? mapped : normalized
        changePreferences { if !$0.excluded.contains(domain) { $0.excluded.append(domain); $0.excluded.sort() } }
        return true
    }
    func checkpoint() {
        guard !demo, let store else { return }
        prune()
        guard dirty else { lastSave = ProcessInfo.processInfo.systemUptime; return }
        do { try store.save(ledger); dirty = false; storageError = nil; lastSave = ProcessInfo.processInfo.systemUptime }
        catch { engine.reset(); snapshots.removeAll(); storageError = "Activity could not be saved. Recording is stopped; your unsaved totals remain in memory. Check disk space and retry." }
    }
    private func prune() {
        let cutoff = LocalDay.recent(max(7, preferences.retention), now: now, calendar: calendar).first!
        ledger.retain(since: cutoff)
    }
    func deleteActivity() {
        record()
        guard let store, !demo else { ledger = UsageLedger(); return }
        let cleared = UsageLedger()
        do {
            try store.save(cleared) // Publish deletion only after the durable transaction succeeds.
            ledger = cleared; dirty = false; storageError = nil
            engine.reset(); snapshots.removeAll(); record()
        } catch { storageError = "Activity could not be deleted. No totals were cleared. Check disk access and retry." }
    }
    func toggleLogin(_ enabled: Bool) {
        guard !demo else { return }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            loginMessage = SMAppService.mainApp.status == .requiresApproval ? "Approve SurfMeter in System Settings → Login Items." : nil
        } catch { loginMessage = "Could not change login settings. Keep SurfMeter in Applications and try again. Signing may be required." }
    }
    func revealExtension() {
        let path = Bundle.main.resourceURL!.appendingPathComponent("ChromeExtension")
        if FileManager.default.fileExists(atPath: path.path) { NSWorkspace.shared.selectFile(path.path, inFileViewerRootedAtPath: path.deletingLastPathComponent().path) }
        else { setupMessage = "The extension is missing from this build. Run the extension build and rebuild SurfMeter." }
    }
    func registerChrome(_ id: String) {
        do {
            try ChromeInstaller.install(extensionID: id)
            setupMessage = "Chrome registered. Open a normal web page, then click SurfMeter’s extension button to connect."
        } catch ProtocolError.invalidOrigin { setupMessage = "Paste the 32-letter extension ID from Chrome." }
        catch { setupMessage = "Could not register Chrome. An existing SurfMeter registration may need removal; see the development guide." }
    }
    func retryStorage() {
        if store == nil {
            do {
                let reopened = try UsageStore(directory: bridgeDirectory.appendingPathComponent("Data"))
                ledger = try reopened.load(); store = reopened
                storageError = nil; engine.reset(); snapshots.removeAll()
                mark("partial"); dirty = true
            } catch { storageError = "Activity storage is still unavailable. Check disk access and reopen SurfMeter."; return }
        }
        checkpoint()
    }
    func quit() { record(); checkpoint(); NSApplication.shared.terminate(nil) }
    private func seedPreview() {
        preferences.enabled = true
        let days = week
        for (index, day) in days.enumerated() {
            for (offset, platform) in Platform.catalog.prefix(5).enumerated() {
                let multiplier = index == days.count - 1 && offset.isMultiple(of: 2) ? 0.7 : 1.0
                let seconds = Double((index + 2) * (6 - offset) * 113) * multiplier
                ledger.add([.init(key: .init(day: day, hour: 9 + offset, platform: platform.id), seconds: seconds)])
            }
            ledger.mark(day: day, reason: "partial")
        }
    }
}
