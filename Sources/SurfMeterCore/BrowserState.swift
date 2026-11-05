import Foundation

public enum Browser: String, Codable, Sendable { case chrome, safari }
public enum ActivityState: String, Codable, Sendable { case active, inactive, unavailable }

/// An ephemeral snapshot, never a usage record. Unknown fields are rejected at the boundary.
public struct BrowserState: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let browser: Browser
    public let sessionID: UUID
    public let sequence: Int
    public let state: ActivityState
    public let hostname: String?

    public init(browser: Browser, sessionID: UUID, sequence: Int, state: ActivityState, hostname: String? = nil) {
        self.protocolVersion = 1
        self.browser = browser
        self.sessionID = sessionID
        self.sequence = sequence
        self.state = state
        self.hostname = hostname
    }

    public static func decode(_ data: Data) throws -> BrowserState {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["protocolVersion", "browser", "sessionID", "sequence", "state", "hostname"]) else {
            throw ProtocolError.invalidState
        }
        let message = try JSONDecoder().decode(Self.self, from: data)
        guard message.protocolVersion == 1, message.sequence >= 0 else { throw ProtocolError.invalidState }
        if message.state == .active {
            guard let hostname = message.hostname, validHostname(hostname) else { throw ProtocolError.invalidState }
        } else if message.hostname != nil {
            throw ProtocolError.invalidState
        }
        return message
    }

    private static func validHostname(_ value: String) -> Bool {
        guard !value.isEmpty, value.utf8.count <= 253, value == value.lowercased() else { return false }
        // Accept ASCII DNS names (including punycode) and IPv4; domain grouping is Task 2.
        return value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
            !label.isEmpty && label.utf8.count <= 63 && label.first != "-" && label.last != "-" &&
            label.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
        }
    }
}

public enum ProtocolError: Error { case invalidState, oversizedFrame, truncatedFrame, invalidOrigin, transport }

public enum NativeFrame {
    public static let maximumSize = 16_384

    public static func encode(_ data: Data) throws -> Data {
        guard !data.isEmpty, data.count <= maximumSize else { throw ProtocolError.oversizedFrame }
        var length = UInt32(data.count).littleEndian
        var output = withUnsafeBytes(of: &length) { Data($0) }
        output.append(data)
        return output
    }

    /// A clean EOF before a header ends the connection; a partial frame is always an error.
    public static func read(from handle: FileHandle) throws -> Data? {
        guard let header = try readExactly(4, from: handle, allowEOF: true) else { return nil }
        let length = header.enumerated().reduce(UInt32(0)) { $0 | (UInt32($1.element) << ($1.offset * 8)) }
        guard length > 0, length <= maximumSize else { throw ProtocolError.oversizedFrame }
        return try readExactly(Int(length), from: handle, allowEOF: false)
    }

    private static func readExactly(_ count: Int, from handle: FileHandle, allowEOF: Bool) throws -> Data? {
        var data = Data()
        while data.count < count {
            let next = try handle.read(upToCount: count - data.count) ?? Data()
            if next.isEmpty {
                if data.isEmpty && allowEOF { return nil }
                throw ProtocolError.truncatedFrame
            }
            data.append(next)
        }
        return data
    }
}

public struct BridgeReply: Codable, Sendable {
    public let protocolVersion: Int
    public let accepted: Bool
    public init(accepted: Bool) { self.protocolVersion = 1; self.accepted = accepted }
}
