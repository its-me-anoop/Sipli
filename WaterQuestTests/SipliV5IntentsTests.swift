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

/// Siri polish: named-drink logging, the user's units, the progress card,
/// and removals that survive a stale in-memory merge.
final class SipliSiriPolishTests: XCTestCase {

    private func state(goalML: Double = 2000, unit: UnitSystem = .metric, entries: [HydrationEntry] = []) -> PersistedState {
        var state = PersistedState.default
        state.profile.customGoalML = goalML
        state.profile.unitSystem = unit
        state.entries = entries
        return state
    }

    private func entry(_ ml: Double, _ type: FluidType = .water, hoursAgo: Double = 1) -> HydrationEntry {
        HydrationEntry(date: Date().addingTimeInterval(-hoursAgo * 3600), volumeML: ml, source: .manual, fluidType: type)
    }

    // MARK: - Log a drink

    func test_logDrink_usesUsersLastAmountForThatDrink() {
        var s = state(entries: [entry(400, .latte, hoursAgo: 30), entry(250, .water)])
        let result = HydrationIntentCore.logDrink(into: &s, fluidType: .latte, now: Date())
        XCTAssertEqual(result.entry.volumeML, 400)
        XCTAssertEqual(result.entry.fluidType, .latte)
        XCTAssertTrue(result.dialog.contains("400 mL of latte"), result.dialog)
    }

    func test_logDrink_fallsBackToTypicalServing() {
        var s = state()
        let result = HydrationIntentCore.logDrink(into: &s, fluidType: .espresso, now: Date())
        XCTAssertEqual(result.entry.volumeML, FluidType.espresso.defaultServingML)
    }

    func test_logDrink_ignoresHealthKitImportsWhenPickingSize() {
        let imported = HydrationEntry(date: Date(), volumeML: 1000, source: .healthKit, fluidType: .water)
        let s = state(entries: [entry(300, .water, hoursAgo: 5), imported])
        XCTAssertEqual(HydrationIntentCore.usualAmountML(for: .water, in: s), 300)
    }

    func test_logDrink_countsAsSiriLog() {
        var s = state()
        HydrationIntentCore.logDrink(into: &s, fluidType: .tea, now: Date())
        XCTAssertEqual(s.counters.siriLogCount, 1)
    }

    // MARK: - Spoken follow-up

    func test_logWater_saysHowMuchIsLeft() {
        var s = state()
        let result = HydrationIntentCore.logWater(into: &s, amountInMilliliters: 500, fluidType: .water, now: Date())
        XCTAssertTrue(result.dialog.contains("1500 mL to go"), result.dialog)
    }

    func test_logWater_saysGoalDoneWhenReached() {
        var s = state(entries: [entry(1800)])
        let result = HydrationIntentCore.logWater(into: &s, amountInMilliliters: 500, fluidType: .water, now: Date())
        XCTAssertTrue(result.dialog.contains("goal is done"), result.dialog)
    }

    // MARK: - Units

    func test_imperialUser_hearsOunces() {
        var s = state(unit: .imperial)
        let result = HydrationIntentCore.logWater(into: &s, amountInMilliliters: 500, fluidType: .water, now: Date())
        XCTAssertTrue(result.dialog.contains("17 oz"), result.dialog)
        XCTAssertFalse(result.dialog.contains("mL"), result.dialog)
        XCTAssertFalse(HydrationIntentCore.remainingDialog(state: s, now: Date()).dialog.contains("mL"))
        XCTAssertFalse(HydrationIntentCore.todaysHydrationDialog(state: s, now: Date()).contains("mL"))
        XCTAssertTrue(HydrationIntentCore.todaysHydrationCompact(state: s, now: Date()).contains("oz"))
    }

    func test_volumeFormatting() {
        XCTAssertEqual(HydrationIntentCore.volume(250, unit: .metric), "250 mL")
        XCTAssertEqual(HydrationIntentCore.volume(30, unit: .imperial), "1 oz")
        XCTAssertEqual(HydrationIntentCore.volume(180, unit: .imperial), "6.1 oz")
        XCTAssertEqual(HydrationIntentCore.volume(2000, unit: .imperial), "68 oz")
    }

    // MARK: - Progress card

