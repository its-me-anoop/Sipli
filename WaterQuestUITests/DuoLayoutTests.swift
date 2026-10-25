import XCTest
import UIKit

/// Walks every tab in each orientation and fold pose and captures screenshots.
///
/// Fold poses use the DEBUG-only `-SipliSimulatedFold book|tabletop` launch
/// argument, which draws a fake fold through the middle of the window. The
/// Simulator can't move the hinge from the command line, so this checks the
/// fold layouts; real hinge movement still needs a device or the Simulator app.
final class DuoLayoutTests: XCTestCase {
    private var orientations: [(String, UIDeviceOrientation)] {
        if ProcessInfo.processInfo.environment["SIPLI_NATIVE_COVER_LOCKED"] == "1" {
            return [("portrait", .portrait)]
        }
        return [
        ("portrait", .portrait),
        ("landscapeLeft", .landscapeLeft),
        ("landscapeRight", .landscapeRight),
        ("upsideDown", .portraitUpsideDown),
        ]
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    override func tearDown() {
        if ProcessInfo.processInfo.environment["SIPLI_NATIVE_COVER_LOCKED"] != "1",
           ProcessInfo.processInfo.environment["SIPLI_NATIVE_ROTATION"] != "1" {
            XCUIDevice.shared.orientation = .portrait
        }
        super.tearDown()
    }

    /// Run in Release too: opening Insights must survive repeated navigation
    /// and both chart timeframes with the simulator's existing hydration data.
    @MainActor
    func testInsightsRepeatedNavigation() {
        let app = launch(onboarded: true, pose: nil)
        for _ in 0..<3 {
            app.buttons["Insights"].firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 10))
            for label in ["30 Days", "7 Days"] {
                let timeframe = app.buttons[label].firstMatch
                if !timeframe.isHittable { app.swipeUp() }
                XCTAssertTrue(timeframe.waitForExistence(timeout: 5))
                timeframe.tap()
                XCTAssertEqual(app.state, .runningForeground)
            }
            app.buttons["Home"].firstMatch.tap()
            XCTAssertTrue(app.buttons["Log water intake"].waitForExistence(timeout: 5))
        }
    }

    @MainActor func testTabsFlat() throws { try runTabs(pose: nil) }
    @MainActor func testTabsBookFold() throws { try runTabs(pose: "book") }
    @MainActor func testHomeBottleBookFold() throws { try runTabs(pose: "book", tabs: ["Home"]) }
    @MainActor func testTabsTabletopFold() throws { try runTabs(pose: "tabletop") }

    @MainActor func testNativeIntakeBottomSheet() throws { try checkNativeIntakeSheet(landscape: false) }
    @MainActor func testNativeIntakeBottomSheetLandscape() throws { try checkNativeIntakeSheet(landscape: true) }

    @MainActor
    private func checkNativeIntakeSheet(landscape: Bool) throws {
        let app = launch(onboarded: true, pose: nil)
        if landscape { orient(name: "landscapeRight", to: .landscapeRight) }
        app.buttons["Log water intake"].tap()
        let bar = app.navigationBars["Log Intake"]
        XCTAssertTrue(bar.waitForExistence(timeout: 8))
        let save = app.buttons["Save Intake"]
        XCTAssertTrue(save.isHittable, "Save must remain reachable at the initial detent")
        if bar.frame.width >= 420 {
            let slider = app.sliders["Intake amount"]
            let beverage = app.staticTexts["Beverage"].firstMatch
            let amount = app.staticTexts["Amount"].firstMatch
            XCTAssertTrue(slider.isHittable, "The amount slider must fit without expanding")
            XCTAssertTrue(beverage.isHittable)
            XCTAssertGreaterThan(beverage.frame.minX, slider.frame.maxX)
            XCTAssertLessThan(amount.frame.minY - bar.frame.maxY, 64,
                              "Fold constraints must not leave a blank region above the controls")
            for quick in app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Quick log '")).allElementsBoundByIndex {
                XCTAssertTrue(quick.isHittable, "All quick presets must fit at the initial detent")
                XCTAssertLessThanOrEqual(quick.frame.maxY, save.frame.minY - 8,
                                         "Presets must clear the fixed save footer completely")
            }
            let beverageAction = app.buttons["Unlock"].exists ? app.buttons["Unlock"] : app.buttons["Water"]
            XCTAssertTrue(beverageAction.isHittable)
            let initialTop = bar.frame.minY
            let handle = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: 0, dy: -300)))
            settle()
            XCTAssertEqual(bar.frame.minY, initialTop, accuracy: 4,
                           "A fitted intake sheet must not expand into empty space")
            XCTAssertTrue(save.isHittable)
        }
        XCTAssertTrue(bar.buttons["Cancel"].isHittable)
        bar.buttons["Cancel"].tap()
        XCTAssertFalse(bar.exists)
        app.buttons["Log water intake"].tap()
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: app.windows.firstMatch.frame.height)))
        XCTAssertTrue(bar.waitForNonExistence(timeout: 5), "Native sheet should dismiss by swiping down")
        app.buttons["Log water intake"].tap()
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isHittable)
        capture(app, landscape ? "native-intake-bottom-sheet-landscape" : "native-intake-bottom-sheet-portrait")
    }

    @MainActor
    func testHomeOpenLandscapeColumns() throws {
        let app = launch(onboarded: true, pose: nil)
        orient(name: "landscapeRight", to: .landscapeRight)
        settle()
        let scroll = app.scrollViews["foldSharedScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        XCTAssertFalse(app.scrollViews["homeSummaryPane"].exists)
        XCTAssertFalse(app.scrollViews["homeCardsPane"].exists)
        let bottle = app.descendants(matching: .any).matching(identifier: "homeWaterBottle").firstMatch
        XCTAssertTrue(bottle.exists)
        XCTAssertLessThan(bottle.frame.maxY, app.windows.firstMatch.frame.maxY - 16)
        XCTAssertTrue(app.buttons["homeBadgeButton"].isHittable)
        XCTAssertTrue(scroll.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Three fresh quests'")).firstMatch.isHittable,
                      "Weekly quests should be visible beside the summary")
        capture(app, "home-open-landscape-page-columns")
    }

    @MainActor func testHomeWideSummaryTabletop() throws { try checkHomeWideSummary(pose: "tabletop") }
    @MainActor func testHomeWideSummaryOpen() throws { try checkHomeWideSummary(pose: nil) }

    @MainActor
    private func checkHomeWideSummary(pose: String?) throws {
        let app = launch(onboarded: true, pose: pose)
        let bottle = app.descendants(matching: .any).matching(identifier: "homeWaterBottle").firstMatch
        let badges = app.buttons["homeBadgeButton"]
        XCTAssertTrue(bottle.waitForExistence(timeout: 8))
        capture(app, "home-\(pose ?? "open")-summary-initial")
        XCTAssertTrue(badges.isHittable, "The badge control must stay visible beside the bottle")
        XCTAssertGreaterThan(bottle.frame.width, 100, "The wide layout should give the bottle a meaningful column")
        XCTAssertGreaterThan(badges.frame.minX, bottle.frame.midX,
                             "Summary controls should occupy the second column")
        XCTAssertLessThan(bottle.frame.maxY, app.windows.firstMatch.frame.maxY - 32)
        capture(app, "home-\(pose ?? "open")-balanced-summary")
        badges.tap()
        XCTAssertTrue(app.navigationBars["Trophy Room"].waitForExistence(timeout: 5))
    }

    @MainActor func testSettingsWideBook() throws { try checkSettingsColumns(pose: "book") }
    @MainActor func testSettingsWideFlat() throws { try checkSettingsColumns(pose: nil) }

    @MainActor
    private func checkSettingsColumns(pose: String?) throws {
        let app = launch(onboarded: true, pose: pose)
        orient(name: "landscapeRight", to: .landscapeRight)
        app.buttons["Settings"].firstMatch.tap()
        settle()
        let scroll = app.scrollViews["foldSharedScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        XCTAssertFalse(app.scrollViews["settingsProfilePane"].exists)
        XCTAssertFalse(app.scrollViews["settingsPreferencesPane"].exists)
        XCTAssertTrue(app.textFields["Your Name"].isHittable)
        var reached: Set<String> = []
        for _ in 0..<16 {
            for id in ["settingsGoalEnd", "settingsVersion"] {
                let footer = app.staticTexts[id].firstMatch
                if footer.exists && footer.isHittable && footer.frame.maxY < app.windows.firstMatch.frame.maxY - 32 {
                    reached.insert(id)
                }
            }
            if reached.count == 2 { break }
            scroll.swipeUp()
            settle(0.3)
        }
        XCTAssertEqual(reached.count, 2)
        capture(app, "settings-\(pose ?? "flat")-shared-scroll-footers")
    }

    @MainActor
    func testLandscapeSharedScrollingAllTabs() throws {
        let app = launch(onboarded: true, pose: nil)
        orient(name: "landscapeRight", to: .landscapeRight)
        for tab in ["Home", "Insights", "Diary", "Settings"] {
            app.buttons[tab].firstMatch.tap()
            settle()
            let shared = app.scrollViews["foldSharedScroll"]
            let scroll = shared.exists ? shared : app.scrollViews["insightsSingleScroll"]
            XCTAssertTrue(scroll.waitForExistence(timeout: 5), "\(tab) needs one shared landscape scroll")
            for id in ["homeSummaryPane", "homeCardsPane", "settingsProfilePane", "settingsPreferencesPane", "diaryCalendarPane", "diaryEntriesPane"] {
                XCTAssertFalse(app.scrollViews[id].exists, "\(tab) must not contain independent scrolling columns")
            }
            XCTAssertTrue(app.buttons["Log water intake"].isHittable)
        }
        capture(app, "all-tabs-landscape-shared-scroll")
    }

    @MainActor func testSettingsNarrowCover() throws { try checkSettingsSingleScroll(pose: nil) }
    @MainActor func testSettingsPortraitTabletop() throws { try checkSettingsSingleScroll(pose: "tabletop") }

    @MainActor
    private func checkSettingsSingleScroll(pose: String?) throws {
        let app = launch(onboarded: true, pose: pose)
        app.buttons["Settings"].firstMatch.tap()
        settle()
        let pane = app.scrollViews["settingsSinglePane"]
        XCTAssertTrue(pane.waitForExistence(timeout: 5))
        XCTAssertFalse(app.scrollViews["settingsProfilePane"].exists)
        XCTAssertFalse(app.scrollViews["settingsPreferencesPane"].exists)
        XCTAssertGreaterThan(pane.frame.height, app.windows.firstMatch.frame.height * 0.65)
        XCTAssertTrue(app.textFields["Your Name"].isHittable)
        capture(app, "settings-\(pose ?? "cover")-single-column")
        let footer = app.staticTexts["settingsVersion"]
        for _ in 0..<12 {
            if footer.exists && footer.isHittable { break }
            pane.swipeUp()
            settle(0.3)
        }
        XCTAssertTrue(footer.isHittable)
        capture(app, "settings-\(pose ?? "cover")-footer")
    }

    @MainActor func testInsightsScrollBoundaries() throws { try checkInsightsPageScroll(pose: "tabletop") }
    @MainActor func testInsightsWholePageScroll() throws { try checkInsightsPageScroll(pose: nil, requiresColumns: true) }

    @MainActor
    private func checkInsightsPageScroll(pose: String?, requiresColumns: Bool = false) throws {
        let app = launch(onboarded: true, pose: pose)
        orient(name: "landscapeRight", to: .landscapeRight)
        app.buttons["Insights"].firstMatch.tap()
        settle()
        let shared = app.scrollViews["foldSharedScroll"]
        if requiresColumns { XCTAssertTrue(shared.waitForExistence(timeout: 5)) }
        let scroll = shared.exists ? shared : app.scrollViews["insightsSingleScroll"]
        XCTAssertTrue(scroll.exists)
        XCTAssertFalse(app.scrollViews["insightsTrendsPane"].exists)
        XCTAssertFalse(app.scrollViews["insightsBreakdownsPane"].exists)
        if requiresColumns {
            let left = app.staticTexts["No data yet"].firstMatch
            let right = app.staticTexts["Daily target"].firstMatch
            XCTAssertTrue(left.isHittable)
            XCTAssertTrue(right.isHittable)
            let leftY = left.frame.minY
            let rightY = right.frame.minY
            scroll.swipeUp()
            settle()
            let leftChange = leftY - left.frame.minY
            let rightChange = rightY - right.frame.minY
            XCTAssertGreaterThan(leftChange, 30)
            XCTAssertGreaterThan(rightChange, 30)
            XCTAssertEqual(leftChange, rightChange, accuracy: 12,
                           "Both columns must move by the same scroll offset")
        }
        var reached: Set<String> = []
        for _ in 0..<16 {
            for id in ["insightsHeatmapEnd", "insightsStreaksEnd"] {
                let footer = app.staticTexts[id].firstMatch
                if footer.exists && footer.isHittable && footer.frame.maxY <= app.windows.firstMatch.frame.maxY - 32 {
                    reached.insert(id)
                }
            }
            if reached.count == 2 { break }
            scroll.swipeUp()
            settle(0.3)
        }
        XCTAssertEqual(reached.count, 2, "Both columns' footer content must remain reachable")
        capture(app, "insights-shared-scroll-footer")
    }

    @MainActor func testOnboardingFlat() throws { try runOnboarding(pose: nil) }
    @MainActor func testOnboardingBookFold() throws { try runOnboarding(pose: "book") }
    @MainActor func testOnboardingTabletopFold() throws { try runOnboarding(pose: "tabletop") }

    @MainActor func testOnboardingAllStepsFlat() throws { try runAllOnboardingSteps(pose: nil) }
    @MainActor func testOnboardingAllStepsBook() throws { try runAllOnboardingSteps(pose: "book") }
    @MainActor func testOnboardingAllStepsTabletop() throws { try runAllOnboardingSteps(pose: "tabletop") }
    @MainActor func testSecondaryScreens() throws { try runSecondaryScreens(pose: nil) }
    @MainActor func testSecondaryScreensBook() throws { try runSecondaryScreens(pose: "book") }
    @MainActor func testSecondaryScreensTabletop() throws { try runSecondaryScreens(pose: "tabletop") }

    // MARK: - Flows

    /// Walks every onboarding step, including the native notification prompt.
    @MainActor
    private func runAllOnboardingSteps(pose: String?) throws {
        let app = launch(onboarded: false, pose: pose)
        let tag = pose ?? "flat"
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 15))
        captureInOrientations(app, name: "steps-\(tag)-0-welcome", action: app.buttons["Get started"])
        app.buttons["Get started"].tap()
        settle()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Continue"].firstMatch.isEnabled, "A blank name must not enable Continue")
        field.tap()
        field.typeText("Alex")
        settle()
        captureInOrientations(app, name: "steps-\(tag)-1-name", action: app.buttons["Continue"].firstMatch)
        // Use the app-owned CTA. The Duo can expose keyboard controls on an
        // inactive display; blindly tapping the last keyboard button is invalid.
        XCTAssertTrue(app.buttons["Continue"].firstMatch.isHittable)

        for index in 2...5 {
            let next = app.buttons["Continue"].firstMatch
            guard next.waitForExistence(timeout: 5) else {
                XCTFail("[\(tag)] Continue missing before step \(index)")
                return
            }
            next.tap()
            settle()
            captureInOrientations(app, name: "steps-\(tag)-\(index)", action: app.buttons["Continue"].firstMatch)
        }
        // One more Continue reaches the notifications step.
        if app.buttons["Continue"].firstMatch.exists {
            app.buttons["Continue"].firstMatch.tap()
            settle()
        }
        let finish = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Start hydrating'")).firstMatch
        captureInOrientations(app, name: "steps-\(tag)-6-notifications", action: finish)
        XCTAssertTrue(finish.isHittable)
        finish.tap()
        settle(1)
        dismissSystemPermissionIfNeeded()
        XCTAssertTrue(app.buttons["Open Sipli"].waitForExistence(timeout: 10))
        captureInOrientations(app, name: "steps-\(tag)-7-done", action: app.buttons["Open Sipli"])
        XCTAssertTrue(app.buttons["Open Sipli"].isHittable)
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
        scrollUp(app); settle(0.8)
        capture(app, "secondary-\(tag)-settings-lower")
        for index in 1...5 {
            scrollUp(app); settle(0.4)
            capture(app, "secondary-\(tag)-settings-scroll-\(index)")
        }

        // Paywall, via the premium beverage unlock in Log Intake.
        app.buttons["Log water intake"].tap()
        settle()
        let unlock = app.buttons["Unlock"].firstMatch
        reveal(unlock, in: app)
        if unlock.isHittable {
            unlock.tap()
            settle(2)
            capture(app, "secondary-\(tag)-paywall")
            scrollUp(app); settle(0.8)
            capture(app, "secondary-\(tag)-paywall-lower")
            let close = app.buttons["Close premium plans"]
            XCTAssertTrue(close.isHittable, "Paywall close must remain reachable after scrolling")
            close.tap()
            XCTAssertTrue(app.navigationBars["Log Intake"].waitForExistence(timeout: 5))
        }
        app.terminate()
    }

    @MainActor
    private func runTabs(pose: String?, tabs: [String] = ["Home", "Insights", "Diary", "Settings"]) throws {
        let app = launch(onboarded: true, pose: pose)
        let tag = pose ?? "flat"

        for (name, orientation) in orientations {
            orient(name: name, to: orientation)
            settle()

            for tab in tabs {
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
                if tab == "Home" {
                    let bottle = app.descendants(matching: .any).matching(identifier: "homeWaterBottle").firstMatch
                    XCTAssertTrue(bottle.exists)
                    XCTAssertLessThanOrEqual(bottle.frame.maxY, app.windows.firstMatch.frame.maxY - 8,
                                             "[\(tag)/\(name)] bottle base is clipped below the display")
                }
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
            orient(name: name, to: orientation)
            settle()
            XCTAssertTrue(start.isHittable, "[\(tag)/\(name)] Get started not reachable")
            capture(app, "onboarding-\(tag)-\(name)-welcome")
        }

        orient(name: "portrait", to: .portrait)
        settle()
        start.tap()
        settle()
        for (name, orientation) in orientations {
            orient(name: name, to: orientation)
            settle()
            XCTAssertTrue(app.buttons["Continue"].firstMatch.exists, "[\(tag)/\(name)] Continue missing on name step")
            capture(app, "onboarding-\(tag)-\(name)-name")
        }
    }

    // MARK: - Helpers

    @MainActor
    private func launch(onboarded: Bool, pose: String?) -> XCUIApplication {
        let app = XCUIApplication()
        orient(name: "portrait", to: .portrait)
        var arguments = ["-hasOnboarded", onboarded ? "YES" : "NO"]
        if let pose { arguments += ["-SipliSimulatedFold", pose] }
        app.launchArguments = arguments
        // Continuous water motion has dedicated BottleFlowTests. Freeze that
        // renderer for layout captures so XCTest can settle tab transitions.
        app.launchEnvironment["SIPLI_BOTTLE_REDUCE_MOTION"] = "1"
        app.launch()
        settle(2.5) // splash
        return app
    }

    /// Optional Device Hub coordinator: the Duo's physical pose rotation is
    /// independent of XCUIDevice's sensor orientation on the current runtime.
    /// scripts/run-duo-ui-audit.py acknowledges each requested native rotation.
    @MainActor
    private func orient(name: String, to orientation: UIDeviceOrientation) {
        guard ProcessInfo.processInfo.environment["SIPLI_NATIVE_COVER_LOCKED"] != "1" else { return }
        guard ProcessInfo.processInfo.environment["SIPLI_NATIVE_ROTATION"] == "1" else {
            XCUIDevice.shared.orientation = orientation
            return
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SipliUIAudit", isDirectory: true)
        let nonce = UUID().uuidString
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try "\(nonce)\n\(name)".write(to: folder.appendingPathComponent("rotation-request.txt"), atomically: true, encoding: .utf8)
        } catch { XCTFail("Could not request native rotation: \(error)"); return }
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if (try? String(contentsOf: folder.appendingPathComponent("rotation-ack.txt"), encoding: .utf8)) == nonce { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTFail("Device Hub did not acknowledge native \(name) rotation")
    }

    @MainActor
    private func captureInOrientations(_ app: XCUIApplication, name: String, action: XCUIElement) {
        for (orientationName, orientation) in orientations {
            orient(name: orientationName, to: orientation)
            settle(0.6)
            dismissSystemPermissionIfNeeded()
            XCTAssertTrue(action.isHittable, "\(name)/\(orientationName): primary action is unreachable")
            if name.hasSuffix("-2"), name.contains("tabletop") || name.contains("book") {
                XCTAssertTrue(app.buttons["kg"].isHittable,
                              "\(name)/\(orientationName): weight unit selector is clipped")
            }
            capture(app, "\(name)-\(orientationName)")
        }
        orient(name: "portrait", to: .portrait)
        settle(0.3)
    }

    @MainActor
    private func dismissSystemPermissionIfNeeded() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        guard alert.exists else { return }
        let decline = alert.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Don'")).firstMatch
        if decline.exists { decline.tap() }
        else if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap() }
        settle(0.3)
    }

    @MainActor
    private func scrollUp(_ app: XCUIApplication) {
        if app.collectionViews.firstMatch.exists {
            app.collectionViews.firstMatch.swipeUp()
        } else if app.scrollViews.firstMatch.exists {
            app.scrollViews.firstMatch.swipeUp()
        } else {
            app.swipeUp()
        }
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            scrollUp(app)
        }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
    }

    private func settle(_ seconds: TimeInterval = 1.2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SipliUIAudit", isDirectory: true)
        var visibleDisplays = 0
        // Duo's default screenshot can be the powered-down cover display.
        // Capture each active screen and reject blank frames before accepting
        // visual evidence. Interaction assertions alone cannot validate layout.
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let screenshot = screen.screenshot()
            guard hasVisibleContent(screenshot) else { continue }
            visibleDisplays += 1
            let displayName = "\(name)-display-\(index)"
            let format = UIGraphicsImageRendererFormat()
            format.scale = screenshot.image.scale
            let visibleImage = UIGraphicsImageRenderer(size: screenshot.image.size, format: format).image { _ in
                screenshot.image.draw(in: CGRect(origin: .zero, size: screenshot.image.size))
            }
            let attachment = XCTAttachment(image: visibleImage)
            attachment.name = displayName
            attachment.lifetime = .keepAlways
            add(attachment)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard let png = visibleImage.pngData() else { XCTFail("Screenshot encoding failed"); continue }
                try png.write(to: directory.appendingPathComponent("\(displayName).png"))
            } catch {
                XCTFail("Could not save UI audit screenshot: \(error)")
            }
        }
        XCTAssertGreaterThan(visibleDisplays, 0, "\(name): every captured display was blank")
        let geometry = XCTAttachment(string: "orientation=\(XCUIDevice.shared.orientation.rawValue), window=\(app.windows.firstMatch.frame)")
        geometry.name = "\(name)-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
    }

    private func hasVisibleContent(_ screenshot: XCUIScreenshot) -> Bool {
        guard let image = screenshot.image.cgImage else { return false }
        var pixel: [UInt8] = [0, 0, 0, 0]
        return pixel.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return Int(bytes[0]) + Int(bytes[1]) + Int(bytes[2]) > 6
        }
    }
}
