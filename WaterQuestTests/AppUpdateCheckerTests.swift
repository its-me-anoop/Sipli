import XCTest
@testable import Sipli

@MainActor
final class AppUpdateCheckerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        suite = "AppUpdateCheckerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func update(_ v: String) -> AppUpdate {
        AppUpdate(version: v, releaseNotes: "", storeURL: URL(string: "https://apps.apple.com/app/id1")!)
    }

    func test_versionComparison_isNumeric() {
        XCTAssertTrue(AppUpdateChecker.isVersion("6.2", newerThan: "6.1"))
        XCTAssertTrue(AppUpdateChecker.isVersion("6.10", newerThan: "6.9"))
        XCTAssertTrue(AppUpdateChecker.isVersion("7.0", newerThan: "6.9.9"))
        XCTAssertFalse(AppUpdateChecker.isVersion("6.1", newerThan: "6.1.0"))
        XCTAssertFalse(AppUpdateChecker.isVersion("6.0", newerThan: "6.1"))
    }

    func test_offersOnlyNewerVersions() {
        let checker = AppUpdateChecker(defaults: defaults, currentVersion: "6.1")
        XCTAssertTrue(checker.shouldOffer(update("6.2"), now: Date()))
        XCTAssertFalse(checker.shouldOffer(update("6.1"), now: Date()))
    }

    func test_later_snoozesSameVersionForThreeDays() {
        let checker = AppUpdateChecker(defaults: defaults, currentVersion: "6.1")
        let now = Date()
        checker.pendingUpdate = update("6.2")
        checker.remindLater(now: now)
        XCTAssertNil(checker.pendingUpdate)
        XCTAssertFalse(checker.shouldOffer(update("6.2"), now: now.addingTimeInterval(60 * 60)))
        XCTAssertTrue(checker.shouldOffer(update("6.3"), now: now.addingTimeInterval(60 * 60)))
        XCTAssertTrue(checker.shouldOffer(update("6.2"), now: now.addingTimeInterval(AppUpdateChecker.snoozeInterval + 1)))
    }

    func test_parse_readsLookupResponse() throws {
        let json = """
        {"resultCount":1,"results":[{"version":"6.2","releaseNotes":"Fixes.\\n","trackViewUrl":"https://apps.apple.com/gb/app/sipli/id6758851574"}]}
        """
        let parsed = try XCTUnwrap(AppUpdateChecker.parse(Data(json.utf8)))
        XCTAssertEqual(parsed.version, "6.2")
        XCTAssertEqual(parsed.releaseNotes, "Fixes.")
        XCTAssertEqual(parsed.storeURL.absoluteString, "https://apps.apple.com/gb/app/sipli/id6758851574")
        XCTAssertNil(AppUpdateChecker.parse(Data(#"{"resultCount":0,"results":[]}"#.utf8)))
    }
}
