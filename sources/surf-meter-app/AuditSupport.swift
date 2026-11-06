import AppKit
import SwiftUI
import SurfMeterCore

/// Explicit opt-in checks. Never use the normal preferences, database, or bridge.
@MainActor enum AuditSupport {
    static func showWindow(model: AppModel) -> Never {
        precondition(model.demo)
        let host = NSHostingView(rootView: AuditRoot(model: model))
        let window = NSWindow(contentRect: NSRect(x: 200, y: 120, width: 390, height: MenuPanelLayout.activityHeight), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "SurfMeter — Isolated UI audit"
        window.contentView = host
        window.isReleasedWhenClosed = false
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.run()
        exit(0)
    }
    static func verifyModel() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("surfmeter-model-audit-\(UUID().uuidString)")
        let suite = "dev.surfmeter.audit.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            guard condition() else { fputs("FAIL: \(name)\n", stderr); exit(1) }
            print("PASS: \(name)")
        }
        do {
            let fresh = AppModel(verificationDirectory: directory.appendingPathComponent("fresh"), verificationDefaults: defaults, startsServices: false)
            check(fresh.needsOnboarding, "fresh install requires walkthrough")
            fresh.completeOnboarding()
            check(!fresh.needsOnboarding, "deferred setup persists without enabling recording")
            check(!fresh.preferences.enabled, "walkthrough does not opt into recording")
            defaults.removeObject(forKey: "setupCompleted")
            fresh.changePreferences { $0.enabled = true }
            check(!fresh.needsOnboarding, "existing recording users skip first-run walkthrough")
            fresh.changePreferences { $0.enabled = false }
            defaults.removeObject(forKey: "preferences")
            let calendar = Calendar.autoupdatingCurrent
            let days = LocalDay.recent(16, now: Date(), calendar: calendar)
            var seed = UsageLedger()
            for (day, seconds) in [(days[0], 600.0), (days[7], 1200), (days[14], 2400), (days[15], 1800)] {
                seed.add([.init(key: .init(day: day, hour: 9, platform: "youtube.com"), seconds: seconds)])
                seed.mark(day: day, reason: "recorded")
            }
            let dataDirectory = directory.appendingPathComponent("Data")
            try UsageStore(directory: dataDirectory).save(seed)
            let model = AppModel(verificationDirectory: directory, verificationDefaults: defaults, startsServices: false)
            model.checkpoint() // Clear the dirty flag before testing idle retention.
            check(model.todayTotal == 1800, "model restores stored totals")
            check(model.ledger.total(days: [model.yesterday]) == 2400, "yesterday is independent of today")
            check(model.ledger.total(days: model.week) == 4200, "seven-day total excludes older days")
            check(model.menuLabel == "30m", "menu total uses today only")
            model.changePreferences { $0.retention = 7 }
            let retained = try UsageStore(directory: dataDirectory).load()
            check(retained.buckets.count == 2 && retained.coverage[days[0]] == nil && retained.coverage[days[7]] == nil, "idle retention removes expired buckets AND coverage from disk immediately")
            check(model.addExclusion("  WWW.YouTube.com.  "), "exclusion normalizes case and platform subdomains")
            check(model.preferences.excluded == ["youtube.com"], "platform exclusion is canonical")
            check(model.addExclusion("youtu.be"), "alias exclusion is accepted")
            check(model.preferences.excluded.count == 1, "alias exclusion is deduplicated")
            check(!model.addExclusion("https://example.com/private?q=secret"), "URL/path is rejected by domain exclusion")
            check(model.preferences.excluded == ["youtube.com"], "invalid exclusion leaves preferences unchanged")
            model.changePreferences { $0.enabled = true; $0.paused = true }
            check(model.menuLabel == "Paused" && model.todayTotal == 1800, "pause changes menu without clearing totals")
            model.changePreferences { $0.paused = false }
            check(model.menuLabel == "30m", "resume restores today's menu total")
            model.changePreferences { $0.appearance = "dark" }
            model.deleteActivity()
            let cleared = try UsageStore(directory: dataDirectory).load()
            check(cleared.buckets.isEmpty && cleared.coverage.isEmpty, "deletion clears durable buckets and coverage")
            check(model.preferences.enabled && !model.preferences.paused && model.preferences.appearance == "dark" && model.preferences.excluded == ["youtube.com"], "deletion preserves recording and appearance preferences")
            let reopened = AppModel(verificationDirectory: directory, verificationDefaults: defaults, startsServices: false)
            check(reopened.todayTotal == 0 && reopened.ledger.buckets.isEmpty, "deleted totals stay deleted on model reopen")
            check(reopened.preferences.enabled && reopened.preferences.appearance == "dark" && reopened.preferences.retention == 7 && reopened.preferences.excluded == ["youtube.com"], "recording, theme, retention, and exclusions survive model reopen")
            let failingDirectory = directory.appendingPathComponent("recovery")
            try FileManager.default.createDirectory(at: failingDirectory, withIntermediateDirectories: true)
            let blockedData = failingDirectory.appendingPathComponent("Data")
            try Data("preserve marker".utf8).write(to: blockedData)
            let failing = AppModel(verificationDirectory: failingDirectory, startsServices: false)
            check(failing.storageError != nil, "invalid storage location produces visible error")
            let marker = try Data(contentsOf: blockedData)
            check(marker == Data("preserve marker".utf8), "storage failure preserves the blocking file")
            try FileManager.default.removeItem(at: blockedData)
            failing.retryStorage()
            check(failing.storageError == nil, "storage retry recovers after the cause is removed")
            let recovered = try UsageStore(directory: blockedData).load()
            check(recovered.buckets.isEmpty, "storage recovery does not invent activity")
        } catch { fputs("Model audit failed: \(error)\n", stderr); exit(1) }
    }
}
private struct AuditRoot: View {
    @ObservedObject var model: AppModel
    var body: some View {
        DashboardView(model: model).modifier(SurfAppearance(mode: model.preferences.appearance))
    }
}
