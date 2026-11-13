import Testing
@testable import ElvisKit

@Suite struct TestRunsTests {
    @Test(arguments: [
        "npm test", "npm run test:unit", "yarn test --watch=false", "pnpm test", "bun test", "npx vitest run",
        "pytest -q", "python -m pytest tests/", "uv run pytest", "poetry run pytest -x", "python3 -m unittest",
        "go test ./...", "cargo test", "cargo nextest run", "swift test", "make test", "just test",
        "cd api && npm test", "CI=1 npm test", "bundle exec rspec", "./gradlew test", "mvn -q verify",
        "dotnet test", "mix test", "deno test", "npx playwright test", "make test -Xswiftc -plugin-path",
        "FOO=bar BAZ=1 pytest", "time go test ./pkg/...", "xcodebuild test -scheme App",
        "php artisan test", "php vendor/bin/phpunit",
    ])
    func recognisesTestRuns(command: String) {
        #expect(TestRuns.isTestCommand(command))
    }

    @Test(arguments: [
        "ls", "git status", "npm install", "npm run build", "cat test.py", "grep -r test src", "echo pytest",
        "go build ./...", "cargo build", "swift build", "make", "python script.py", "rm -rf tests",
        "git commit -m \"fix test\"", "npx playwright install", "code tests/", "npm run dev",
        "make test-data", "make -C tests build", "rake db:test:prepare", "pytest --collect-only", "pytest --version",
        "cargo test --no-run", "npm run test:setup", "swift test --list-tests",
        "php artisan migrate", "php tests/seed.php",
    ])
    func ignoresEverythingElse(command: String) {
        #expect(!TestRuns.isTestCommand(command))
    }

    @Test func exitStatusDecidesWhenNothingHidesIt() {
        #expect(TestRuns.verdict(command: "npm test", exitStatus: 0, output: nil) == .passed)
        #expect(TestRuns.verdict(command: "npm test", exitStatus: 1, output: nil) == .failed)
        #expect(TestRuns.verdict(command: "cd app && pytest 2>&1", exitStatus: 0, output: nil) == .passed)
        #expect(TestRuns.verdict(command: "npm test && echo done", exitStatus: 0, output: nil) == .passed)
        #expect(TestRuns.verdict(command: "ls", exitStatus: 1, output: nil) == nil)
    }

    @Test func aPipeHidesTheStatusSoTheOutputDecides() {
        let piped = "npm test 2>&1 | tail -20"
        #expect(TestRuns.verdict(command: piped, exitStatus: 0, output: nil) == nil)
        #expect(TestRuns.verdict(command: piped, exitStatus: 0, output: "Tests: 1 failed, 12 passed, 13 total") == .failed)
        #expect(TestRuns.verdict(command: piped, exitStatus: 0, output: "Tests: 13 passed, 13 total") == .passed)
        #expect(TestRuns.verdict(command: piped, exitStatus: 0, output: "compiling...") == nil)
        #expect(TestRuns.verdict(command: "pytest || true", exitStatus: 0, output: "===== 2 failed, 3 passed in 0.4s =====") == .failed)
        #expect(TestRuns.verdict(command: "go test ./... ; echo finished", exitStatus: 0, output: "--- FAIL: TestThing (0.00s)\nFAIL\nfinished") == .failed)
        #expect(TestRuns.verdict(command: "cargo test | tail -3", exitStatus: 0, output: "test result: ok. 5 passed; 0 failed; 0 ignored") == .passed)
        #expect(TestRuns.verdict(command: "swift test 2>&1 | tail -4", exitStatus: 0, output: "✔ Test run with 9 tests in 2 suites passed after 0.004 seconds.") == .passed)
    }

    @Test func aHiddenStatusIsNeverBlamedOnTheTests() {
        #expect(TestRuns.verdict(command: "npm test 2>&1 | grep -E 'fail|error'", exitStatus: 1, output: "") == nil)
        #expect(TestRuns.verdict(command: "npm test; git diff --exit-code", exitStatus: 1, output: nil) == nil)
        #expect(TestRuns.verdict(command: "npm test | tail", exitStatus: 1, output: "Tests: 13 passed, 13 total") == .passed)
    }

    @Test func aRunThatMayHaveBeenSkippedIsJudgedByItsOutputAlone() {
        #expect(TestRuns.verdict(command: "test -f .skip || npm test", exitStatus: 0, output: nil) == nil)
        #expect(TestRuns.verdict(command: "test -f .skip || npm test", exitStatus: 0, output: "") == nil)
        #expect(TestRuns.verdict(command: "test -f .skip || npm test", exitStatus: 0, output: "Tests: 13 passed, 13 total") == .passed)
        #expect(TestRuns.verdict(command: "test -f .skip || npm test", exitStatus: 1, output: "Tests: 1 failed, 12 passed, 13 total") == .failed)
    }

    @Test func aRunnerThatNeverStartedOrWasKilledSaysNothing() {
        #expect(TestRuns.verdict(command: "pytest", exitStatus: 127, output: nil) == nil)
        #expect(TestRuns.verdict(command: "pytest", exitStatus: 130, output: nil) == nil)
        #expect(TestRuns.verdict(command: "pytest", exitStatus: 143, output: nil) == nil)
        #expect(TestRuns.verdict(command: "pytest", exitStatus: 2, output: nil) == .failed)
    }

