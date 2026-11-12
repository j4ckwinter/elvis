public enum GitRuns {
    public enum Deed: Equatable, Sendable {
        case committed, pushed
    }

    public static func deed(command: String, exitStatus: Int, output: String?) -> Deed? {
        guard exitStatus == 0 else { return nil }
        let line = ShellLine(command)
        let deeds = line.pieces.indices.compactMap { index in
            line.hidesStatus(ofPieceAt: index) ? nil : deed(of: line.pieces[index].words)
        }
        let nothingWasSent = output?.contains("Everything up-to-date") == true
        if deeds.contains(.pushed), !nothingWasSent { return .pushed }
        return deeds.contains(.committed) ? .committed : nil
    }

    private static let optionsThatTakeAValue: Set<String> = ["-C", "-c"]
    private static let flagsThatCommitNothing: Set<String> = ["--dry-run", "--help", "-h"]
    private static let flagsThatPushNoWork: Set<String> = ["--dry-run", "-n", "--delete", "-d", "--help", "-h"]

    static func deed(of words: [String]) -> Deed? {
        var rest = words.drop(while: isAssignment)
        guard let tool = rest.first, tool.split(separator: "/").last == "git" else { return nil }
        rest = rest.dropFirst()
        while let option = rest.first, option.hasPrefix("-") {
            rest = rest.dropFirst(optionsThatTakeAValue.contains(option) ? 2 : 1)
        }
        let flags = Set(rest.dropFirst().filter { $0.hasPrefix("-") })
        switch rest.first {
        case "commit": return flags.isDisjoint(with: flagsThatCommitNothing) ? .committed : nil
        case "push": return flags.isDisjoint(with: flagsThatPushNoWork) ? .pushed : nil
        default: return nil
        }
    }

    private static func isAssignment(_ word: String) -> Bool {
        guard let name = word.split(separator: "=", omittingEmptySubsequences: false).first, word.contains("=") else { return false }
        return !name.isEmpty && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
