import Testing
@testable import ElvisKit

@Suite struct VersionTests {
    @Test func anEarlierReleaseIsOlder() {
        #expect(Version.isOlder("0.2.1", than: "0.3.0"))
        #expect(Version.isOlder("0.9.0", than: "0.10.0"))
        #expect(Version.isOlder("0.2", than: "0.2.1"))
    }

    @Test func theSameReleaseOrALaterOneIsNotOlder() {
        #expect(!Version.isOlder("0.3.0", than: "0.3.0"))
        #expect(!Version.isOlder("0.10.0", than: "0.9.0"))
        #expect(!Version.isOlder("1.0.0", than: "0.10.0"))
    }

    @Test func anElvisWhoRecordedNoVersionIsOlderThanAnyRelease() {
        #expect(Version.isOlder("", than: "0.0.1"))
    }

    @Test func somethingThatIsNotAVersionIsNotCalledOlder() {
        #expect(!Version.isOlder("not a version", than: "0.3.0"))
    }
}
