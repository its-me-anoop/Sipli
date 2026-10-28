import XCTest
import UIKit

/// Run against a dedicated simulator seeded with an empty day and a 2,000 ml
/// goal. The host seeds its own sandbox; these tests never reset user data.
final class BottleFlowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testBottleCompanionFlow() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        let namespace = UUID().uuidString
        launch(app, environment: ["SIPLI_COMPANION_UI_NAMESPACE": namespace,
                                  "SIPLI_BOTTLE_REDUCE_MOTION": "1"])
        if app.buttons["Not for me"].waitForExistence(timeout: 3) { app.buttons["Not for me"].tap() }
        let entry = app.buttons.containing(.staticText, identifier: "Track your real bottle").firstMatch
        if !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription)
        entry.tap()
        XCTAssertTrue(app.buttons["Start with a full bottle"].waitForExistence(timeout: 5))
        capture(app, "companion-setup-portrait")
        app.buttons["Start with a full bottle"].tap()
        app.buttons["Half"].tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Log consumed water"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Log consumed water"].isEnabled)
        app.buttons["Log consumed water"].tap()
        XCTAssertFalse(app.buttons["Log consumed water"].isEnabled)
        capture(app, "companion-half-portrait")
        app.terminate()
        app.launch()
        let update = app.buttons.containing(.staticText, identifier: "Update water remaining").firstMatch
        if !update.isHittable { app.swipeUp() }
        update.tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["Finished bottle"].waitForExistence(timeout: 5))
        app.buttons["Finished bottle"].tap()
        XCTAssertFalse(app.buttons["Finished bottle"].isEnabled)
        app.swipeUp()
        app.buttons["Undo last bottle action"].tap()
        XCTAssertTrue(app.buttons["Finished bottle"].isEnabled)
        XCUIDevice.shared.orientation = .landscapeLeft
        capture(app, "companion-landscape")
        for _ in 0..<3 {
            if app.buttons["Finished bottle"].isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(app.buttons["Finished bottle"].isHittable)
        capture(app, "companion-landscape-controls")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["Done"].tap()
        app.terminate()
    }

    @MainActor
    func testNativeShareScreen() throws {
        let app = XCUIApplication()
        launch(app)
        app.buttons["Share today's progress"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10))
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "native-share-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        capture(app, "native-share-screen")
        let close = app.buttons["header.closeButton"]
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCTAssertTrue(app.buttons["Log water intake"].isHittable)
        app.terminate()
    }

    /// Storefront captures use a separately seeded day with 1,000 ml logged.
    @MainActor
    func testStorefrontScreenshots() throws {
        let app = XCUIApplication()
        launch(app)
        assertRemaining(50, in: app)
        capture(app, "store-home-half")

        app.buttons["Diary"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 10), app.debugDescription)
        capture(app, "store-diary")

        app.buttons["Insights"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Insights"].waitForExistence(timeout: 10), app.debugDescription)
        capture(app, "store-insights")

        goHome(app)
        app.buttons["Log water intake"].tap()
        XCTAssertTrue(app.navigationBars["Log Intake"].waitForExistence(timeout: 10), app.debugDescription)
        capture(app, "store-log")
    }

    /// Run with a separate 2,750 ml fixture and no preunlocked achievements.
    @MainActor
    func testAchievementAndSharingScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasOnboarded", "YES"]
        app.launch()
        app.buttons["Log water intake"].tap()
        let quickLog = app.buttons["Quick log 250 millilitres of Water"]
        XCTAssertTrue(quickLog.waitForExistence(timeout: 10))
        quickLog.tap()
        let keepGoing = app.buttons["Keep going"]
        XCTAssertTrue(keepGoing.waitForExistence(timeout: 10), app.debugDescription)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: keepGoing)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed, app.debugDescription)
        capture(app, "achievement-unlocked")
        XCTAssertTrue(keepGoing.isHittable)
        for _ in 0..<12 {
            if !keepGoing.exists { break }
            keepGoing.tap()
            Thread.sleep(forTimeInterval: 0.4)
        }
        let share = app.buttons["Share today's progress"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        Thread.sleep(forTimeInterval: 3)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "daily-share-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        capture(app, "daily-share-sheet")
        // Inspect only: no external destination is selected.
        app.terminate()
    }

    @MainActor
    func testRemainingWaterBottleFlow() throws {
        let app = XCUIApplication()
        launch(app)
        assertRemaining(100, in: app)
        capture(app, "01-Full-before-any-drinks")

        // A rapid second tap during confirmation must not create a second log.
        log(500, in: app, rapidTap: true)
        assertRemaining(75, in: app)
        capture(app, "02-After-500ml")
        log(500, in: app)
        assertRemaining(50, in: app)
        capture(app, "03-Half-after-1000ml")

        // Simulator Core Motion injection exercises the same gravity input
        // and renderer as the device sensor. Physical-device sensing is a
        // separate verification boundary.
        launch(app, environment: [
            "SIPLI_BOTTLE_GRAVITY_X": "-0.5",
            "SIPLI_BOTTLE_GRAVITY_Y": "-0.8660254"
        ])
        assertRemaining(50, in: app)
        capture(app, "04-Half-with-left-gravity")
        launch(app, environment: [
            "SIPLI_BOTTLE_GRAVITY_X": "0.5",
            "SIPLI_BOTTLE_GRAVITY_Y": "-0.8660254"
        ])
        assertRemaining(50, in: app)
        capture(app, "05-Half-with-right-gravity")

        launch(app, environment: ["SIPLI_BOTTLE_REDUCE_MOTION": "1"])
        assertRemaining(50, in: app)
        capture(app, "06-Half-reduced-motion")
        log(500, in: app)
        assertRemaining(25, in: app)
        capture(app, "07-Reduced-motion-after-drink")
        deleteEntry(500, in: app)
        assertRemaining(50, in: app)
        capture(app, "08-Delete-restores-water")

        launch(app)
        assertRemaining(50, in: app)
        editEntry(500, toSliderPosition: 1, in: app)
        assertRemaining(15, in: app) // 500 + 1,200 ml
        capture(app, "09-Edit-increase-drains-water")
        editEntry(1200, toSliderPosition: 0, in: app)
        assertRemaining(70, in: app) // 500 + 100 ml
        capture(app, "10-Edit-decrease-restores-water")
        deleteEntry(100, in: app)
        assertRemaining(75, in: app)

        log(500, in: app)
        assertRemaining(50, in: app)
        log(750, in: app)
        assertRemaining(13, in: app) // 12.5% rounds to 13% for display.
        capture(app, "11-Nearly-empty-after-1750ml")
        log(250, in: app)
        assertRemaining(0, in: app)
        capture(app, "12-Empty-at-2000ml-goal")
        log(250, in: app)
        assertRemaining(0, in: app)
        capture(app, "13-Remains-empty-above-goal")

        launch(app)
        assertRemaining(0, in: app)
        capture(app, "14-Empty-persists-after-relaunch")
        deleteEntry(250, in: app)
        assertRemaining(0, in: app)
        deleteEntry(250, in: app)
        assertRemaining(13, in: app)
        capture(app, "15-Correction-below-goal-restores-water")
    }

    @MainActor
    private func launch(_ app: XCUIApplication, environment: [String: String] = [:]) {
        if app.state != .notRunning { app.terminate() }
        app.launchArguments = ["-hasOnboarded", "YES"]
        app.launchEnvironment = environment
        app.launch()
        XCTAssertTrue(bottle(in: app).waitForExistence(timeout: 30), app.debugDescription)
    }

    @MainActor
    private func bottle(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "homeWaterBottle").firstMatch
    }

    @MainActor
    private func assertRemaining(_ percent: Int, in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let element = bottle(in: app)
        XCTAssertTrue(element.waitForExistence(timeout: 10), file: file, line: line)
        let expected = "\(percent) percent left"
        let correctValue = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expected), object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [correctValue], timeout: 10), .completed,
                       "Expected \(expected), observed \(String(describing: element.value))",
                       file: file, line: line)
        // Home already combines its summary for VoiceOver. Keep that existing
        // grouping while checking the bottle contributes the correct label.
        XCTAssertTrue(element.label.contains("Water remaining"), file: file, line: line)
    }

    @MainActor
    private func log(_ amount: Int, in app: XCUIApplication, rapidTap: Bool = false) {
        let add = app.buttons["Log water intake"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let quickLog = app.buttons["Quick log \(amount) millilitres of Water"]
        XCTAssertTrue(quickLog.waitForExistence(timeout: 10), app.debugDescription)
        if rapidTap {
            quickLog.tap(withNumberOfTaps: 2, numberOfTouches: 1)
        } else {
            quickLog.tap()
        }
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.navigationBars["Log Intake"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
        XCTAssertTrue(bottle(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    private func openEntry(_ amount: Int, in app: XCUIApplication) {
        let diary = app.buttons["Diary"].firstMatch
        XCTAssertTrue(diary.waitForExistence(timeout: 10))
        diary.tap()
        let row = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH[c] %@", "\(amount) ml Water at "
        )).firstMatch
        for _ in 0..<6 {
            if row.exists && row.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.exists && row.isHittable, app.debugDescription)
        row.tap()
        XCTAssertTrue(app.navigationBars["Edit Entry"].waitForExistence(timeout: 10)
                      || app.sliders.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
    }

    @MainActor
    private func editEntry(_ amount: Int, toSliderPosition position: CGFloat,
                           in app: XCUIApplication) {
        openEntry(amount, in: app)
        app.sliders.firstMatch.adjust(toNormalizedSliderPosition: position)
        let save = app.buttons["Save"]
        reveal(save, in: app)
        save.tap()
        goHome(app)
    }

    @MainActor
    private func deleteEntry(_ amount: Int, in app: XCUIApplication) {
        openEntry(amount, in: app)
        let remove = app.buttons["Delete Entry"]
        reveal(remove, in: app)
        remove.tap()
        let confirm = app.buttons["Delete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        goHome(app)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
    }

    @MainActor
    private func goHome(_ app: XCUIApplication) {
        let home = app.buttons["Home"].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"), object: home
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        home.tap()
        XCTAssertTrue(bottle(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        // Let the deliberately damped water settle before the still image;
        // motion dynamics and lifecycle have separate model/controller tests.
        Thread.sleep(forTimeInterval: 2)
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let screenshot = screen.screenshot()
            guard let cgImage = screenshot.image.cgImage else { continue }
            var pixel: [UInt8] = [0, 0, 0, 0]
            let visible = pixel.withUnsafeMutableBytes { bytes in
                guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1,
                                              bitsPerComponent: 8, bytesPerRow: 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return Int(bytes[0]) + Int(bytes[1]) + Int(bytes[2]) > 6
            }
            guard visible else { continue }
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "\(name)-display-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
