import Foundation

public enum Version {
    public static let current = "0.4.0"

    public static func isOlder(_ version: String, than other: String) -> Bool {
        version.compare(other, options: .numeric) == .orderedAscending
    }
}
