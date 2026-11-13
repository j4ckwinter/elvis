import Darwin
import Foundation

enum RunningElvis {
    private static var lockPath: String { EventSocket.directory + "/elvis.lock" }
    private static let waitForADepartingElvisToLetGo = (tries: 10, pause: useconds_t(50_000))

    static func claim(as version: String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: EventSocket.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        } catch {
            FileHandle.standardError.write(Data("elvis: could not create \(EventSocket.directory): \(error)\n".utf8))
            exit(1)
        }
        let lock = open(lockPath, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard lock >= 0 else { return false }
        var triesLeft = waitForADepartingElvisToLetGo.tries
        while flock(lock, LOCK_EX | LOCK_NB) != 0 {
            if EventSocket.isSomeoneListening || triesLeft == 0 { return false }
            usleep(waitForADepartingElvisToLetGo.pause)
            triesLeft -= 1
        }
        ftruncate(lock, 0)
        let record = Array("\(version) \(getpid())".utf8)
        _ = write(lock, record, record.count)
        return true
    }

    static var version: String? {
        guard let listener = EventSocket.listeningProcess else { return nil }
        guard let record = try? String(contentsOfFile: lockPath, encoding: .utf8).split(separator: " ") else { return nil }
        let isHisOwn = record.count >= 2 && record[1] == "\(listener)"
        return isHisOwn ? String(record[0]) : ""
    }
}
