import Foundation
import Darwin

/// Own the writer lease before opening Core Data. The socket lock alone is too
/// late: an unconnected second model must never checkpoint a stale ledger.
final class ActivityLease {
    enum Failure: Error { case inUse, unavailable }
    private let descriptor: Int32
    init(directory: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let attributes = try fm.attributesOfItem(atPath: directory.path)
        guard (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              attributes[.type] as? FileAttributeType == .typeDirectory,
              ((attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0) & 0o077 == 0 else { throw Failure.unavailable }
        let fd = open(directory.appendingPathComponent("activity.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw Failure.unavailable }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o077 == 0 else {
            close(fd); throw Failure.unavailable
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let busy = errno == EWOULDBLOCK || errno == EAGAIN
            close(fd); throw busy ? Failure.inUse : Failure.unavailable
        }
        descriptor = fd
    }
    deinit { close(descriptor) }
}
