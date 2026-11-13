import Foundation

public enum TestRuns {
    public enum Verdict: Equatable, Sendable {
        case passed, failed
    }

    public static func verdict(command: String, exitStatus: Int, output: String?) -> Verdict? {
        guard let run = testSegment(in: command) else { return nil }
        if run.statusIsMasked { return output.flatMap(verdict(fromOutput:)) }
        if exitStatus == 0 { return .passed }
        let runnerNeverStartedOrWasKilled = exitStatus >= 126
        if runnerNeverStartedOrWasKilled { return nil }
        guard run.statusMayBeAnotherCommands else { return .failed }
        guard let output else { return nil }
        if reportsFailedTests(output) { return .failed }
        return run.onlyAChangeOfDirectoryCameFirst && !reportsAFailedChangeOfDirectory(output) ? .failed : nil
    }

    public static func isTestCommand(_ command: String) -> Bool {
        testSegment(in: command) != nil
    }

    struct Segment {
        var statusIsMasked: Bool
        var statusMayBeAnotherCommands: Bool
        var onlyAChangeOfDirectoryCameFirst: Bool
    }

    static func testSegment(in command: String) -> Segment? {
        let line = ShellLine(command)
        let pieces = line.pieces
        guard let index = pieces.firstIndex(where: { isTestInvocation($0.words) }) else { return nil }
        let masked = line.hidesStatus(ofPieceAt: index) || line.mayHaveSkipped(pieceAt: index)
        let runsOnlyIfTheStepBeforeSucceeds = index > pieces.startIndex && pieces[index - 1].joiner == "&&"
        let isFollowedByAnotherCommand = index < pieces.endIndex - 1
        let cameFirst = pieces[..<index]
        let composeMayHaveFailedBeforeTheRunnerStarted = runsInsideAComposeService(pieces[index].words)
        let onlyAChangeOfDirectoryCameFirst = !isFollowedByAnotherCommand && !cameFirst.isEmpty && !composeMayHaveFailedBeforeTheRunnerStarted
            && cameFirst.allSatisfy { $0.joiner == "&&" && isAChangeOfDirectoryThatWouldSayIfItFailed($0.words) }
        return Segment(
            statusIsMasked: masked,
            statusMayBeAnotherCommands: runsOnlyIfTheStepBeforeSucceeds || isFollowedByAnotherCommand || composeMayHaveFailedBeforeTheRunnerStarted,
            onlyAChangeOfDirectoryCameFirst: onlyAChangeOfDirectoryCameFirst)
    }

    private static let changesOfDirectory: Set<String> = ["cd", "pushd"]
    private static let wrappers: Set<String> = [
        "time", "sudo", "command", "exec", "nice", "env", "caffeinate", "npx", "bunx", "pnpx", "dotenv", "arch", "xcrun", "php",
    ]
    private static let twoWordWrappers: Set<String> = [
        "uv run", "poetry run", "pipenv run", "pdm run", "hatch run", "bundle exec", "pnpm exec", "yarn exec", "npm exec",
        "pnpm dlx", "yarn dlx", "rye run", "mise exec", "nix-shell --run",
    ]
    private static let composeFlagsThatTakeAValue: Set<String> = [
        "-f", "--file", "-p", "--project-name", "--profile", "--env-file", "--project-directory", "--progress", "--parallel",
        "--ansi", "-e", "--env", "-u", "--user", "-w", "--workdir", "--index", "--publish", "-v", "--volume", "--name",
        "--cap-add", "--cap-drop", "-l", "--label", "--pull",
    ]
    private static let composeFlagsThatStandAlone: Set<String> = [
        "--rm", "-T", "--no-TTY", "-i", "-t", "-it", "-ti", "--interactive", "--tty", "--no-deps", "--build", "--quiet-pull",
        "--service-ports", "--use-aliases", "--remove-orphans", "--privileged", "--compatibility",
    ]
    private static let runners: Set<String> = [
        "pytest", "py.test", "jest", "vitest", "mocha", "ava", "tap", "jasmine", "karma", "rspec", "phpunit", "pest",
        "ctest", "tox", "nox", "nosetests", "behave", "cucumber", "busted", "bats", "ginkgo", "gotestsum", "nextest",
        "playwright", "cypress", "minitest", "unittest",
    ]

