import Testing

@testable import Frameless

@MainActor
struct UpdateCheckerTests {
    @Test(
        "a later version is newer, part by part",
        arguments: [("1.0.1", "1.0.0"), ("1.1", "1.0.9"), ("2.0.0", "1.9.9"), ("v1.2.0", "1.1.0"), ("1.0.0.1", "1.0")])
    func laterIsNewer(version: String, current: String) {
        #expect(UpdateChecker.isNewer(version, than: current))
    }

    @Test(
        "the same or an earlier version isn't newer",
        arguments: [("1.0.0", "1.0.0"), ("1.0", "1.0.0"), ("0.9.9", "1.0.0"), ("1.0.0", "1.10.0")])
    func sameOrEarlierIsNotNewer(version: String, current: String) {
        #expect(!UpdateChecker.isNewer(version, than: current))
    }
}
