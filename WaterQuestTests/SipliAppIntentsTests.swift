import XCTest
@testable import Sipli

/// Tests for the App Intents layer: the pure `HydrationIntentCore` logic that
/// backs `LogWaterIntent` / `GetTodaysHydrationIntent` / `UndoLastIntakeIntent`,
/// the `FluidTypeAppEnum` ↔ `FluidType` bridge, and the `HydrationMerge`
/// entry-merge helper that backs the foreground-reload fix.
final class SipliAppIntentsTests: XCTestCase {

    // MARK: - Fixtures

    /// A profile with a fixed custom goal so `goalML` is deterministic:
    /// `GoalCalculator` returns `max(1200, customGoalML)` when no weather/workout
    /// adjustments apply (weather is nil here).
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

    private func entry(_ ml: Double, _ type: FluidType, at date: Date, id: UUID = UUID()) -> HydrationEntry {
        HydrationEntry(id: id, date: date, volumeML: ml, source: .manual, fluidType: type)
    }

    // MARK: - clampAmount

    func test_clampAmount_belowMinimum_clampsTo50() {
        XCTAssertEqual(HydrationIntentCore.clampAmount(10), 50)
        XCTAssertEqual(HydrationIntentCore.clampAmount(49), 50)
    }

    func test_clampAmount_aboveMaximum_clampsTo2000() {
        XCTAssertEqual(HydrationIntentCore.clampAmount(2001), 2000)
        XCTAssertEqual(HydrationIntentCore.clampAmount(99_999), 2000)
    }

    func test_clampAmount_withinRange_unchanged() {
        XCTAssertEqual(HydrationIntentCore.clampAmount(250), 250)
        XCTAssertEqual(HydrationIntentCore.clampAmount(50), 50)
        XCTAssertEqual(HydrationIntentCore.clampAmount(2000), 2000)
    }

    // MARK: - percent

    func test_percent_partialGoal() {
        XCTAssertEqual(HydrationIntentCore.percent(total: 500, goal: 2000), 25)
    }

    func test_percent_overGoal_exceeds100() {
        XCTAssertEqual(HydrationIntentCore.percent(total: 2500, goal: 2000), 125)
    }

    func test_percent_zeroGoal_isZero_noDivideByZero() {
        XCTAssertEqual(HydrationIntentCore.percent(total: 100, goal: 0), 0)
    }

    // MARK: - goalML

    func test_goalML_usesCustomGoal_whenNoWeather() {
        let state = makeState(goalML: 1800)
        XCTAssertEqual(HydrationIntentCore.goalML(for: state), 1800)
    }

    func test_goalML_flooredAt1200() {
        let state = makeState(goalML: 500)
        XCTAssertEqual(HydrationIntentCore.goalML(for: state), 1200)
    }

    // MARK: - logWater

    func test_logWater_appendsEntryWithClampedVolumeAndFluid() {
        var state = makeState()
        let now = Date()
        let result = HydrationIntentCore.logWater(
            into: &state, amountInMilliliters: 3000, fluidType: .coffee, now: now
        )

        XCTAssertEqual(state.entries.count, 1)
        XCTAssertEqual(state.entries[0].volumeML, 2000) // clamped
        XCTAssertEqual(state.entries[0].fluidType, .coffee)
        XCTAssertEqual(state.entries[0].source, .manual)
        XCTAssertEqual(result.entry.volumeML, 2000)
    }

    func test_logWater_defaultsToWater() {
        var state = makeState()
        let result = HydrationIntentCore.logWater(
            into: &state, amountInMilliliters: 250, fluidType: .water, now: Date()
        )
        XCTAssertEqual(result.entry.fluidType, .water)
        XCTAssertEqual(result.entry.volumeML, 250)
    }

    func test_logWater_dialogReportsPercentUsingEffectiveML() {
        var state = makeState(goalML: 2000)
        // Coffee 500 mL → effectiveML = 500 * 0.80 = 400 → 20% of 2000.
        let result = HydrationIntentCore.logWater(
            into: &state, amountInMilliliters: 500, fluidType: .coffee, now: Date()
        )
        XCTAssertTrue(result.dialog.contains("20%"), "dialog was: \(result.dialog)")
        XCTAssertTrue(result.dialog.contains("500 mL"), "dialog was: \(result.dialog)")
    }

    func test_logWater_accumulatesAcrossTodayEntries() {
        let now = Date()
        var state = makeState(goalML: 2000, entries: [entry(1000, .water, at: now)])
        // Add 1000 water → today effective total 2000 → 100%.
        let result = HydrationIntentCore.logWater(
            into: &state, amountInMilliliters: 1000, fluidType: .water, now: now
        )
        XCTAssertEqual(state.entries.count, 2)
        XCTAssertTrue(result.dialog.contains("100%"), "dialog was: \(result.dialog)")
    }

    // MARK: - todaysHydrationDialog

    func test_todaysHydration_emptyState_zeroPercent() {
        let state = makeState()
        let dialog = HydrationIntentCore.todaysHydrationDialog(state: state, now: Date())
        XCTAssertTrue(dialog.contains("0%"), "dialog was: \(dialog)")
    }

