import Darwin
import Foundation

enum UnixSocket {
    static func isAccepting(at path: String) -> Bool {
        guard let connection = connect(to: path) else { return false }
        close(connection)
        return true
    }

    static func processListening(at path: String) -> pid_t? {
        guard let connection = connect(to: path) else { return nil }
        defer { close(connection) }
        var process: pid_t = 0
        var size = socklen_t(MemoryLayout<pid_t>.size)
        return getsockopt(connection, SOL_LOCAL, LOCAL_PEERPID, &process, &size) == 0 ? process : nil
    }

    static func sayAndHangUp(_ line: String, at path: String) -> Bool {
        guard let connection = connect(to: path) else { return false }
        defer { close(connection) }
        let bytes = Array((line + "\n").utf8)
        return write(connection, bytes, bytes.count) == bytes.count
    }

    static func everythingSaid(inAnswerTo text: String, at path: String) -> String? {
        guard let connection = connect(to: path) else { return nil }
        defer { close(connection) }
        let bytes = Array(text.utf8)
        guard write(connection, bytes, bytes.count) == bytes.count else { return nil }
        shutdown(connection, SHUT_WR)
        var patience = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO, &patience, socklen_t(MemoryLayout<timeval>.size))
        var said = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while case let count = read(connection, &buffer, buffer.count), count > 0 {
            said.append(buffer, count: count)
        }
        return String(decoding: said, as: UTF8.self)
    }

    private static func connect(to path: String) -> Int32? {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }
        guard (try? withAddress(of: path) { Darwin.connect(descriptor, $0, $1) }) == 0 else {
            close(descriptor)
            return nil
        }
        return descriptor
    }

    private static func withAddress(of path: String, _ call: (UnsafePointer<sockaddr>, socklen_t) -> Int32) throws -> Int32 {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw POSIXError(.ENAMETOOLONG) }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { call($0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
    }

    final class Listener {
        private let descriptor: Int32

        init(at path: String) throws {
            descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
            let bound = try UnixSocket.withAddress(of: path) { bind(descriptor, $0, $1) }
            guard bound == 0, listen(descriptor, 16) == 0, fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }

        deinit { close(descriptor) }

        func linesDelivered() -> [String] {
            var delivered = Data()
            while case let connection = accept(descriptor, nil, nil), connection >= 0 {
                delivered.append(everything(sentOver: connection))
                close(connection)
            }
            return String(decoding: delivered, as: UTF8.self).split(separator: "\n").map(String.init)
        }

        func kindsDeliveredInAnyOrder(expecting count: Int) -> [String] {
            var lines: [String] = []
            _ = eventually(within: 5) {
                lines += linesDelivered()
                return lines.count >= count
            }
            usleep(200_000)
            lines += linesDelivered()
            return lines.compactMap { line in
                (try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: String])?["kind"]
            }.sorted()
        }

        private func everything(sentOver connection: Int32) -> Data {
            var patience = timeval(tv_sec: 2, tv_usec: 0)
            _ = fcntl(connection, F_SETFL, 0)
            setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO, &patience, socklen_t(MemoryLayout<timeval>.size))
            var sent = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while case let count = read(connection, &buffer, buffer.count), count > 0 {
                sent.append(buffer, count: count)
            }
            return sent
        }
    }
}
