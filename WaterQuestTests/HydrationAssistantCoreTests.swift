import XCTest
@testable import Sipli

/// Tests for `HydrationAssistantCore`, the pure logic behind the iOS 27.3
/// Siri AI tools: logging several drinks in one request, finding past
/// drinks, editing or deleting one, setting the daily goal, and the
/// snapshot that backs `DrinkEntryEntity`.
final class HydrationAssistantCoreTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date {
        calendar.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
    }

    private func hoursAgo(_ hours: Double) -> Date {
        now.addingTimeInterval(-hours * 3600)
    }

    private func daysAgo(_ days: Int, hour: Int = 10) -> Date {
        let day = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func makeState(goalML: Double = 2000, unit: UnitSystem = .metric, entries: [HydrationEntry] = []) -> PersistedState {
        var state = PersistedState.default
        var profile = UserProfile.default
        profile.customGoalML = goalML
        profile.unitSystem = unit
        state.profile = profile
        state.entries = entries
        return state
    }

    private func entry(_ ml: Double, at date: Date, _ type: FluidType = .water, source: HydrationSource = .manual) -> HydrationEntry {
        HydrationEntry(date: date, volumeML: ml, source: source, fluidType: type)
    }

    // MARK: - logDrinks

    func test_logDrinks_appendsOneEntryPerRequest() throws {
        var state = makeState()
        let outcome = try HydrationAssistantCore.logDrinks(
            [
                .init(fluid: .coffee, amountML: 240),
                .init(fluid: .coffee, amountML: 240),
                .init(fluid: .water, amountML: 250),
            ],
            into: &state,
            now: now
        )
        XCTAssertEqual(outcome.entries.count, 3)
        XCTAssertEqual(state.entries.count, 3)
        XCTAssertEqual(state.entries.map(\.fluidType), [.coffee, .coffee, .water])
        XCTAssertEqual(state.counters.siriLogCount, 3, "each drink feeds the Voice Activated badge")
    }

    func test_logDrinks_dialogGroupsRepeatedDrinks() throws {
        var state = makeState()
        let outcome = try HydrationAssistantCore.logDrinks(
            [
                .init(fluid: .coffee, amountML: 240),
                .init(fluid: .coffee, amountML: 240),
                .init(fluid: .water, amountML: 250),
            ],
            into: &state,
            now: now
        )
        XCTAssertTrue(outcome.dialog.hasPrefix("Logged 2 coffees (480 mL) and 250 mL of water."), outcome.dialog)
        XCTAssertEqual(outcome.compactDialog, "3 drinks logged — 31% of goal")
    }

    func test_logDrinks_missingAmountUsesUsualSize() throws {
        var state = makeState(entries: [entry(400, at: daysAgo(2), .latte)])
        let outcome = try HydrationAssistantCore.logDrinks(
            [.init(fluid: .latte), .init(fluid: .espresso)],
            into: &state,
            now: now
        )
        XCTAssertEqual(outcome.entries[0].volumeML, 400, "last latte size")
        XCTAssertEqual(outcome.entries[1].volumeML, FluidType.espresso.defaultServingML, "typical serving when never logged")
    }

    func test_logDrinks_usualSizeIsReadBeforeTheBatchIsAppended() throws {
        var state = makeState(entries: [entry(300, at: daysAgo(1), .tea)])
        let outcome = try HydrationAssistantCore.logDrinks(
            [.init(fluid: .tea, amountML: 500), .init(fluid: .tea)],
            into: &state,
            now: now
        )
        XCTAssertEqual(outcome.entries[1].volumeML, 300, "an earlier drink in the same request must not change the usual size")
    }

    func test_logDrinks_backdatesToRequestedTime() throws {
        var state = makeState()
        let morning = hoursAgo(6)
        let outcome = try HydrationAssistantCore.logDrinks([.init(fluid: .coffee, amountML: 240, loggedAt: morning)], into: &state, now: now)
        XCTAssertEqual(outcome.entries[0].date, morning)
    }

    func test_logDrinks_futureTimeIsClampedToNow() throws {
        var state = makeState()
        let outcome = try HydrationAssistantCore.logDrinks(
            [.init(fluid: .water, amountML: 250, loggedAt: now.addingTimeInterval(3600))],
            into: &state,
            now: now
        )
        XCTAssertEqual(outcome.entries[0].date, now)
    }

    func test_logDrinks_rejectsTimesMoreThanAWeekAgo() {
        var state = makeState()
        XCTAssertThrowsError(
            try HydrationAssistantCore.logDrinks([.init(fluid: .water, amountML: 250, loggedAt: daysAgo(8))], into: &state, now: now)
        ) { error in
            XCTAssertEqual(error as? HydrationAssistantCore.Failure, .tooFarInPast)
        }
        XCTAssertTrue(state.entries.isEmpty, "a rejected request logs nothing")
    }

    func test_logDrinks_rejectsEmptyAndOversizedRequests() {
        var state = makeState()
        XCTAssertThrowsError(try HydrationAssistantCore.logDrinks([], into: &state, now: now)) {
            XCTAssertEqual($0 as? HydrationAssistantCore.Failure, .nothingToLog)
        }
        let tooMany = Array(repeating: HydrationAssistantCore.DrinkRequest(fluid: .water, amountML: 100),
                            count: HydrationAssistantCore.maxDrinksPerRequest + 1)
        XCTAssertThrowsError(try HydrationAssistantCore.logDrinks(tooMany, into: &state, now: now)) {
            XCTAssertEqual($0 as? HydrationAssistantCore.Failure, .tooManyDrinks)
        }
        XCTAssertTrue(state.entries.isEmpty)
    }

    func test_logDrinks_clampsAmounts() throws {
        var state = makeState()
        let outcome = try HydrationAssistantCore.logDrinks(
            [.init(fluid: .espresso, amountML: 2), .init(fluid: .water, amountML: 9000)],
            into: &state,
            now: now
        )
        XCTAssertEqual(outcome.entries.map(\.volumeML), [10, 2000])
    }

    // MARK: - entries(in:from:through:)

    func test_entries_returnsWholeDaysInRangeOldestFirst() {
        let state = makeState(entries: [
            entry(250, at: daysAgo(0, hour: 9)),
            entry(300, at: daysAgo(1, hour: 20), .tea),
            entry(200, at: daysAgo(1, hour: 7), .coffee),
            entry(500, at: daysAgo(2)),
        ])
        let yesterday = daysAgo(1, hour: 12)
        let found = HydrationAssistantCore.entries(in: state, from: yesterday, through: yesterday)
        XCTAssertEqual(found.map(\.volumeML), [200, 300])
    }

    func test_entries_filtersByDrinkAndToleratesReversedRange() {
        let state = makeState(entries: [
            entry(200, at: daysAgo(0), .coffee),
            entry(250, at: daysAgo(1)),
            entry(220, at: daysAgo(3), .coffee),
        ])
        let found = HydrationAssistantCore.entries(in: state, from: now, through: daysAgo(6), fluid: .coffee)
        XCTAssertEqual(found.map(\.volumeML), [220, 200])
    }

    // MARK: - historySummary

    func test_historySummary_yesterday() {
        let entries = [entry(200, at: daysAgo(1), .coffee), entry(300, at: daysAgo(1))]
        let state = makeState(entries: entries)
        let summary = HydrationAssistantCore.historySummary(
            entries, from: daysAgo(1), through: daysAgo(1), fluid: nil, state: state, now: now
        )
        XCTAssertTrue(summary.dialog.hasPrefix("You logged 2 drinks yesterday, 500 mL in total"), summary.dialog)
        XCTAssertEqual(summary.compactDialog, "2 drinks · 500 mL")
    }

    func test_historySummary_singleDrinkToday() {
        let entries = [entry(240, at: daysAgo(0), .coffee)]
        let summary = HydrationAssistantCore.historySummary(
            entries, from: now, through: now, fluid: .coffee, state: makeState(entries: entries), now: now
        )
        XCTAssertTrue(summary.dialog.hasPrefix("You logged 1 coffee today, 240 mL in total"), summary.dialog)
    }

    func test_historySummary_nothingLogged() {
        let summary = HydrationAssistantCore.historySummary(
            [], from: daysAgo(1), through: daysAgo(1), fluid: .juice, state: makeState(), now: now
        )
        XCTAssertEqual(summary.dialog, "You didn't log any juice yesterday.")
    }

    // MARK: - updateEntry

    func test_updateEntry_changesAmountAndDrink() throws {
        let latte = entry(300, at: hoursAgo(2), .latte)
        var state = makeState(entries: [latte])
        let result = try HydrationAssistantCore.updateEntry(id: latte.id, amountML: 400, fluid: .flatWhite, in: &state, now: now)
        XCTAssertEqual(state.entries[0].volumeML, 400)
        XCTAssertEqual(state.entries[0].fluidType, .flatWhite)
        XCTAssertEqual(result.entry.id, latte.id)
        XCTAssertTrue(result.dialog.hasPrefix("Updated that drink to 400 mL of flat white."), result.dialog)
    }

    func test_updateEntry_requiresAChangeAndAnExistingEntry() {
        let tea = entry(300, at: hoursAgo(1), .tea)
        var state = makeState(entries: [tea])
        XCTAssertThrowsError(try HydrationAssistantCore.updateEntry(id: tea.id, amountML: nil, fluid: nil, in: &state, now: now)) {
            XCTAssertEqual($0 as? HydrationAssistantCore.Failure, .nothingToChange)
        }
        XCTAssertThrowsError(try HydrationAssistantCore.updateEntry(id: UUID(), amountML: 100, fluid: nil, in: &state, now: now)) {
            XCTAssertEqual($0 as? HydrationAssistantCore.Failure, .entryNotFound)
        }
    }

    // MARK: - deleteEntry

    func test_deleteEntry_removesRecordsRemovalAndCountsUndo() throws {
        let coffee = entry(240, at: hoursAgo(1), .coffee)
        let water = entry(500, at: hoursAgo(2))
        var state = makeState(entries: [coffee, water])
        let result = try HydrationAssistantCore.deleteEntry(id: coffee.id, from: &state, now: now)
        XCTAssertEqual(state.entries.map(\.id), [water.id])
        XCTAssertNotNil(state.removedEntryIDs[coffee.id], "removal must stick across process merges")
        XCTAssertEqual(state.counters.undoCount, 1)
        XCTAssertEqual(result.removed.id, coffee.id)
        XCTAssertEqual(result.dialog, "Deleted 240 mL of coffee. You're now at 25% of today's goal.")
    }

    func test_deleteEntry_unknownID() {
        var state = makeState()
        XCTAssertThrowsError(try HydrationAssistantCore.deleteEntry(id: UUID(), from: &state, now: now)) {
            XCTAssertEqual($0 as? HydrationAssistantCore.Failure, .entryNotFound)
        }
    }

    // MARK: - setDailyGoal

    func test_setDailyGoal_setsCustomGoal() {
        var state = makeState()
        let result = HydrationAssistantCore.setDailyGoal(ml: 2500, in: &state)
        XCTAssertEqual(state.profile.customGoalML, 2500)
        XCTAssertEqual(result.dialog, "Your daily goal is now 2500 mL.")
    }

    func test_setDailyGoal_clampsToTheAppsRange() {
        var state = makeState()
        let result = HydrationAssistantCore.setDailyGoal(ml: 9000, in: &state)
        XCTAssertEqual(state.profile.customGoalML, 4500)
        XCTAssertEqual(result.dialog, "Your daily goal is now 4500 mL, the highest Sipli allows.")

        _ = HydrationAssistantCore.setDailyGoal(ml: 100, in: &state)
        XCTAssertEqual(state.profile.customGoalML, 1500)
    }

    func test_setDailyGoal_nilReturnsToAutomatic() {
        var state = makeState(goalML: 3000)
        let result = HydrationAssistantCore.setDailyGoal(ml: nil, in: &state)
        XCTAssertNil(state.profile.customGoalML)
        XCTAssertTrue(result.dialog.hasPrefix("Your goal is back to automatic"), result.dialog)
    }

    func test_setDailyGoal_imperialRangeMatchesSettingsSlider() {
        var state = makeState(unit: .imperial)
        _ = HydrationAssistantCore.setDailyGoal(ml: 100, in: &state)
        XCTAssertEqual(state.profile.customGoalML ?? 0, UnitSystem.imperial.ml(from: 50), accuracy: 0.5)
    }

    // MARK: - Entity snapshot

    func test_snapshot_describesEntryInUsersUnits() {
        let latte = HydrationEntry(date: now, volumeML: 350, source: .manual, fluidType: .latte, note: "with lunch")
        let snap = HydrationAssistantCore.snapshot(of: latte, unit: .metric)
        XCTAssertEqual(snap.id, latte.id)
        XCTAssertEqual(snap.title, "Latte")
        XCTAssertEqual(snap.amountText, "350 mL")
        XCTAssertEqual(snap.amountML, 350)
        XCTAssertEqual(snap.hydrationML, Int((350 * FluidType.latte.hydrationFactor).rounded()))
        XCTAssertEqual(snap.note, "with lunch")
    }

    func test_shareText_listsEachDrinkAndTotal() {
        let entries = [entry(240, at: hoursAgo(3), .coffee), entry(500, at: hoursAgo(1))]
        let text = HydrationAssistantCore.shareText(for: entries, unit: .metric)
        XCTAssertTrue(text.contains("240 mL coffee"), text)
        XCTAssertTrue(text.contains("500 mL water"), text)
        XCTAssertTrue(text.contains("Total: 740 mL"), text)
    }

    // MARK: - Spotlight window

    func test_indexableEntries_coversLast30DaysOnly() {
        let state = makeState(entries: [entry(250, at: daysAgo(0)), entry(250, at: daysAgo(29)), entry(250, at: daysAgo(31))])
        XCTAssertEqual(HydrationAssistantCore.indexableEntries(in: state, now: now).count, 2)
    }
}
