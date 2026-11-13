import Darwin
import ElvisKit
import Foundation

enum EventSocket {
    static var directory: String {
        if let override = ProcessInfo.processInfo.environment["ELVIS_HOME"], !override.isEmpty { return override }
        return NSHomeDirectory() + "/Library/Application Support/Elvis"
    }

    static var path: String { directory + "/elvis.sock" }

    private static func address(for path: String) -> sockaddr_un? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard bytes.count < capacity else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
        }
        return address
    }

    private static func connect() -> Int32? {
        guard var address = address(for: path) else { return nil }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        if result != 0 {
            close(fd)
            return nil
        }
        return fd
    }

    private static var lockPath: String { directory + "/elvis.lock" }
    private static let triesForADepartingElvisToLetGo = 10

    static func claimSoleInstance(as version: String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        } catch {
            FileHandle.standardError.write(Data("elvis: could not create \(directory): \(error)\n".utf8))
            exit(1)
        }
        let lock = open(lockPath, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard lock >= 0 else { return false }
        var triesLeft = triesForADepartingElvisToLetGo
        while flock(lock, LOCK_EX | LOCK_NB) != 0 {
            if isSomeoneListening || triesLeft == 0 { return false }
            usleep(50_000)
            triesLeft -= 1
        }
        ftruncate(lock, 0)
        let record = Array("\(version) \(getpid())".utf8)
        _ = write(lock, record, record.count)
        return true
    }

    static var versionOfTheRunningElvis: String? {
        guard let fd = connect() else { return nil }
        defer { close(fd) }
        var listener: pid_t = 0
        var size = socklen_t(MemoryLayout<pid_t>.size)
        guard getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &listener, &size) == 0 else { return nil }
        let record = ((try? String(contentsOfFile: lockPath, encoding: .utf8)) ?? "").split(separator: " ")
        let isHisOwn = record.count >= 2 && record[1] == "\(listener)"
        return isHisOwn ? String(record[0]) : ""
    }

    static var isSomeoneListening: Bool {
        guard let fd = connect() else { return false }
        close(fd)
        return true
    }

    @discardableResult
    static func send(_ event: WorkEvent) -> Bool {
        guard let fd = connect() else { return false }
        defer { close(fd) }
        let line = event.encodedLine()
        return line.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) } == line.count
    }

    static func listen(deliveringOnMain deliver: @escaping (WorkEvent) -> Void) throws {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        unlink(path)
        guard var address = address(for: path) else { throw CocoaError(.fileWriteInvalidFileName) }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, Darwin.listen(fd, 32) == 0 else {
            close(fd)
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        chmod(path, 0o600)

        let thread = Thread {
            while true {
                let client = accept(fd, nil, nil)
                if client < 0 {
                    if errno == EBADF || errno == EINVAL || errno == ENOTSOCK { return }
                    if errno != EINTR { usleep(100_000) }
                    continue
                }
                var timeout = timeval(tv_sec: 1, tv_usec: 0)
                setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 1024)
                while data.count < 8192 {
                    let count = read(client, &buffer, buffer.count)
                    if count <= 0 { break }
                    data.append(buffer, count: count)
                }
                close(client)
                for line in data.split(separator: 0x0A) {
                    if let event = WorkEvent.decode(line: Data(line)) {
                        DispatchQueue.main.async { deliver(event) }
                    }
                }
            }
        }
        thread.name = "elvis.events"
        thread.start()
    }
}
