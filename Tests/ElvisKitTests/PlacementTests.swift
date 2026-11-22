import Testing
@testable import ElvisKit

@Suite struct PlacementTests {
    @Test func hisCornerIsOnTheScreenItWasChosenOn() {
        #expect(Placement.cornerScreen(remembered: "side", among: ["main", "side"]) == 1)
    }

    @Test func hisCornerFallsBackToTheMainScreenWhenItsOwnIsGone() {
        #expect(Placement.cornerScreen(remembered: "side", among: ["main"]) == 0)
        #expect(Placement.cornerScreen(remembered: nil, among: ["main", "side"]) == 0)
    }
}
