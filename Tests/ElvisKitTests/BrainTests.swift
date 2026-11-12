import Testing
@testable import ElvisKit

@Suite struct BrainTests {
    @discardableResult
    private func run(_ brain: inout Brain, for seconds: Double) -> [Action] {
        var seen: [Action] = []
        var serial = brain.actionSerial
        for _ in 0..<Int(seconds * 30) {
            brain.tick(1.0 / 30)
            if brain.actionSerial != serial {
                serial = brain.actionSerial
                seen.append(brain.action)
            }
        }
        return seen
    }

    private func working(seed: UInt64 = 1) -> Brain {
        var brain = Brain(seed: seed)
        brain.handle(WorkEvent(.taskStarted, session: "s"))
        run(&brain, for: 3)
        return brain
    }

    @Test func settlesDownToSleepWhenNothingHappens() {
        var brain = Brain(seed: 3)
        run(&brain, for: 60)
        #expect(brain.action.isLyingDown)
        run(&brain, for: 300)
        #expect(brain.action.isAsleep)
    }

    @Test func boundsUpFromSleepWhenATaskStarts() {
        var brain = Brain(seed: 3)
        run(&brain, for: 400)
        brain.handle(WorkEvent(.taskStarted, session: "s"))
        #expect(brain.action == .startle)
        let next = run(&brain, for: 1)
        #expect(next.first == .boundUp)
        #expect(brain.mode == .working)
    }

    @Test func sniffsAndDigsWhileClaudeWorks() {
        var brain = working()
        brain.handle(WorkEvent(.toolStarted, session: "s", flavour: .edit))
        let seen = run(&brain, for: 20)
        #expect(seen.contains(.dig))
        #expect(brain.world.mud >= 0.03)
        #expect(brain.mode == .working)
    }

    @Test func waitsAtTheDoorUntilAnswered() {
        var brain = working()
        brain.handle(WorkEvent(.needsYou, session: "s", subject: "Bash:1"))
        #expect(brain.world.doorOpen)
        run(&brain, for: 12)
        #expect(brain.world.x == Yard.doorSpot)
        let waiting: [Action] = [.stare, .tiltHead, .pawDoor, .glanceDoor]
        #expect(waiting.contains(brain.action))

        brain.handle(WorkEvent(.toolFinished, session: "s", subject: "Read:9"))
        #expect(brain.mode == .waiting, "another tool finishing is not an answer")
        brain.handle(WorkEvent(.toolFinished, session: "s", subject: "Bash:1"))
        #expect(brain.mode == .working)
        #expect(brain.action == .relief)
        #expect(!brain.world.doorOpen)
    }

    @Test func aSiblingToolStartingStraightAwayIsNotAnAnswer() {
        var brain = working()
        brain.handle(WorkEvent(.needsYou, session: "s", subject: "Bash:1"))
        brain.handle(WorkEvent(.toolStarted, session: "s", flavour: .read, subject: "Read:2"))
        #expect(brain.mode == .waiting)
        run(&brain, for: 5)
        brain.handle(WorkEvent(.toolStarted, session: "s", flavour: .read, subject: "Read:3"))
        #expect(brain.mode == .working)
    }

    @Test func liesDownByTheDoorInSilenceWhenTheWaitIsLong() {
        var brain = working()
        brain.handle(WorkEvent(.needsYou, session: "s"))
        var whines = 0
        for _ in 0..<200 {
            run(&brain, for: 1)
            whines += brain.drainCues().count
        }
        #expect(brain.action == .lieByDoor)
        #expect(whines == 0)
        run(&brain, for: 40 * 60)
        #expect(brain.mode == .waiting, "he does not give up on an unanswered prompt")
    }

    @Test func aSubagentCarryingOnIsNotAnAnswer() {
        var brain = working()
        brain.handle(WorkEvent(.needsYou, session: "s", subject: "Bash:1"))
        run(&brain, for: 5)
        brain.handle(WorkEvent(.toolStarted, session: "s", flavour: .read, subject: "Read:2", agent: "helper"))
        #expect(brain.mode == .waiting)
    }

    @Test func pricksUpHisEarsWhenTheFirstHelperGoesOut() {
        var brain = working()
        brain.handle(WorkEvent(.helperStarted, session: "s", agent: "a1"))
        #expect(brain.action == .listen)
        let serial = brain.actionSerial
        brain.handle(WorkEvent(.helperStarted, session: "s", agent: "a2"))
        #expect(brain.actionSerial == serial, "the second helper is no surprise")
    }

