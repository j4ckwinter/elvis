import Foundation

public enum ClaudeHooks {
    public static func event(fromPayload payload: Data) -> WorkEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let name = object["hook_event_name"] as? String
        else { return nil }
        let session = object["session_id"] as? String ?? ""
        let tool = object["tool_name"] as? String ?? ""
        let input = object["tool_input"] as? [String: Any] ?? [:]
        let subject = tool.isEmpty ? nil : fingerprint(tool: tool, input: input)
        let agent = object["agent_id"] as? String

        switch name {
        case "SessionStart":
            let source = object["source"] as? String ?? "startup"
            let someoneJustSatDown = source == "startup" || source == "resume"
            return someoneJustSatDown ? WorkEvent(.sessionStarted, session: session) : nil
        case "UserPromptSubmit":
            return WorkEvent(.taskStarted, session: session)
        case "PreToolUse":
            if toolsThatAskTheUser.contains(tool) {
                return WorkEvent(.needsYou, session: session, subject: subject, agent: agent)
            }
            return WorkEvent(.toolStarted, session: session, flavour: flavour(of: tool), subject: subject, agent: agent)
        case "PermissionRequest":
            return WorkEvent(.needsYou, session: session, subject: subject, agent: agent)
        case "Elicitation":
            return WorkEvent(.needsYou, session: session)
        case "Notification":
            let type = object["notification_type"] as? String ?? ""
            if type == "idle_prompt" { return WorkEvent(.sessionIdle, session: session) }
            return notificationsThatWait.contains(type) ? WorkEvent(.needsYou, session: session) : nil
        case "ElicitationResult", "PermissionDenied":
            return WorkEvent(.youAnswered, session: session)
        case "PostToolUse":
            let response = object["tool_response"] as? [String: Any]
            let cutShort = response?["interrupted"] as? Bool == true || response?["backgroundTaskId"] != nil
            let kind = cutShort ? nil : shellNews(tool: tool, input: input, exitStatus: 0, output: output(of: object["tool_response"]))
            return WorkEvent(kind ?? .toolFinished, session: session, subject: subject, agent: agent)
        case "PostToolUseFailure":
            let error = object["error"] as? String ?? ""
            let interrupted = object["is_interrupt"] as? Bool ?? false
            guard !interrupted, let status = exitStatus(ofCommandThatRan: error) else {
                return WorkEvent(.toolFinished, session: session, subject: subject, agent: agent)
            }
            let kind = shellNews(tool: tool, input: input, exitStatus: status, output: error)
            return WorkEvent(kind ?? .toolFinished, session: session, subject: subject, agent: agent)
        case "Stop":
            return WorkEvent(.taskFinished, session: session)
        case "StopFailure":
            return WorkEvent(.taskStumbled, session: session)
        case "SessionEnd":
            return WorkEvent(.sessionEnded, session: session)
        default:
            return nil
        }
    }

    private static let toolsThatAskTheUser: Set<String> = ["AskUserQuestion", "ExitPlanMode"]
    private static let notificationsThatWait: Set<String> = [
        "permission_prompt", "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input",
    ]

    private static func shellNews(tool: String, input: [String: Any], exitStatus: Int, output: String?) -> WorkEvent.Kind? {
        guard tool == "Bash" || tool == "PowerShell", let command = input["command"] as? String else { return nil }
        if input["run_in_background"] as? Bool == true { return nil }
        return ShellNews.kind(ofCommand: command, exitStatus: exitStatus, output: output)
    }

    private static func exitStatus(ofCommandThatRan error: String) -> Int? {
        error.hasPrefix("Exit code ") ? Int(error.dropFirst(10).prefix(while: \.isNumber)) : nil
    }

    private static func output(of response: Any?) -> String? {
        if let text = response as? String { return text }
        guard let fields = response as? [String: Any] else { return nil }
        let parts = ["stdout", "stderr"].compactMap { fields[$0] as? String }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    static func flavour(of tool: String) -> WorkEvent.Flavour {
        switch tool {
        case "Read", "Grep", "Glob", "LS", "NotebookRead", "ToolSearch", "ListMcpResourcesTool", "ReadMcpResourceTool":
            return .read
        case "Edit", "Write", "MultiEdit", "NotebookEdit":
            return .edit
        case "Bash", "PowerShell", "BashOutput", "KillShell", "Monitor":
            return .shell
        case "WebFetch", "WebSearch":
            return .web
        default:
            return tool.hasPrefix("mcp__") ? .web : .other
        }
    }

    static func fingerprint(tool: String, input: [String: Any]) -> String {
        let canonical = (try? JSONSerialization.data(withJSONObject: input, options: [.sortedKeys])) ?? Data()
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in canonical {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return "\(tool):\(String(hash, radix: 16))"
    }
}
