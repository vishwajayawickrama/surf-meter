import Foundation
import SurfMeterCore

struct Configuration: Decodable {
    let allowedOrigin: String
    let bridgeDirectory: String?
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
    while let data = try NativeFrame.read(from: .standardInput) {
        do {
            let state = try BrowserState.decode(data)
            guard state.browser == .chrome else { throw ProtocolError.invalidState }
            let reply = try LocalBridge.send(state, directory: directory)
            try FileHandle.standardOutput.write(contentsOf: NativeFrame.encode(JSONEncoder().encode(reply)))
        } catch {
            try FileHandle.standardOutput.write(contentsOf: NativeFrame.encode(JSONEncoder().encode(BridgeReply(accepted: false))))
        }
    }
} catch {
    FileHandle.standardError.write(Data("SurfMeter native host could not establish a valid session.\n".utf8))
    exit(1)
}