    @Test func keepsAnEarOutOnlyWhileHelpersAreOut() {
        var brain = working(seed: 4)
        #expect(!run(&brain, for: 240).contains(.listen))
        brain.handle(WorkEvent(.helperStarted, session: "s", agent: "a1"))
        brain.handle(WorkEvent(.toolStarted, session: "s", flavour: .read, agent: "a1"))
        #expect(run(&brain, for: 240).filter { $0 == .listen }.count >= 3)
        brain.handle(WorkEvent(.helperFinished, session: "s", agent: "a1"))
        brain.handle(WorkEvent(.toolStarted, session: "s", flavour: .read))
        run(&brain, for: 10)
        #expect(!run(&brain, for: 240).contains(.listen))
    }

    @Test func theMenuCountsSessionsAndHelpersWithoutNamingThem() {
        var brain = Brain(seed: 1)
        #expect(brain.company == nil)
        brain.handle(WorkEvent(.taskStarted, session: "one"))
        #expect(brain.company == "1 session working")
        brain.handle(WorkEvent(.taskStarted, session: "two"))
        brain.handle(WorkEvent(.taskStarted, session: "three"))
        brain.handle(WorkEvent(.needsYou, session: "three"))
        brain.handle(WorkEvent(.helperStarted, session: "one", agent: "a1"))
        brain.handle(WorkEvent(.helperStarted, session: "one", agent: "a2"))
        brain.handle(WorkEvent(.helperStarted, session: "two", agent: "b1"))
        #expect(brain.company == "2 sessions working, 1 waiting for you, 3 helpers out")
        brain.handle(WorkEvent(.helperFinished, session: "one", agent: "a2"))
        brain.handle(WorkEvent(.taskFinished, session: "two"))
        #expect(brain.company == "1 session working, 1 waiting for you, 2 helpers out")
    }

    @Test func aHelperThatNeverReportsBackIsForgottenWithItsSession() {
        var ended = working()
        ended.handle(WorkEvent(.helperStarted, session: "s", agent: "a1"))
        ended.handle(WorkEvent(.sessionEnded, session: "s"))
        #expect(ended.company == nil)

        var silent = working()
        silent.handle(WorkEvent(.helperStarted, session: "s", agent: "a1"))
        silent.handle(WorkEvent(.taskFinished, session: "s"))
        #expect(silent.company == "1 helper out", "a helper may carry on in the background after Claude stops")
        run(&silent, for: 16 * 60)
        #expect(silent.company == nil)
    }

    @Test func stragglersFromAnEndedSessionAreIgnored() {
        var brain = working()
        brain.handle(WorkEvent(.sessionEnded, session: "s"))
        brain.handle(WorkEvent(.toolFinished, session: "s"))
        #expect(brain.mode == .calm)
        brain.handle(WorkEvent(.taskStarted, session: "s"))
        #expect(brain.mode == .working)
    }

    @Test func anInterruptedSessionSettlesOnceClaudeReportsIdle() {
        var brain = working()
        brain.handle(WorkEvent(.sessionIdle, session: "s"))
        #expect(brain.mode == .calm)
    }

    @Test func failingTestsDroopAndWhineButNotOnRepeat() {
        var brain = working()
        brain.handle(WorkEvent(.testsFailed, session: "s"))
        #expect(brain.action == .droop)
        #expect(brain.drainCues() == [.whine])
        #expect(brain.world.glum == 1)
        run(&brain, for: 10)
        brain.handle(WorkEvent(.testsFailed, session: "s"))
        #expect(brain.action == .droop)
        #expect(brain.drainCues().isEmpty)
    }

    @Test func passingTestsMeanFetch() throws {
        var brain = working()
        brain.handle(WorkEvent(.testsPassed, session: "s"))
        #expect(brain.world.ball?.state == .flying)
        var carried = false
        var seen: [Action] = []
        for _ in 0..<20 {
            seen += run(&brain, for: 1)
            carried = carried || brain.world.ball?.state == .carried
            if brain.action == .proudSit { break }
        }
        #expect(carried)
        #expect(seen.contains(.grabBall))
        #expect(brain.action == .proudSit)
        let ball = try #require(brain.world.ball)
        #expect(ball.state == .resting)
        #expect(abs(ball.x - Yard.home) < 25)

        brain.handle(WorkEvent(.testsPassed, session: "s"))
        #expect(brain.action == .wagAtYou, "a second pass straight away is a wag, not another fetch")
    }

