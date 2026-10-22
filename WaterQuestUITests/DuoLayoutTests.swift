import XCTest

/// Walks every tab in each orientation and fold pose and captures screenshots.
///
/// Fold poses use the DEBUG-only `-SipliSimulatedFold book|tabletop` launch
/// argument, which draws a fake fold through the middle of the window. The
/// Simulator can't move the hinge from the command line, so this checks the
/// fold layouts; real hinge movement still needs a device or the Simulator app.
final class DuoLayoutTests: XCTestCase {
    private let orientations: [(String, UIDeviceOrientation)] = [
        ("portrait", .portrait),
        ("landscapeLeft", .landscapeLeft),
        ("landscapeRight", .landscapeRight),
        ("upsideDown", .portraitUpsideDown),
    ]

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    @MainActor func testTabsFlat() throws { try runTabs(pose: nil) }
    @MainActor func testTabsBookFold() throws { try runTabs(pose: "book") }
    @MainActor func testTabsTabletopFold() throws { try runTabs(pose: "tabletop") }

    @MainActor func testOnboardingFlat() throws { try runOnboarding(pose: nil) }
    @MainActor func testOnboardingBookFold() throws { try runOnboarding(pose: "book") }
    @MainActor func testOnboardingTabletopFold() throws { try runOnboarding(pose: "tabletop") }

    @MainActor func testOnboardingAllStepsFlat() throws { try runAllOnboardingSteps(pose: nil) }
    @MainActor func testOnboardingAllStepsTabletop() throws { try runAllOnboardingSteps(pose: "tabletop") }
    @MainActor func testSecondaryScreens() throws { try runSecondaryScreens(pose: nil) }
    @MainActor func testSecondaryScreensTabletop() throws { try runSecondaryScreens(pose: "tabletop") }

    // MARK: - Flows

    /// Walks onboarding up to (not into) the notification permission prompt.
    @MainActor
    private func runAllOnboardingSteps(pose: String?) throws {
        let app = launch(onboarded: false, pose: pose)
        let tag = pose ?? "flat"
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 15))
        app.buttons["Get started"].tap()
        settle()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Alex")
        settle()
        capture(app, "steps-\(tag)-1-name")
        app.keyboards.buttons.allElementsBoundByIndex.last?.tap() // dismiss
        settle(0.6)

        for index in 2...5 {
            let next = app.buttons["Continue"].firstMatch
            guard next.waitForExistence(timeout: 5) else {
                XCTFail("[\(tag)] Continue missing before step \(index)")
                return
            }
            next.tap()
            settle()
            capture(app, "steps-\(tag)-\(index)")
        }
        // One more Continue reaches the notifications step.
        if app.buttons["Continue"].firstMatch.exists {
            app.buttons["Continue"].firstMatch.tap()
            settle()
        }
        capture(app, "steps-\(tag)-6-notifications")
    }

    @MainActor
    private func runSecondaryScreens(pose: String?) throws {
        let app = launch(onboarded: true, pose: pose)
        let tag = pose ?? "flat"

        app.tabBars.buttons["Settings"].exists
            ? app.tabBars.buttons["Settings"].tap()
            : app.buttons["Settings"].firstMatch.tap()
        settle()
        let trophy = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Trophy Room'")).firstMatch
        if trophy.waitForExistence(timeout: 5) {
            trophy.tap()
            settle()
            capture(app, "secondary-\(tag)-trophy")
            // Trophy Room is pushed from Settings; re-tapping the selected
            // tab pops back (the Duo's back button lives in a side bar).
            (app.tabBars.buttons["Settings"].exists
                ? app.tabBars.buttons["Settings"]
                : app.buttons["Settings"].firstMatch).tap()
            settle()
        } else {
            XCTFail("[\(tag)] Trophy Room row missing")
        }

        // Scroll Settings to its lower sections.
        app.swipeUp(); settle(0.8)
        capture(app, "secondary-\(tag)-settings-lower")
        app.swipeUp(); settle(0.8)
        capture(app, "secondary-\(tag)-settings-bottom")

        // Paywall, via the premium beverage unlock in Log Intake.
        app.buttons["Log water intake"].tap()
        settle()
        let unlock = app.buttons["Unlock"].firstMatch
        if unlock.waitForExistence(timeout: 5) {
            unlock.tap()
            settle(2)
            capture(app, "secondary-\(tag)-paywall")
            app.swipeUp(); settle(0.8)
            capture(app, "secondary-\(tag)-paywall-lower")
        }
        app.terminate()
    }

    @MainActor
    private func runTabs(pose: String?) throws {
        let app = launch(onboarded: true, pose: pose)
        let tag = pose ?? "flat"

        for (name, orientation) in orientations {
            XCUIDevice.shared.orientation = orientation
            settle()

            for tab in ["Home", "Insights", "Diary", "Settings"] {
                let button = app.tabBars.buttons[tab].exists
                    ? app.tabBars.buttons[tab]
                    : app.buttons[tab].firstMatch
                guard button.waitForExistence(timeout: 5) else {
                    XCTFail("[\(tag)/\(name)] \(tab) tab missing")
                    continue
                }
                button.tap()
                settle()
                XCTAssertTrue(app.buttons["Log water intake"].isHittable,
                              "[\(tag)/\(name)/\(tab)] add button not reachable")
                capture(app, "\(tag)-\(name)-\(tab)")
            }

            // The intake sheet must stay usable in every pose.
            app.buttons["Log water intake"].tap()
            XCTAssertTrue(app.navigationBars["Log Intake"].waitForExistence(timeout: 5),
                          "[\(tag)/\(name)] Log Intake sheet missing")
            settle()
            capture(app, "\(tag)-\(name)-LogIntake")
            app.navigationBars["Log Intake"].buttons["Cancel"].tap()
            settle()
        }
    }

    @MainActor
    private func runOnboarding(pose: String?) throws {
        let app = launch(onboarded: false, pose: pose)
        let tag = pose ?? "flat"
        let start = app.buttons["Get started"]
        XCTAssertTrue(start.waitForExistence(timeout: 15), "Welcome step missing")

        for (name, orientation) in orientations {
            XCUIDevice.shared.orientation = orientation
            settle()
            XCTAssertTrue(start.isHittable, "[\(tag)/\(name)] Get started not reachable")
            capture(app, "onboarding-\(tag)-\(name)-welcome")
        }

        XCUIDevice.shared.orientation = .portrait
        settle()
        start.tap()
        settle()
        for (name, orientation) in orientations {
            XCUIDevice.shared.orientation = orientation
            settle()
            XCTAssertTrue(app.buttons["Continue"].firstMatch.exists, "[\(tag)/\(name)] Continue missing on name step")
            capture(app, "onboarding-\(tag)-\(name)-name")
        }
    }

    // MARK: - Helpers

    @MainActor
    private func launch(onboarded: Bool, pose: String?) -> XCUIApplication {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        var arguments = ["-hasOnboarded", onboarded ? "YES" : "NO"]
        if let pose { arguments += ["-SipliSimulatedFold", pose] }
        app.launchArguments = arguments
        app.launch()
        settle(2.5) // splash
        return app
    }

    private func settle(_ seconds: TimeInterval = 1.2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
