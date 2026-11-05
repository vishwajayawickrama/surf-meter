import Foundation
import ServiceManagement

/// Explicit local setup commands for installers when a menu-only app has no automation window.
/// Runs before AppModel: does not open the activity store or start another bridge server.
@MainActor
enum SetupCommand {
    static let preferencesChanged = Notification.Name("dev.surfmeter.preferencesChanged")

    static func run(arguments: [String]) -> Never {
        guard let index = arguments.firstIndex(of: "--configure-chrome"), arguments.indices.contains(index + 1) else {
            fail("Usage: SurfMeter --configure-chrome EXTENSION_ID [--enable-recording] [--enable-login]", code: 64)
        }
        let id = arguments[index + 1]
        var remaining = arguments
        remaining.removeSubrange(index...(index + 1))
        guard Set(remaining).isSubset(of: ["--enable-recording", "--enable-login"]),
              id.range(of: "^[a-p]{32}$", options: .regularExpression) != nil else {
            fail("Use the actual 32-letter Chrome extension ID and only the documented setup flags.", code: 64)
        }
        do {
            try ChromeInstaller.install(extensionID: id)
            print("Chrome native helper registered for the installed app.")
            if remaining.contains("--enable-recording") {
                let defaults = UserDefaults.standard
                var preferences: Preferences
                if let saved = defaults.data(forKey: "preferences") {
                    preferences = try JSONDecoder().decode(Preferences.self, from: saved)
                } else { preferences = Preferences() }
                preferences.enabled = true
                preferences.paused = false
                defaults.set(try JSONEncoder().encode(preferences), forKey: "preferences")
                guard defaults.synchronize() else { fail("Could not save recording preferences.", code: 1) }
                print("Local recording enabled; existing appearance, exclusions, and retention preserved.")
            }
            var loginPending = false
            if remaining.contains("--enable-login") {
                do {
                    if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                    switch SMAppService.mainApp.status {
                    case .enabled: print("Launch at login enabled.")
                    case .requiresApproval:
                        print("Launch at login requires approval in macOS System Settings → Login Items.")
                        loginPending = true
                    default:
                        print("Launch at login is not enabled; check the app's signing and Login Items settings.")
                        loginPending = true
                    }
                } catch {
                    print("Launch at login could not register: \(error.localizedDescription)")
                    loginPending = true
                }
            }
            DistributedNotificationCenter.default().postNotificationName(preferencesChanged, object: nil, userInfo: nil, deliverImmediately: true)
            exit(loginPending ? 3 : 0)
        } catch {
            fail("Chrome setup failed. Check for an existing different SurfMeter host registration: \(error.localizedDescription)", code: 1)
        }
    }
    private static func fail(_ message: String, code: Int32) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(code)
    }
}