    @Test func aFailedChainIsBlamedOnTheTestsOnlyWhenTheOutputReportsThemFailing() {
        #expect(TestRuns.verdict(command: "cd missing && npm test", exitStatus: 1, output: "cd: no such file or directory: missing") == nil)
        #expect(TestRuns.verdict(command: "cd missing && npm test", exitStatus: 1, output: nil) == nil)
        #expect(TestRuns.verdict(command: "npm run build && npm test", exitStatus: 1, output: "Found 3 errors.\nnpm ERR! build failed") == nil)
        #expect(TestRuns.verdict(command: "npm test && git diff --exit-code", exitStatus: 1, output: "Tests: 13 passed, 13 total") == nil)
        #expect(TestRuns.verdict(command: "cd app && npm test", exitStatus: 1, output: "Tests: 1 failed, 12 passed, 13 total") == .failed)
        #expect(TestRuns.verdict(command: "npm test && echo done", exitStatus: 1, output: "Tests: 1 failed, 12 passed, 13 total") == .failed)
    }

    @Test func aFailureAfterOnlyAChangeOfDirectoryIsTheRunnersHoweverItReadsUnlessTheChangeItselfFailed() {
        #expect(TestRuns.verdict(command: "cd app && npm test", exitStatus: 1, output: "src/a.ts(3,1): error TS2304: Cannot find name 'foo'.") == .failed)
        #expect(TestRuns.verdict(command: "cd pkg && swift test", exitStatus: 1, output: "error: emit-module command failed with exit code 1") == .failed)
        #expect(TestRuns.verdict(command: "cd a && pushd b && pytest", exitStatus: 2, output: "ImportError while importing test module") == .failed)
        #expect(TestRuns.verdict(command: "cd missing && npm test", exitStatus: 1, output: "(eval):cd:1: no such file or directory: missing") == nil)
        #expect(TestRuns.verdict(command: "cd missing && npm test", exitStatus: 1, output: "bash: line 1: cd: missing: No such file or directory") == nil)
        #expect(TestRuns.verdict(command: "cd app && npm test", exitStatus: 1, output: nil) == nil, "with no output there is no telling which step failed")
        #expect(TestRuns.verdict(command: "cd missing 2>/dev/null && npm test", exitStatus: 1, output: "") == nil, "a silenced change of directory could fail without a word")
        #expect(TestRuns.verdict(command: "cd app && npm run build && npm test", exitStatus: 1, output: "error TS2304: Cannot find name 'foo'.") == nil)
        #expect(TestRuns.verdict(command: "cd app && npm test && echo done", exitStatus: 1, output: "error TS2304: Cannot find name 'foo'.") == nil)
    }

    @Test func aChainThatSucceedsMeansTheTestsPassed() {
        #expect(TestRuns.verdict(command: "cd app && npm test", exitStatus: 0, output: nil) == .passed)
        #expect(TestRuns.verdict(command: "npm run build && npm test && echo done", exitStatus: 0, output: nil) == .passed)
    }

    @Test func aStepThatCannotStopTheRunnerLeavesTheStatusToTheTests() {
        #expect(TestRuns.verdict(command: "cd app; npm test", exitStatus: 1, output: nil) == .failed)
        #expect(TestRuns.verdict(command: "npm run build && echo built; npm test", exitStatus: 1, output: nil) == .failed)
    }

    @Test func outputIsReadByItsCountsNotItsVocabulary() {
        let piped = "mvn test | tail"
        #expect(TestRuns.verdict(command: piped, exitStatus: 0, output: "Tests run: 5, Failures: 0, Errors: 0, Skipped: 0\nBUILD SUCCESS") == .passed)
        #expect(TestRuns.verdict(command: piped, exitStatus: 0, output: "Tests run: 5, Failures: 2, Errors: 0, Skipped: 0") == .failed)
        #expect(TestRuns.verdict(command: "dotnet test | tail", exitStatus: 0, output: "Failed!  - Failed:     1, Passed:     5, Skipped:     0") == .failed)
        #expect(TestRuns.verdict(command: "dotnet test | tail", exitStatus: 0, output: "Passed!  - Failed:     0, Passed:     6, Skipped:     0") == .passed)
        #expect(TestRuns.verdict(command: "npm test | tail", exitStatus: 0, output: "GET /x 500 error\nTests: 5 passed, 5 total") == nil)
        #expect(TestRuns.verdict(command: "pytest | tail", exitStatus: 0, output: "===== 2 passed, 1 error in 0.3s =====") == nil)
        #expect(TestRuns.verdict(command: "go test ./... | tail -2", exitStatus: 0, output: "ok  \tpkg/a\t0.2s\nFAIL") == .failed)
    }

    @Test func redirectsAreNotPipes() {
        #expect(TestRuns.verdict(command: "pytest > out.txt 2>&1", exitStatus: 0, output: nil) == .passed)
        #expect(TestRuns.verdict(command: "pytest &> out.txt", exitStatus: 0, output: nil) == .passed)
        #expect(TestRuns.verdict(command: "pytest &", exitStatus: 0, output: nil) == nil)
    }
}
