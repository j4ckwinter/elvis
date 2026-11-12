public enum ShellNews {
    public static func ofTests(command: String, exitStatus: Int, output: String?) -> WorkEvent.Kind? {
        switch TestRuns.verdict(command: command, exitStatus: exitStatus, output: output) {
        case .passed: return .testsPassed
        case .failed: return .testsFailed
        case nil: return nil
        }
    }

    public static func ofYourOwnCommand(_ command: String, exitStatus: Int) -> WorkEvent.Kind? {
        if let tests = ofTests(command: command, exitStatus: exitStatus, output: nil) { return tests }
        switch GitRuns.deed(command: command, exitStatus: exitStatus) {
        case .committed: return .committed
        case .pushed: return .pushed
        case nil: return nil
        }
    }
}
