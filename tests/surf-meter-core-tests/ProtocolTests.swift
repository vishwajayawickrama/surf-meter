import Foundation
import Testing
@testable import SurfMeterCore

struct ProtocolTests {
    func payload(_ hostname: String? = "www.youtube.com", state: ActivityState = .active) throws -> Data {
        try JSONEncoder().encode(BrowserState(browser: .chrome, sessionID: UUID(), sequence: 1, state: state, hostname: hostname))
    }

    @Test func roundTrip() throws {
        let value = try BrowserState.decode(payload())
        #expect(value.hostname == "www.youtube.com")
        #expect(value.protocolVersion == 1)
    }

    @Test func rejectsURLsAndInvalidDomains() throws {
        for value in ["https://youtube.com/private?q=1", "youtube.com/path", "YouTube.com", "a..com", "-bad.com", "bad_.com", "", "a.com?query"] {
            let data = try payload(value)
            #expect(throws: (any Error).self) { try BrowserState.decode(data) }
        }
    }

    @Test func excludedSnapshotsContainNoHostname() throws {
        _ = try BrowserState.decode(payload(nil, state: .unavailable))
        for state in [ActivityState.unavailable, .inactive] {
            let data = try payload("secret.com", state: state)
            #expect(throws: (any Error).self) { try BrowserState.decode(data) }
        }
    }

    @Test func rejectsUnexpectedMetadataAndVersions() throws {
        var object = try JSONSerialization.jsonObject(with: payload()) as! [String: Any]
        object["title"] = "Private title"
        var data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { try BrowserState.decode(data) }
        object.removeValue(forKey: "title")
        object["protocolVersion"] = 2
        data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { try BrowserState.decode(data) }
        object["protocolVersion"] = 1
        object["sequence"] = -1
        data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { try BrowserState.decode(data) }
    }

    func read(_ bytes: Data) throws -> Data? {
        let pipe = Pipe()
        try pipe.fileHandleForWriting.write(contentsOf: bytes)
        try pipe.fileHandleForWriting.close()
        return try NativeFrame.read(from: pipe.fileHandleForReading)
    }

    @Test func framingAndCleanEOF() throws {
        let data = try payload()
        #expect(try read(NativeFrame.encode(data)) == data)
        #expect(try read(Data()) == nil)
    }

    @Test func rejectsTruncatedAndOversizedFrames() throws {
        for data in [Data([1, 0]), Data([4, 0, 0, 0, 123]), Data([255, 255, 255, 127])] {
            #expect(throws: (any Error).self) { try read(data) }
        }
        #expect(throws: (any Error).self) { try NativeFrame.encode(Data(count: NativeFrame.maximumSize + 1)) }
    }
}