    private static let flagsThatRunNothing: Set<String> = [
        "--collect-only", "--co", "--version", "-V", "--help", "-h", "--no-run", "--list", "--list-tests", "--listTests",
        "--dry-run", "--setup-only", "--fixtures",
    ]
    private static let flagsThatTakeAValue: Set<String> = ["-C", "-f", "-j", "-I", "--directory", "--file", "--makefile", "--jobs"]
    private static let partsThatAreNotARun: Set<String> = [
        "data", "db", "prepare", "setup", "fixtures", "clean", "env", "deps", "install", "seed", "reset", "server", "image",
        "docker", "up", "down", "init", "build", "lint", "gen", "generate",
    ]

    static func isTestInvocation(_ rawWords: [String]) -> Bool {
        if rawWords.contains(where: flagsThatRunNothing.contains) { return false }
        var words = rawWords[...]
        while let first = words.first {
            if first.contains("=") && !first.hasPrefix("-") && first.first != "=" && !first.hasPrefix("./") {
                words = words.dropFirst()
            } else if words.count >= 2, twoWordWrappers.contains("\(first) \(words[words.index(after: words.startIndex)])") {
                words = words.dropFirst(2)
            } else if let insideAService = commandRunInAComposeService(words) {
                words = insideAService
            } else if wrappers.contains(first) {
                words = words.dropFirst()
                if first == "nice" || first == "caffeinate" || first == "arch" {
                    while let flag = words.first, flag.hasPrefix("-") { words = words.dropFirst() }
                }
            } else {
                break
            }
        }
        guard let head = words.first else { return false }
        let tool = (head.split(separator: "/").last.map(String.init) ?? head).lowercased()
        let rest = words.dropFirst().filter { !$0.hasPrefix("-") }.map { $0.lowercased() }

        if runners.contains(tool) {
            if tool == "playwright" || tool == "cypress" { return rest.first == "test" || rest.first == "run" }
            return true
        }
        if tool == "manage.py" { return rest.first == "test" }
        if tool.hasPrefix("python") || tool == "py" {
            let all = words.dropFirst().map { $0.lowercased() }
            if let m = all.firstIndex(of: "-m"), all.index(after: m) < all.endIndex {
                return ["pytest", "unittest", "nose", "nose2", "tox", "nox"].contains(all[all.index(after: m)])
            }
            return rest.first?.split(separator: "/").last == "manage.py" && rest.dropFirst().first == "test"
        }
        guard let verb = rest.first else { return false }
        switch tool {
        case "npm", "yarn", "pnpm", "bun":
            if verb == "run" || verb == "run-script" {
                guard rest.count > 1 else { return false }
                return isTestScriptName(rest[1])
            }
            return verb == "t" || isTestScriptName(verb)
        case "make", "gmake", "just", "task", "rake", "invoke", "turbo", "nx", "moon", "rush", "lerna", "melos":
            var targets: [String] = []
            var skipNext = false
            for word in words.dropFirst() {
                if skipNext { skipNext = false } else if flagsThatTakeAValue.contains(word) { skipNext = true } else if !word.hasPrefix("-") { targets.append(word.lowercased()) }
            }
            return targets.contains(where: isTestScriptName)
        case "cargo":
            return verb == "test" || verb == "t" || verb == "nextest"
        case "go", "swift", "deno", "dotnet", "mix", "zig", "stack", "cabal", "lein", "sbt", "flutter", "dart",
             "composer", "tuist", "forge", "hardhat", "ng", "wasm-pack", "pixi", "bazel", "buck", "pants", "rails",
             "elixir", "artisan":
            return verb == "test" || (tool == "rails" && verb.hasPrefix("test:"))
        case "mvn", "mvnw", "gradle", "gradlew":
            return rest.contains { $0 == "test" || $0 == "verify" || $0 == "check" || $0.hasSuffix(":test") }
        case "xcodebuild":
            return rest.contains("test") || rest.contains("test-without-building")
        default:
            return false
        }
    }