    func test_progressSnapshot() {
        let p = HydrationIntentCore.progress(state: state(entries: [entry(500)]), now: Date())
        XCTAssertEqual(p.totalML, 500)
        XCTAssertEqual(p.goalML, 2000)
        XCTAssertEqual(p.percent, 25)
        XCTAssertEqual(p.fraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(p.remainingML, 1500)
    }

    func test_progressSnapshot_capsFractionAndRemaining() {
        let p = HydrationIntentCore.progress(state: state(entries: [entry(2500)]), now: Date())
        XCTAssertEqual(p.fraction, 1)
        XCTAssertEqual(p.remainingML, 0)
        XCTAssertEqual(p.percent, 125)
    }

    // MARK: - Removals stick

    /// The bug: Siri undo removed the drink on disk, then the app's stale
    /// in-memory copy merged it straight back on the next foreground.
    func test_siriUndo_isNotResurrectedByStaleAppCopy() {
        let drink = entry(300)
        var disk = state(entries: [entry(200, hoursAgo: 2), drink])
        let staleAppEntries = disk.entries

        let result = HydrationIntentCore.undoLastToday(from: &disk, now: Date())
        XCTAssertEqual(result.removed?.id, drink.id)
        XCTAssertNotNil(disk.removedEntryIDs[drink.id])

        let merged = HydrationMerge.mergeByID(
            local: staleAppEntries,
            incoming: disk.entries,
            removed: Set(disk.removedEntryIDs.keys)
        )
        XCTAssertFalse(merged.contains { $0.id == drink.id })
        XCTAssertEqual(merged.count, 1)
    }

    func test_mergeWithoutRemovals_keepsLocalOnlyEntries() {
        let localOnly = entry(300)
        let merged = HydrationMerge.mergeByID(local: [localOnly], incoming: [])
        XCTAssertEqual(merged.map(\.id), [localOnly.id])
    }

    func test_removals_roundTripAndDecodeFromOlderFiles() throws {
        var s = state()
        let id = UUID()
        s.recordRemoval(of: [id], at: Date())
        let decoded = try JSONDecoder().decode(PersistedState.self, from: JSONEncoder().encode(s))
        XCTAssertNotNil(decoded.removedEntryIDs[id])

        // A file written before this field existed still decodes.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state())) as? [String: Any])
        json.removeValue(forKey: "removedEntryIDs")
        let legacy = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(legacy.removedEntryIDs.isEmpty)
    }

    func test_removals_mergeKeepsLaterDateAndPrunesOld() {
        let shared = UUID(), old = UUID()
        let now = Date()
        let a: [UUID: Date] = [shared: now.addingTimeInterval(-60), old: now.addingTimeInterval(-40 * 86_400)]
        let b: [UUID: Date] = [shared: now]
        let merged = PersistedState.mergedRemovals(a, b, now: now)
        XCTAssertEqual(merged[shared], now)
        XCTAssertNil(merged[old])
    }
}

/// "Log 350 ml of latte": parsing, ids, speech synonyms, Siri suggestions.
final class DrinkAmountTests: XCTestCase {

    private func parse(_ text: String, _ unit: UnitSystem = .metric) -> DrinkAmount? {
        DrinkAmount.parse(text, defaultUnit: unit)
    }

    func test_parse_amountAndDrink() {
        XCTAssertEqual(parse("350 ml of latte"), DrinkAmount(quantity: 350, unit: .ml, fluid: .latte))
        XCTAssertEqual(parse("350ml latte"), DrinkAmount(quantity: 350, unit: .ml, fluid: .latte))
        XCTAssertEqual(parse("Log 350 milliliters of Latte"), DrinkAmount(quantity: 350, unit: .ml, fluid: .latte))
        XCTAssertEqual(parse("12 oz of coffee"), DrinkAmount(quantity: 12, unit: .oz, fluid: .coffee))
        XCTAssertEqual(parse("16 fluid ounces of iced coffee"), DrinkAmount(quantity: 16, unit: .oz, fluid: .icedCoffee))
    }

    func test_parse_prefersLongestDrinkName() {
        XCTAssertEqual(parse("250 ml green tea")?.fluid, .greenTea)
        XCTAssertEqual(parse("250 ml tea")?.fluid, .tea)
        XCTAssertEqual(parse("330 ml sparkling water")?.fluid, .sparklingWater)
    }

    func test_parse_waterAndNoDrinkMeanWater() {
        XCTAssertNil(parse("500 ml")?.fluid)
        XCTAssertNil(parse("500 ml of water")?.fluid)
    }

    func test_parse_litresCentilitresCups() {
        XCTAssertEqual(parse("half a litre")?.milliliters, 500)
        XCTAssertEqual(parse("1.5 liters")?.milliliters, 1500)
        XCTAssertEqual(parse("1,5 l")?.milliliters, 1500)
        XCTAssertEqual(parse("a litre of water")?.milliliters, 1000)
        XCTAssertEqual(parse("33cl coke"), DrinkAmount(quantity: 330, unit: .ml, fluid: .soda))
        XCTAssertEqual(parse("2 cups of tea"), DrinkAmount(quantity: 16, unit: .oz, fluid: .tea))
    }

    func test_parse_bareNumberUsesUsersUnit() {
        XCTAssertEqual(parse("350"), DrinkAmount(quantity: 350, unit: .ml))
        XCTAssertEqual(parse("12", .imperial), DrinkAmount(quantity: 12, unit: .oz))
    }

