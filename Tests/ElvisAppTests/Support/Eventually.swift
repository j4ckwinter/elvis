import Foundation

func eventually(within seconds: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() {
        if Date() >= deadline { return false }
        usleep(10_000)
    }
    return true
}
