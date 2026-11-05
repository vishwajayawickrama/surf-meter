import Foundation
import SurfMeterCore

struct Configuration: Decodable {
    let allowedOrigin: String
    let bridgeDirectory: String?
    let appBundle: String?
}

// Chrome supplies the caller origin. The adjacent installer-generated configuration pins it.
// This is a development bridge, not code-signature authentication of same-user processes.
do {
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    let config = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: executable.deletingLastPathComponent().appendingPathComponent("host-config.json")))
    guard CommandLine.arguments.count == 2,
          CommandLine.arguments[1] == config.allowedOrigin,
          config.allowedOrigin.range(of: "^chrome-extension://[a-p]{32}/$", options: .regularExpression) != nil else { throw ProtocolError.invalidOrigin }
    let directory = config.bridgeDirectory.map { URL(fileURLWithPath: $0) } ?? LocalBridge.defaultDirectory
    var lastLaunch = -Double.infinity
    var hasConnected = false
    func forward(_ state: BrowserState) throws -> BridgeReply {
        do { let reply = try LocalBridge.send(state, directory: directory); hasConnected = true; return reply }
        catch {
            guard !hasConnected, let app = config.appBundle, app.hasPrefix("/"), app.hasSuffix(".app"), FileManager.default.fileExists(atPath: app),
                  ProcessInfo.processInfo.systemUptime - lastLaunch > 10 else { throw error }
            lastLaunch = ProcessInfo.processInfo.systemUptime
            let launch = Process(); launch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            launch.arguments = ["-g", app]; launch.standardOutput = FileHandle.nullDevice; launch.standardError = FileHandle.nullDevice
            try launch.run(); launch.waitUntilExit()
            guard launch.terminationStatus == 0 else { throw ProtocolError.transport }
            for _ in 0..<20 {
                if let reply = try? LocalBridge.send(state, directory: directory) { hasConnected = true; return reply }
                Thread.sleep(forTimeInterval: 0.05)
            }
            throw ProtocolError.transport
        }
    }
    while let data = try NativeFrame.read(from: .standardInput) {
        do {
            let state = try BrowserState.decode(data)
            guard state.browser == .chrome else { throw ProtocolError.invalidState }
            let reply = try forward(state)
            try FileHandle.standardOutput.write(contentsOf: NativeFrame.encode(JSONEncoder().encode(reply)))
        } catch {
            try FileHandle.standardOutput.write(contentsOf: NativeFrame.encode(JSONEncoder().encode(BridgeReply(accepted: false))))
        }
    }
} catch {
    FileHandle.standardError.write(Data("SurfMeter native host could not establish a valid session.\n".utf8))
    exit(1)
}