    func test_parse_doesNotMistakeDrinkNameForLitres() {
        // "350 latte" must not read as 350 litres.
        XCTAssertEqual(parse("350 latte"), DrinkAmount(quantity: 350, unit: .ml, fluid: .latte))
    }

    func test_parse_rejectsNoAmount() {
        XCTAssertNil(parse("latte"))
        XCTAssertNil(parse(""))
        XCTAssertNil(parse("0 ml"))
    }

    func test_idRoundTrip() {
        for amount in [DrinkAmount(quantity: 350, unit: .ml, fluid: .latte),
                       DrinkAmount(quantity: 12, unit: .oz),
                       DrinkAmount(quantity: 1.5, unit: .oz, fluid: .espresso)] {
            XCTAssertEqual(DrinkAmount(id: amount.id), amount)
        }
        XCTAssertNil(DrinkAmount(id: "ml:350:notadrink"))
        XCTAssertNil(DrinkAmount(id: "garbage"))
    }

    func test_waterIsStoredAsPlainAmount() {
        XCTAssertEqual(DrinkAmount(quantity: 500, unit: .ml, fluid: .water).id, "ml:500:")
    }

    func test_titlesAndSynonyms() {
        let latte = DrinkAmount(quantity: 350, unit: .ml, fluid: .latte)
        XCTAssertEqual(latte.title, "350 ml of latte")
        XCTAssertTrue(latte.synonyms.contains("350 milliliters of latte"))
        XCTAssertTrue(latte.synonyms.contains("350 ml latte"))
        let water = DrinkAmount(quantity: 500, unit: .ml)
        XCTAssertEqual(water.title, "500 ml")
        XCTAssertTrue(water.synonyms.contains("500 ml of water"))
        XCTAssertTrue(water.synonyms.contains("half a litre"))
        XCTAssertTrue(DrinkAmount(quantity: 12, unit: .oz).synonyms.contains("12 ounces"))
    }

    func test_ouncesConvertToMillilitres() {
        XCTAssertEqual(DrinkAmount(quantity: 12, unit: .oz).milliliters, 354.88, accuracy: 0.1)
    }

    // MARK: Suggestions

    private func state(_ unit: UnitSystem = .metric, entries: [HydrationEntry] = []) -> PersistedState {
        var s = PersistedState.default
        s.profile.unitSystem = unit
        s.entries = entries
        return s
    }

    private func drink(_ type: FluidType, _ ml: Double, daysAgo: Double = 1) -> HydrationEntry {
        HydrationEntry(date: Date().addingTimeInterval(-daysAgo * 86_400), volumeML: ml, source: .manual, fluidType: type)
    }

    func test_suggestions_coverCommonMetricSizes() {
        let ids = Set(DrinkAmount.suggestions(state: state()).map(\.id))
        for ml in [50, 250, 350, 500, 750, 1000, 1500] {
            XCTAssertTrue(ids.contains("ml:\(ml):"), "missing \(ml) ml")
        }
        XCTAssertTrue(ids.contains("oz:12:"))
    }

    func test_suggestions_includeFavouriteDrinksAtUsualSize() {
        let entries = (0..<4).map { drink(.flatWhite, 220, daysAgo: Double($0)) } + [drink(.matcha, 180)]
        let ids = Set(DrinkAmount.suggestions(state: state(entries: entries)).map(\.id))
        XCTAssertTrue(ids.contains("ml:220:flatWhite"))
        XCTAssertTrue(ids.contains("ml:350:flatWhite"))
        XCTAssertTrue(ids.contains("ml:180:matcha"))
    }

    func test_suggestions_imperialUsesOunces() {
        let s = state(.imperial, entries: [drink(.coffee, 355)])
        let ids = Set(DrinkAmount.suggestions(state: s).map(\.id))
        XCTAssertTrue(ids.contains("oz:16:"))
        XCTAssertTrue(ids.contains("oz:12:coffee"))
        XCTAssertTrue(ids.contains("ml:500:"))
    }

    func test_suggestions_haveNoDuplicatesAndStaySmall() {
        let entries = FluidType.allCases.map { drink($0, 300) }
        let all = DrinkAmount.suggestions(state: state(entries: entries))
        XCTAssertEqual(all.count, Set(all.map(\.id)).count)
        XCTAssertLessThan(all.count, 120)
    }

    func test_favourites_newUserGetsStarters() {
        XCTAssertEqual(DrinkAmount.favoriteDrinks(state: state(), now: Date()), [.coffee, .tea, .latte])
    }

    func test_favourites_ignoreOldAndWater() {
        let entries = [drink(.water, 250), drink(.beer, 330, daysAgo: 90), drink(.juice, 250)]
        let favs = DrinkAmount.favoriteDrinks(state: state(entries: entries), now: Date())
        XCTAssertEqual(favs.first, .juice)
        XCTAssertFalse(favs.contains(.beer))
        XCTAssertFalse(favs.contains(.water))
    }
}
