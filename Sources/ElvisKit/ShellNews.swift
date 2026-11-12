public enum ShellNews {
    public static func kind(ofCommand command: String, exitStatus: Int, output: String?) -> WorkEvent.Kind? {
        switch TestRuns.verdict(command: command, exitStatus: exitStatus, output: output) {
        case .passed: return .testsPassed
        case .failed: return .testsFailed
        case nil: return nil
        }
    }
}