    private static func commandRunInAComposeService(_ words: ArraySlice<String>) -> ArraySlice<String>? {
        var rest: ArraySlice<String>
        if words.first == "docker-compose" {
            rest = words.dropFirst()
        } else if words.starts(with: ["docker", "compose"]) {
            rest = words.dropFirst(2)
        } else {
            return nil
        }
        guard let verbAndAfter = droppingComposeFlagsWeKnow(rest), verbAndAfter.first == "exec" || verbAndAfter.first == "run",
              let serviceAndCommand = droppingComposeFlagsWeKnow(verbAndAfter.dropFirst())
        else { return nil }
        return serviceAndCommand.count > 1 ? serviceAndCommand.dropFirst() : nil
    }

    private static func droppingComposeFlagsWeKnow(_ words: ArraySlice<String>) -> ArraySlice<String>? {
        var rest = words
        while let flag = rest.first, flag.hasPrefix("-") {
            let name = String(flag.prefix { $0 != "=" })
            let carriesItsValue = name != flag
            if composeFlagsThatTakeAValue.contains(name) {
                rest = rest.dropFirst(carriesItsValue ? 1 : 2)
            } else if composeFlagsThatStandAlone.contains(flag) {
                rest = rest.dropFirst()
            } else {
                return nil
            }
        }
        return rest
    }

    private static func runsInsideAComposeService(_ words: [String]) -> Bool {
        words.contains("docker-compose") || zip(words, words.dropFirst()).contains { $0 == "docker" && $1 == "compose" }
    }

    private static func isTestScriptName(_ name: String) -> Bool {
        let parts = name.split(whereSeparator: { $0 == ":" || $0 == "-" || $0 == "_" || $0 == "." }).map(String.init)
        if parts.contains(where: partsThatAreNotARun.contains) { return false }
        return parts.contains { $0 == "test" || $0 == "tests" || $0 == "spec" || $0 == "e2e" || $0 == "unittest" }
    }

    static func verdict(fromOutput output: String) -> Verdict? {
        if reportsFailedTests(output) { return .failed }
        let text = searchable(output)
        let weakMarks = ["assertionerror", "panicked at", "build failed", "traceback (most recent", "npm err!"]
        let passMarks = [
            " passed", "\nok ", "\nok\t", "\npass", "✓", "✔", "all tests passed", "0 failed", "0 failures", "test result: ok",
            "tests passed", " passing", "build succeeded", "build success",
        ]
        let troubled = matches(text, #"\b[1-9]\d*\s+errors?\b"#) || weakMarks.contains(where: text.contains)
        let passed = passMarks.contains(where: text.contains) || matches(text, #"\b(failed|failures?)\s*[:=]\s*0\b"#)
        if troubled { return passed ? nil : .failed }
        return passed ? .passed : nil
    }

    static func reportsFailedTests(_ output: String) -> Bool {
        let text = searchable(output)
        let marks = [
            "\nfail ", "\n fail ", "\nfail\t", "\nfail:", "\nfail\n", "--- fail", "✗", "✘", "\nnot ok ", "test failed", "tests failed",
        ]
        return matches(text, #"\b[1-9]\d*\s+(failed|failing|failures?)\b"#) || matches(text, #"\b(failed|failures?|errors?)\s*[:=]\s*[1-9]"#)
            || marks.contains(where: text.contains)
    }

    private static func isAChangeOfDirectoryThatWouldSayIfItFailed(_ words: [String]) -> Bool {
        changesOfDirectory.contains(words[0]) && !words.contains { $0.contains(">") }
    }

    static func reportsAFailedChangeOfDirectory(_ output: String) -> Bool {
        matches(searchable(output), #"\b(cd|pushd):"#)
    }

    private static func searchable(_ output: String) -> String {
        "\n" + output.lowercased() + "\n"
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
