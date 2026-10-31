import XCTest

/// Checks the free-trial paywall: the timeline explains what happens next
/// and the call to action stays on screen without scrolling.
/// Runs against Products.storekit, where the annual plan has a one-month
/// free trial.
final class PaywallTrialUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTrialTimelineAndStickyCallToAction() throws {
        let app = XCUIApplication()
        // A recent "last update check" keeps the new-version popup away.
        app.launchArguments = [
            "-hasOnboarded", "YES",
            "-appUpdateLastCheck", "<date>2999-01-01T00:00:00Z</date>"
        ]
        app.launch()

        // Log Intake's "Unlock" button is always offered to free users.
        let logButton = app.buttons["Log water intake"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 10), app.debugDescription)
        // Launch popups (seasonal opt-in, new version) aren't under test.
        for label in ["Not for me", "Later"] {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 3) { button.tap() }
        }
        // Wait for the splash to clear before tapping.
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: logButton)
        XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 10), .completed)
        sleep(2)
        logButton.tap()
        XCTAssertTrue(app.navigationBars["Log Intake"].waitForExistence(timeout: 10), app.debugDescription)
        let unlock = app.buttons["Unlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 10), app.debugDescription)
        unlock.tap()

        let heading = app.staticTexts["How your free month works"]
        XCTAssertTrue(heading.waitForExistence(timeout: 15), app.debugDescription)

        let cta = app.buttons["Start my free month"]
        XCTAssertTrue(cta.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(cta.isHittable, "The trial button should be reachable without scrolling")
        attach(app, "paywall-trial-timeline")

        // Switching to monthly (no trial) swaps the timeline for the feature list.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Monthly'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Sipli Premium"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(heading.exists)
        attach(app, "paywall-monthly")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
