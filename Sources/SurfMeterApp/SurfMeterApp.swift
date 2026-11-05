import SwiftUI
import AppKit
import SurfMeterCore

@MainActor
final class ConnectionModel: ObservableObject {
    struct Snapshot {
        let message: BrowserState
        let received: ContinuousClock.Instant
    }
    @Published var snapshots: [Browser: Snapshot] = [:]
    @Published var bridgeStatus = "Starting local bridge…"
    @Published var foreground = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    @Published var idleSeconds: Double = 0
    @Published var sleeping = false
    @Published var now = ContinuousClock.now
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?

    init() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.foreground = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown" }
        })
        for (name, asleep) in [(NSWorkspace.willSleepNotification, true), (NSWorkspace.didWakeNotification, false)] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.sleeping = asleep
                    self?.snapshots.removeAll() // Require fresh browser state after wake.
                }
            })
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = .now
                self?.idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
            }
        }
        let args = CommandLine.arguments
        let directory: URL
        if let index = args.firstIndex(of: "--bridge-directory"), args.indices.contains(index + 1) {
            directory = URL(fileURLWithPath: args[index + 1])
        } else { directory = LocalBridge.defaultDirectory }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try LocalBridge.serve(directory: directory) { state in
                    // Keep acceptance and snapshot mutation in order on the main thread.
                    DispatchQueue.main.sync {
                        guard let self else { return false }
                        if let prior = self.snapshots[state.browser], prior.message.sessionID == state.sessionID,
                           state.sequence <= prior.message.sequence { return false }
                        self.snapshots[state.browser] = Snapshot(message: state, received: .now)
                        self.bridgeStatus = "Local bridge running"
                        return true
                    }
                }
            } catch {
                DispatchQueue.main.async { self?.bridgeStatus = "Bridge unavailable. Quit other SurfMeter instances and reopen." }
            }
        }
        bridgeStatus = "Waiting for browser connection"
    }

    func status(_ browser: Browser) -> String {
        guard let snapshot = snapshots[browser], snapshot.received.duration(to: now) < .seconds(15) else { return "Disconnected" }
        switch snapshot.message.state {
        case .active: return snapshot.message.hostname ?? "Unavailable"
        case .inactive: return "No focused browser window"
        case .unavailable: return "Page excluded or unavailable"
        }
    }
}

@main
struct SurfMeterApp: App {
    @StateObject private var model = ConnectionModel()
    var body: some Scene {
        MenuBarExtra("SurfMeter", systemImage: "water.waves") {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "water.waves").font(.title2)
                    VStack(alignment: .leading) {
                        Text("SurfMeter").font(.headline)
                        Text("Native foundation").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text("Browser connections").font(.subheadline.weight(.semibold))
                connection("Chrome", .chrome, icon: "globe")
                connection("Safari", .safari, icon: "safari")
                Divider()
                LabeledContent("Foreground app", value: model.foreground)
                LabeledContent("Idle", value: "\(Int(model.idleSeconds.isFinite ? model.idleSeconds : 0)) seconds")
                LabeledContent("System", value: model.sleeping ? "Sleeping" : "Awake")
                Text(model.bridgeStatus).font(.caption).foregroundStyle(.secondary)
                Text("Time recording arrives in Task 2. Browser snapshots stay in memory.").font(.caption).foregroundStyle(.secondary)
                Button("Quit SurfMeter") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            }
            .padding(22)
            .frame(width: 360)
        }
        .menuBarExtraStyle(.window)
    }

    private func connection(_ name: String, _ browser: Browser, icon: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon).frame(width: 20)
            Text(name)
            Spacer()
            Text(model.status(browser)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}
