import Foundation
import Darwin

/// Local-only, same-user IPC. No network listener and no persistent browser snapshots.
public enum LocalBridge {
    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/SurfMeter")
    }

    private static func address(_ directory: URL) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(directory.appendingPathComponent("bridge.sock").path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw ProtocolError.transport }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        return address
    }

    private static func withAddress<T>(_ address: inout sockaddr_un, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
        withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { body($0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
    }

    private static func configure(_ fd: Int32) {
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
    }

    private static func sameUser(_ fd: Int32) -> Bool {
        var uid: uid_t = 0
        var gid: gid_t = 0
        return getpeereid(fd, &uid, &gid) == 0 && uid == getuid()
    }

    public static func send(_ message: BrowserState, directory: URL = defaultDirectory) throws -> BridgeReply {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ProtocolError.transport }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        configure(fd)
        var addr = try address(directory)
        guard withAddress(&addr, { connect(fd, $0, $1) }) == 0, sameUser(fd) else { throw ProtocolError.transport }
        try handle.write(contentsOf: NativeFrame.encode(JSONEncoder().encode(message)))
        guard let reply = try NativeFrame.read(from: handle) else { throw ProtocolError.transport }
        return try JSONDecoder().decode(BridgeReply.self, from: reply)
    }

    /// Call on a dedicated queue. Socket ownership is exclusive until this process exits.
    public static func serve(directory: URL = defaultDirectory, receive: @escaping (BrowserState) -> Bool) throws -> Never {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let attrs = try fm.attributesOfItem(atPath: directory.path)
        guard (attrs[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              (attrs[.type] as? FileAttributeType) == .typeDirectory,
              ((attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0) & 0o077 == 0 else { throw ProtocolError.transport }
        // Keep a lock open to prevent a second app from unlinking a live endpoint.
        let lock = open(directory.appendingPathComponent("bridge.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard lock >= 0 else { throw ProtocolError.transport }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { close(lock); throw ProtocolError.transport }
        defer { close(lock) }
        let path = directory.appendingPathComponent("bridge.sock").path
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ProtocolError.transport }
        defer { close(fd); unlink(path) }
        var addr = try address(directory)
        guard withAddress(&addr, { bind(fd, $0, $1) }) == 0, chmod(path, 0o600) == 0, listen(fd, 8) == 0 else { throw ProtocolError.transport }
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 { if errno == EINTR { continue }; throw ProtocolError.transport }
            configure(client)
            let handle = FileHandle(fileDescriptor: client, closeOnDealloc: true)
            defer { try? handle.close() }
            guard sameUser(client) else { continue }
            do {
                guard let data = try NativeFrame.read(from: handle) else { continue }
                let state = try BrowserState.decode(data)
                let reply = BridgeReply(accepted: receive(state))
                try handle.write(contentsOf: NativeFrame.encode(JSONEncoder().encode(reply)))
            } catch {
                // Deliberately omit payloads from diagnostics.
                try? handle.write(contentsOf: NativeFrame.encode(JSONEncoder().encode(BridgeReply(accepted: false))))
            }
        }
    }
}