    @Test func goingFromRedToGreenEarnsAYip() {
        var brain = working()
        brain.handle(WorkEvent(.testsFailed, session: "s"))
        #expect(brain.drainCues() == [.whine])
        run(&brain, for: 6)
        brain.handle(WorkEvent(.testsPassed, session: "s"))
        #expect(brain.action == .spin)
        #expect(brain.drainCues() == [.yip])
    }

    @Test func buriesABoneWhenWorkIsCommitted() {
        var brain = working()
        let mudBefore = brain.world.mud
        brain.handle(WorkEvent(.committed, session: "s"))
        #expect(brain.action == .buryBone)
        #expect(brain.mode == .working)
        run(&brain, for: 4)
        #expect(brain.world.mud > mudBefore + 0.02)

        brain.handle(WorkEvent(.committed, session: "s"))
        #expect(brain.action != .buryBone, "a second commit straight away is not worth another bone")
    }

    @Test func aCommitStraightAfterPassingTestsWaitsForTheFetchToFinish() {
        var brain = working()
        brain.handle(WorkEvent(.testsPassed, session: "s"))
        brain.handle(WorkEvent(.committed, session: "s"))
        #expect(brain.isFetching)
        let seen = run(&brain, for: 30)
        let proud = seen.firstIndex(of: .proudSit), burying = seen.firstIndex(of: .buryBone)
        #expect(proud != nil && burying == proud.map { $0 + 1 })
    }

    @Test func barksWhenWorkIsPushedAndOnlyWagsIfItHappensAgainSoon() {
        var brain = working()
        brain.handle(WorkEvent(.pushed, session: "s"))
        #expect(brain.action == .bark)
        #expect(brain.drainCues() == [.bark])
        run(&brain, for: 10)
        brain.handle(WorkEvent(.pushed, session: "s"))
        #expect(brain.action == .wagAtYou)
        #expect(brain.drainCues().isEmpty)
    }

    @Test func yourOwnCommitsAndPushesNeedNoSession() {
        var brain = Brain(seed: 5)
        run(&brain, for: 5)
        brain.handle(WorkEvent(.committed))
        #expect(brain.action == .buryBone)
        #expect(brain.mode == .calm)
    }

    @Test func keepsQuietAboutCommitsAndPushesWhileHeWaitsAtTheDoor() {
        var brain = working()
        brain.handle(WorkEvent(.needsYou, session: "s", subject: "Bash:1"))
        brain.handle(WorkEvent(.pushed, session: "other"))
        brain.handle(WorkEvent(.committed, session: "other"))
        let seen = run(&brain, for: 20)
        #expect(!seen.contains(.bark) && !seen.contains(.buryBone))
        #expect(brain.drainCues().isEmpty)
    }

    @Test func aCommitThatWasWaitingForApprovalIsAnAnswer() {
        var brain = working()
        brain.handle(WorkEvent(.needsYou, session: "s", subject: "Bash:1"))
        brain.handle(WorkEvent(.committed, session: "s", subject: "Bash:1"))
        #expect(brain.mode == .working)
        #expect(!brain.world.doorOpen)
    }

    @Test func testsFromTheShellNeedNoSession() {
        var brain = Brain(seed: 5)
        run(&brain, for: 5)
        brain.handle(WorkEvent(.testsPassed))
        #expect(brain.isFetching)
        #expect(brain.mode == .calm)
    }

    @Test func flopsAfterALongRunAndWagsAfterAShortOne() {
        var long = working()
        run(&long, for: 130)
        long.handle(WorkEvent(.taskFinished, session: "s"))
        #expect(long.action == .flop)
        #expect(long.mode == .calm)

        var short = working()
        short.handle(WorkEvent(.taskFinished, session: "s"))
        #expect(short.action == .wagAtYou)
    }

    @Test func oneSessionFinishingDoesNotEndAnothersWork() {
        var brain = working()
        brain.handle(WorkEvent(.taskStarted, session: "other"))
        run(&brain, for: 130)
        brain.handle(WorkEvent(.taskFinished, session: "s"))
        #expect(brain.mode == .working)
        #expect(brain.action != .flop)
    }