    func test_todaysHydration_ignoresOtherDays() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let state = makeState(goalML: 2000, entries: [
            entry(2000, .water, at: yesterday),
            entry(500, .water, at: now),
        ])
        let dialog = HydrationIntentCore.todaysHydrationDialog(state: state, now: now)
        XCTAssertTrue(dialog.contains("25%"), "dialog was: \(dialog)") // only today's 500/2000
    }

    // MARK: - undoLastToday

    func test_undoLastToday_removesMostRecentTodayEntry() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)
        var state = makeState(goalML: 2000, entries: [
            entry(250, .water, at: earlier),
            entry(500, .coffee, at: now),
        ])
        let result = HydrationIntentCore.undoLastToday(from: &state, now: now)

        XCTAssertEqual(result.removed?.fluidType, .coffee)
        XCTAssertEqual(result.removed?.volumeML, 500)
        XCTAssertEqual(state.entries.count, 1)
        XCTAssertEqual(state.entries.first?.fluidType, .water)
    }

    func test_undoLastToday_nothingToday_returnsNil() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        var state = makeState(entries: [entry(250, .water, at: yesterday)])
        let result = HydrationIntentCore.undoLastToday(from: &state, now: now)

        XCTAssertNil(result.removed)
        XCTAssertEqual(state.entries.count, 1) // untouched
    }

    // MARK: - Compact dialogs (iOS 27 visual surfaces)

    func test_logWater_compactDialog_containsAmountAndPercent_andIsShorter() {
        var state = makeState(goalML: 2000)
        let result = HydrationIntentCore.logWater(
            into: &state, amountInMilliliters: 500, fluidType: .water, now: Date()
        )
        XCTAssertTrue(result.compactDialog.contains("500 mL"), "compact was: \(result.compactDialog)")
        XCTAssertTrue(result.compactDialog.contains("25%"), "compact was: \(result.compactDialog)")
        XCTAssertLessThan(result.compactDialog.count, result.dialog.count)
    }

    func test_todaysHydrationCompact_showsTotalGoalAndPercent() {
        let now = Date()
        let state = makeState(goalML: 2000, entries: [entry(500, .water, at: now)])
        let compact = HydrationIntentCore.todaysHydrationCompact(state: state, now: now)
        XCTAssertTrue(compact.contains("500"), "compact was: \(compact)")
        XCTAssertTrue(compact.contains("2000"), "compact was: \(compact)")
        XCTAssertTrue(compact.contains("25%"), "compact was: \(compact)")
    }

    func test_undoLastToday_compactDialog_reportsRemovedVolume() {
        let now = Date()
        var state = makeState(goalML: 2000, entries: [entry(500, .coffee, at: now)])
        let result = HydrationIntentCore.undoLastToday(from: &state, now: now)
        XCTAssertTrue(result.compactDialog.contains("500 mL"), "compact was: \(result.compactDialog)")
        XCTAssertTrue(result.compactDialog.contains("0%"), "compact was: \(result.compactDialog)")
    }

    func test_undoLastToday_emptyDay_compactMatchesDialog() {
        var state = makeState()
        let result = HydrationIntentCore.undoLastToday(from: &state, now: Date())
        XCTAssertNil(result.removed)
        XCTAssertEqual(result.dialog, result.compactDialog)
    }

    // MARK: - FluidTypeAppEnum bridge

    func test_everyFluidType_hasMatchingAppEnumCase() {
        for fluid in FluidType.allCases {
            XCTAssertNotNil(
                FluidTypeAppEnum(rawValue: fluid.rawValue),
                "FluidType.\(fluid.rawValue) has no FluidTypeAppEnum case"
            )
        }
    }

    func test_appEnum_caseCount_matchesFluidType() {
        XCTAssertEqual(FluidTypeAppEnum.allCases.count, FluidType.allCases.count)
    }

    func test_appEnum_roundTripsThroughFluidType() {
        for appCase in FluidTypeAppEnum.allCases {
            XCTAssertEqual(FluidTypeAppEnum.from(appCase.toFluidType()), appCase)
        }
    }

    func test_appEnum_hasDisplayRepresentationForEveryCase() {
        for appCase in FluidTypeAppEnum.allCases {
            XCTAssertNotNil(
                FluidTypeAppEnum.caseDisplayRepresentations[appCase],
                "Missing caseDisplayRepresentation for \(appCase.rawValue)"
            )
        }
    }

    // MARK: - HydrationMerge.mergeByID

    func test_mergeByID_unionsDisjointEntries_sortedByDate() {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let local = [entry(100, .water, at: t2)]
        let incoming = [entry(200, .water, at: t1)]

        let merged = HydrationMerge.mergeByID(local: local, incoming: incoming)

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.map(\.date), [t1, t2]) // sorted ascending
    }

    func test_mergeByID_incomingWinsOnSharedID() {
        let id = UUID()
        let t1 = Date(timeIntervalSince1970: 1_000)
        let local = [entry(100, .water, at: t1, id: id)]
        let incoming = [entry(999, .coffee, at: t1, id: id)]

        let merged = HydrationMerge.mergeByID(local: local, incoming: incoming)

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.volumeML, 999) // incoming wins
        XCTAssertEqual(merged.first?.fluidType, .coffee)
    }

    func test_mergeByID_preservesLocalOnlyEntries() {
        let t1 = Date(timeIntervalSince1970: 1_000)
        let t2 = Date(timeIntervalSince1970: 2_000)
        let t3 = Date(timeIntervalSince1970: 3_000)
        let shared = UUID()
        let local = [
            entry(100, .water, at: t1, id: shared),
            entry(200, .juice, at: t3), // local-only, must survive
        ]
        let incoming = [
            entry(999, .water, at: t1, id: shared),
            entry(300, .milk, at: t2), // incoming-only
        ]

        let merged = HydrationMerge.mergeByID(local: local, incoming: incoming)

        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged.map(\.date), [t1, t2, t3])
        XCTAssertTrue(merged.contains { $0.fluidType == .juice })
    }
}
