import Testing
@testable import ElvisKit

@Suite struct GitRunsTests {
    @Test(arguments: [
        "git commit -m x", "git commit --amend --no-edit", "git add -A && git commit -m \"fix: a thing\"",
        "git -C ../other commit -m x", "git -c user.name=me commit -m x", "GIT_AUTHOR_DATE=now git commit -m x",
        "/usr/bin/git commit -m x", "git commit -m x && git status", "cd app && git commit -qm x",
    ])
    func recognisesACommit(command: String) {
        #expect(GitRuns.deed(command: command, exitStatus: 0) == .committed)
    }

    @Test(arguments: [
        "git push", "git push -u origin main", "git commit -m x && git push", "git push --force-with-lease",
        "git -C ../other push origin HEAD", "git add . && git commit -m x && git push && git status",
    ])
    func recognisesAPush(command: String) {
        #expect(GitRuns.deed(command: command, exitStatus: 0) == .pushed)
    }

    @Test(arguments: [
        "git status", "git log --oneline", "git commit --dry-run", "git push --dry-run", "git push -n", "git push origin --delete old",
        "git stash push", "git config push.default simple", "git push -nf", "git push origin :old-branch", "git push -fd origin old", "echo git commit", "gh pr create", "git", "git commit --help",
        "grep -r \"git push\" docs",
    ])
    func ignoresEverythingElse(command: String) {
        #expect(GitRuns.deed(command: command, exitStatus: 0) == nil)
    }

    @Test func nothingIsClaimedWhenTheCommandFailed() {
        #expect(GitRuns.deed(command: "git commit -m x", exitStatus: 1) == nil)
        #expect(GitRuns.deed(command: "git push", exitStatus: 128) == nil)
    }

    @Test func nothingIsClaimedWhenALaterCommandHidesHowItWent() {
        #expect(GitRuns.deed(command: "git commit -m x | tail -2", exitStatus: 0) == nil)
        #expect(GitRuns.deed(command: "git commit -m x; git status", exitStatus: 0) == nil)
        #expect(GitRuns.deed(command: "git push || true", exitStatus: 0) == nil)
        #expect(GitRuns.deed(command: "git push &", exitStatus: 0) == nil)
        #expect(GitRuns.deed(command: "git commit -m x && git push | tail -3", exitStatus: 0) == nil)
    }

    @Test func nothingIsClaimedForACommandThatMayHaveBeenSkipped() {
        #expect(GitRuns.deed(command: "git diff --cached --quiet || git commit -m x", exitStatus: 0) == nil)
        #expect(GitRuns.deed(command: "git fetch || git push", exitStatus: 0) == nil)
        #expect(GitRuns.deed(command: "git add . || true && git commit -m x", exitStatus: 0) == .committed)
    }
}
