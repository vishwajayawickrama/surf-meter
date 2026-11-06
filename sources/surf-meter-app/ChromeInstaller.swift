import Foundation
import SurfMeterCore

@MainActor
enum ChromeInstaller {
    static func install(extensionID: String, app: URL = Bundle.main.bundleURL) throws {
        guard extensionID.range(of: "^[a-p]{32}$", options: .regularExpression) != nil else { throw ProtocolError.invalidOrigin }
        let fm = FileManager.default
        let directory = LocalBridge.defaultDirectory.appendingPathComponent("NativeHost")
        let host = directory.appendingPathComponent("SurfMeterNativeHost")
        let registration = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Google/Chrome/NativeMessagingHosts/dev.surfmeter.bridge.json")
        let origin = "chrome-extension://\(extensionID)/"
        let manifest: [String: Any] = ["name": "dev.surfmeter.bridge", "description": "SurfMeter local browser bridge", "path": host.path, "type": "stdio", "allowed_origins": [origin]]
        if fm.fileExists(atPath: registration.path) {
            let prior = try JSONSerialization.jsonObject(with: Data(contentsOf: registration)) as? NSDictionary
            guard prior == manifest as NSDictionary else { throw NSError(domain: "SurfMeterExistingRegistration", code: 1) }
        }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let source = app.appendingPathComponent("Contents/Helpers/SurfMeterNativeHost")
        let staged = directory.appendingPathComponent("host-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: staged) }
        try fm.copyItem(at: source, to: staged)
        if fm.fileExists(atPath: host.path) { _ = try fm.replaceItemAt(host, withItemAt: staged) }
        else { try fm.moveItem(at: staged, to: host) }
        let config: [String: Any] = ["allowedOrigin": origin, "appBundle": app.path]
        try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]).write(to: directory.appendingPathComponent("host-config.json"), options: .atomic)
        try fm.createDirectory(at: registration.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: registration, options: .atomic)
    }
}