    @Test func aSessionThatGoesSilentIsEventuallyForgotten() {
        var brain = working()
        run(&brain, for: 14 * 60)
        #expect(brain.mode == .working)
        run(&brain, for: 2 * 60)
        #expect(brain.mode == .calm)
    }

    @Test func shakesOffMudOnceThingsAreCalm() {
        var brain = Brain(seed: 9)
        brain.restore(mud: 0.9)
        let seen = run(&brain, for: 30)
        #expect(seen.contains(.shake))
        #expect(brain.world.mud < 0.5)
    }

    @Test func strokingHimWithThePointerPetsHim() {
        var brain = Brain(seed: 2)
        run(&brain, for: 4)
        var petted = false
        for step in 0..<90 {
            brain.cursor(at: (brain.world.x + Double(step % 6), 15))
            brain.tick(1.0 / 30)
            petted = petted || brain.action == .petted
        }
        #expect(petted)
    }

    @Test func aParkedPointerIsNotAStroke() {
        var brain = Brain(seed: 2)
        run(&brain, for: 4)
        for _ in 0..<300 {
            brain.cursor(at: (brain.world.x, 15))
            brain.tick(1.0 / 30)
            #expect(brain.action != .petted)
        }
    }

    @Test func staysHeldWhateverClaudeDoesUntilPutDown() {
        var brain = working()
        brain.pickUp()
        brain.handle(WorkEvent(.testsPassed, session: "s"))
        brain.handle(WorkEvent(.needsYou, session: "s"))
        run(&brain, for: 60)
        #expect(brain.action == .held)
        #expect(brain.world.ball == nil, "nobody throws a ball for a dog who is being carried")
        #expect(brain.mode == .waiting)
        #expect(brain.world.doorOpen)

        brain.putDown(at: 60)
        #expect(brain.action == .landed)
        #expect(brain.world.x == 60)
        run(&brain, for: 15)
        #expect(brain.world.x == Yard.doorSpot, "once down, he goes to the door that opened while he was held")
    }

    @Test func stillHearsHowTheTestsWentWhileHeld() {
        var brain = working()
        brain.pickUp()
        brain.handle(WorkEvent(.testsFailed, session: "s"))
        #expect(brain.world.glum == 1)
        brain.handle(WorkEvent(.testsPassed, session: "s"))
        #expect(brain.world.glum == 0)
        #expect(brain.action == .held)
    }

    @Test func aClickIsAPatUnlessHeIsBusy() {
        var calm = Brain(seed: 2)
        run(&calm, for: 4)
        calm.pat()
        #expect(calm.action == .petted)

        var fetching = working()
        fetching.handle(WorkEvent(.testsPassed, session: "s"))
        let before = fetching.action
        fetching.pat()
        #expect(fetching.action == before)
    }

    @Test func isPutDownInsideTheYardHoweverFarHeWasCarried() {
        var brain = Brain(seed: 4)
        brain.pickUp()
        brain.putDown(at: 9000)
        #expect(brain.world.x == Yard.rightEdge)
        brain.putDown(at: 10)
        #expect(brain.world.x == Yard.rightEdge, "putting down a dog who is not held does nothing")
    }

    @Test func dropsTheBallWhenPickedUpMidFetch() throws {
        var brain = working()
        brain.handle(WorkEvent(.testsPassed, session: "s"))
        for _ in 0..<400 where brain.world.ball?.state != .carried { brain.tick(1.0 / 30) }
        #expect(brain.world.ball?.state == .carried)
        brain.pickUp()
        #expect(brain.world.ball?.state == .resting)
    }

    @Test func staysInsideTheYard() {
        for seed in 0..<6 as Range<UInt64> {
            var brain = working(seed: seed)
            for step in 0..<600 {
                if step % 97 == 0 { brain.handle(WorkEvent(.testsPassed, session: "s")) }
                if step % 41 == 0 { brain.handle(WorkEvent(.toolStarted, session: "s", flavour: .edit)) }
                brain.tick(0.1)
                #expect(brain.world.x > 0 && brain.world.x < Yard.width)
                if let ball = brain.world.ball { #expect(ball.x >= 0 && ball.x <= Yard.width) }
            }
        }
    }
}
