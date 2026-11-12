import Foundation

public enum TestRuns {
    public enum Verdict: Equatable, Sendable {
        case passed, failed
    }

    public static func verdict(command: String, exitStatus: Int, output: String?) -> Verdict? {
        guard let run = testSegment(in: command) else { return nil }
        if run.statusIsMasked { return output.flatMap(verdict(fromOutput:)) }
        if exitStatus == 0 { return .passed }
        // 126 and 127 mean the runner never started; 128 and above mean a signal ended it.
        if exitStatus >= 126 { return nil }
        return .failed
    }

    public static func isTestCommand(_ command: String) -> Bool {
        testSegment(in: command) != nil
    }

    struct Segment {
        var statusIsMasked: Bool
    }

    static func testSegment(in command: String) -> Segment? {
        let pieces = split(command)
        guard let index = pieces.firstIndex(where: { isTestInvocation($0.words) }) else { return nil }
        let masked = pieces[index...].dropLast().contains { $0.joiner != "&&" } || pieces.last?.joiner == "&"
        return Segment(statusIsMasked: masked)
    }

    struct Piece {
        var words: [String]
        /// The operator that follows this piece, or "" for the last one.
        var joiner: String
    }

    static func split(_ command: String) -> [Piece] {
        var pieces: [Piece] = []
        var current = ""
        var quote: Character?
        let chars = Array(command)
        var i = 0
        func flush(_ joiner: String) {
            let words = current.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).map(String.init)
            if !words.isEmpty || !joiner.isEmpty { pieces.append(Piece(words: words, joiner: joiner)) }
            current = ""
        }
        while i < chars.count {
            let c = chars[i]
            if let q = quote {
                if c == q { quote = nil }
                current.append(c)
            } else if c == "\"" || c == "'" {
                quote = c
                current.append(c)
            } else if c == "\\", i + 1 < chars.count {
                current.append(chars[i + 1])
                i += 1
            } else if c == "&" || c == "|" {
                if i + 1 < chars.count, chars[i + 1] == c {
                    flush(String([c, c]))
                    i += 1
                } else if c == "&", current.hasSuffix(">") || (i + 1 < chars.count && chars[i + 1] == ">") {
                    // Part of a redirect such as `2>&1` or `&>log`, not a background operator.
                    current.append(c)
                } else {
                    flush(String(c))
                }
            } else if c == ";" || c == "\n" {
                flush(";")
            } else {
                current.append(c)
            }
            i += 1
        }
        flush("")
        return pieces.filter { !$0.words.isEmpty }
    }

    private static let wrappers: Set<String> = [
        "time", "sudo", "command", "exec", "nice", "env", "caffeinate", "npx", "bunx", "pnpx", "dotenv", "arch", "xcrun",
    ]
    private static let twoWordWrappers: Set<String> = [
        "uv run", "poetry run", "pipenv run", "pdm run", "hatch run", "bundle exec", "pnpm exec", "yarn exec", "npm exec",
        "pnpm dlx", "yarn dlx", "rye run", "mise exec", "nix-shell --run", "docker-compose exec",
    ]
    private static let runners: Set<String> = [
        "pytest", "py.test", "jest", "vitest", "mocha", "ava", "tap", "jasmine", "karma", "rspec", "phpunit", "pest",
        "ctest", "tox", "nox", "nosetests", "behave", "cucumber", "busted", "bats", "ginkgo", "gotestsum", "nextest",
        "playwright", "cypress", "minitest", "unittest",
    ]
    private static let toolsWithTestVerb: Set<String> = [
        "npm", "yarn", "pnpm", "bun", "deno", "go", "cargo", "swift", "make", "gmake", "just", "task", "mvn", "mvnw",
        "gradle", "gradlew", "dotnet", "mix", "rails", "rake", "bazel", "buck", "pants", "turbo", "nx", "lerna", "zig",
        "stack", "cabal", "lein", "sbt", "flutter", "dart", "composer", "xcodebuild", "tuist", "elixir", "ng", "forge",
        "hardhat", "melos", "moon", "rush", "wasm-pack", "pixi", "invoke", "artisan",
    ]
    private static let testVerbs: Set<String> = [
        "test", "tests", "check", "spec", "t", "tst", "unittest", "unit", "e2e", "integration", "verify", "nextest", "ci",
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
        if tool.hasPrefix("python") || tool == "py" {
            let all = words.dropFirst().map { $0.lowercased() }
            if let m = all.firstIndex(of: "-m"), all.index(after: m) < all.endIndex {
                return ["pytest", "unittest", "nose", "nose2", "tox", "nox"].contains(all[all.index(after: m)])
            }
            return false
        }
        guard toolsWithTestVerb.contains(tool) else { return false }
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
            return testVerbs.contains(verb)
        }
    }

    private static func isTestScriptName(_ name: String) -> Bool {
        let parts = name.split(whereSeparator: { $0 == ":" || $0 == "-" || $0 == "_" || $0 == "." }).map(String.init)
        if parts.contains(where: partsThatAreNotARun.contains) { return false }
        return parts.contains { $0 == "test" || $0 == "tests" || $0 == "spec" || $0 == "e2e" || $0 == "unittest" }
    }

    /// Reads a verdict from runner output. A clear failure count or failure mark wins. A vaguer sign of trouble
    /// alongside a pass summary is treated as unknown, because staying quiet beats celebrating a failure.
    static func verdict(fromOutput output: String) -> Verdict? {
        let text = "\n" + output.lowercased() + "\n"
        let strongMarks = [
            "\nfail ", "\n fail ", "\nfail\t", "\nfail:", "\nfail\n", "--- fail", "✗", "✘", "\nnot ok ", "test failed", "tests failed",
        ]
        if matches(text, #"\b[1-9]\d*\s+(failed|failing|failures?)\b"#) || matches(text, #"\b(failed|failures?|errors?)\s*[:=]\s*[1-9]"#)
            || strongMarks.contains(where: text.contains) {
            return .failed
        }
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

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
