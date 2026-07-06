import XCTest
@testable import Sipli

/// Tests for the v5.0 additions to `HydrationIntentCore`: streak dialog,
/// remaining-to-goal dialog, repeat-last-drink, and the engagement counters
/// that feed the secret achievements.
final class SipliV5IntentsTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date {
        calendar.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
            .addingTimeInterval(10 * 3600)
    }

    private func fixedGoalProfile(_ goalML: Double = 2000) -> UserProfile {
        var p = UserProfile.default
        p.customGoalML = goalML
        return p
    }

    private func makeState(goalML: Double = 2000, entries: [HydrationEntry] = []) -> PersistedState {
        var state = PersistedState.default
        state.profile = fixedGoalProfile(goalML)
        state.entries = entries
        return state
    }

    private func entry(_ ml: Double, dayOffset: Int, _ type: FluidType = .water) -> HydrationEntry {
        HydrationEntry(date: day(dayOffset), volumeML: ml, source: .manual, fluidType: type)
    }

    // MARK: - Streak dialog

    func test_streakDialog_zero() {
        let result = HydrationIntentCore.streakDialog(state: makeState(), now: now)
        XCTAssertTrue(result.dialog.contains("No active streak"))
    }

    func test_streakDialog_pluralDays() {
        let state = makeState(entries: [entry(2000, dayOffset: 0), entry(2000, dayOffset: 1), entry(2000, dayOffset: 2)])
        let result = HydrationIntentCore.streakDialog(state: state, now: now)
        XCTAssertTrue(result.dialog.contains("3 days"), result.dialog)
        XCTAssertEqual(result.compactDialog, "3-day streak")
    }

    // MARK: - Remaining dialog

    func test_remainingDialog_partway() {
        let state = makeState(entries: [entry(800, dayOffset: 0)])
        let result = HydrationIntentCore.remainingDialog(state: state, now: now)
        XCTAssertTrue(result.dialog.contains("1200 mL"), result.dialog)
        XCTAssertTrue(result.compactDialog.contains("1200 mL"), result.compactDialog)
    }

    func test_remainingDialog_goalReached() {
        let state = makeState(entries: [entry(2200, dayOffset: 0)])
        let result = HydrationIntentCore.remainingDialog(state: state, now: now)
        XCTAssertTrue(result.dialog.contains("already reached"), result.dialog)
    }

    // MARK: - Repeat last drink

    func test_repeatLast_duplicatesMostRecentEntry() {
        var state = makeState(entries: [
            entry(300, dayOffset: 1, .coffee),
            entry(450, dayOffset: 0, .greenTea), // most recent
        ])
        let result = HydrationIntentCore.repeatLastDrink(into: &state, now: now)
        XCTAssertEqual(result.entry.volumeML, 450)
        XCTAssertEqual(result.entry.fluidType, .greenTea)
        XCTAssertEqual(state.entries.count, 3)
    }

    func test_repeatLast_noHistory_fallsBackTo250Water() {
        var state = makeState()
        let result = HydrationIntentCore.repeatLastDrink(into: &state, now: now)
        XCTAssertEqual(result.entry.volumeML, 250)
        XCTAssertEqual(result.entry.fluidType, .water)
    }

    // MARK: - Engagement counters

    func test_logWater_incrementsSiriCounter() {
        var state = makeState()
        XCTAssertEqual(state.counters.siriLogCount, 0)
        HydrationIntentCore.logWater(into: &state, amountInMilliliters: 250, fluidType: .water, now: now)
        XCTAssertEqual(state.counters.siriLogCount, 1)
    }

    func test_undo_incrementsUndoCounter_onlyWhenSomethingRemoved() {
        var state = makeState(entries: [entry(250, dayOffset: 0)])
        HydrationIntentCore.undoLastToday(from: &state, now: now)
        XCTAssertEqual(state.counters.undoCount, 1)

        // Nothing left today — undo again must not count.
        HydrationIntentCore.undoLastToday(from: &state, now: now)
        XCTAssertEqual(state.counters.undoCount, 1)
    }

    func test_countersMerge_takesPerFieldMaximum() {
        let a = EngagementCounters(siriLogCount: 3, widgetLogCount: 0, undoCount: 5)
        let b = EngagementCounters(siriLogCount: 1, widgetLogCount: 4, undoCount: 2)
        let merged = a.merged(with: b)
        XCTAssertEqual(merged.siriLogCount, 3)
        XCTAssertEqual(merged.widgetLogCount, 4)
        XCTAssertEqual(merged.undoCount, 5)
    }
}
