import XCTest
@testable import Sipli

/// Tests for the pure achievement evaluation engine. Mirrors the
/// StreakCalculatorTests style: fixed mid-afternoon "now", day offsets,
/// everything injected.
final class AchievementEngineTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date {
        calendar.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
    }

    private func day(_ offset: Int, hour: Int = 10) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
            .addingTimeInterval(TimeInterval(hour) * 3600)
    }

    private func entry(_ ml: Double, dayOffset: Int, hour: Int = 10, fluid: FluidType = .water) -> HydrationEntry {
        HydrationEntry(date: day(dayOffset, hour: hour), volumeML: ml, source: .manual, fluidType: fluid)
    }

    private func state(
        entries: [HydrationEntry] = [],
        goalCompletionCount: Int = 0,
        matchDayWins: Int = 0,
        streakFreezeTokens: Int = 0,
        streakFreezeDates: [Date] = [],
        counters: EngagementCounters = .zero
    ) -> PersistedState {
        var s = PersistedState.default
        s.entries = entries
        s.goalCompletionCount = goalCompletionCount
        s.matchDayWins = matchDayWins
        s.streakFreezeTokens = streakFreezeTokens
        s.streakFreezeDates = streakFreezeDates
        s.counters = counters
        return s
    }

    private func earned(_ s: PersistedState, goal: Double = 2000) -> Set<String> {
        AchievementEngine.earned(state: s, goalML: goal, now: now, calendar: calendar)
    }

    // MARK: - Catalog sanity

    func test_catalog_idsAreUnique() {
        let ids = AchievementCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_freshState_earnsNothing() {
        XCTAssertTrue(earned(state()).isEmpty)
    }

    // MARK: - Consistency

    func test_streakMilestones_unlockAtThresholds() {
        let entries = (0..<7).map { entry(2000, dayOffset: $0) }
        let result = earned(state(entries: entries))
        XCTAssertTrue(result.contains("streak.3"))
        XCTAssertTrue(result.contains("streak.7"))
        XCTAssertFalse(result.contains("streak.14"))
    }

    func test_streakMilestone_usesLongestEverStreak_notCurrent() {
        // A 7-day run in the past followed by a gap and a fresh 1-day run.
        var entries = (10..<17).map { entry(2000, dayOffset: $0) }
        entries.append(entry(2000, dayOffset: 0))
        let result = earned(state(entries: entries))
        XCTAssertTrue(result.contains("streak.7"), "a broken streak must not revoke the milestone")
    }

    func test_streak_frozenDaysBridgeGaps() {
        var entries = (0..<3).map { entry(2000, dayOffset: $0) }
        entries.append(contentsOf: (4..<7).map { entry(2000, dayOffset: $0) })
        let frozen = [calendar.startOfDay(for: day(3))]
        let result = earned(state(entries: entries, streakFreezeDates: frozen))
        XCTAssertTrue(result.contains("streak.7"))
    }

    func test_purist_requiresThirtyDaysWithoutFreezes() {
        // 30-day streak but one day only counts because it's frozen → no purist.
        var entries = (0..<15).map { entry(2000, dayOffset: $0) }
        entries.append(contentsOf: (16..<31).map { entry(2000, dayOffset: $0) })
        let frozen = [calendar.startOfDay(for: day(15))]
        let withFreeze = earned(state(entries: entries, streakFreezeDates: frozen))
        XCTAssertTrue(withFreeze.contains("streak.30"), "freeze bridges the milestone streak")
        XCTAssertFalse(withFreeze.contains("secret.purist"))

        // A clean 30-day streak earns it.
        let clean = (0..<30).map { entry(2000, dayOffset: $0) }
        XCTAssertTrue(earned(state(entries: clean)).contains("secret.purist"))
    }

    func test_perfectWeek_requiresAllSevenDaysOfCalendarWeek() {
        // Fill the most recent fully-elapsed calendar week (offsets vary with
        // the weekday "now" falls on), so just fill 14 days — guaranteed to
        // cover at least one full calendar week.
        let entries = (0..<14).map { entry(2000, dayOffset: $0) }
        XCTAssertTrue(earned(state(entries: entries)).contains("week.perfect"))

        // Six scattered days never yield a perfect week.
        let sparse = (0..<6).map { entry(2000, dayOffset: $0 * 2) }
        XCTAssertFalse(earned(state(entries: sparse)).contains("week.perfect"))
    }

    // MARK: - Volume

    func test_volumeMilestones_useLifetimeEffectiveML() {
        // 6 days × 2L = 12L effective.
        let entries = (0..<6).map { entry(2000, dayOffset: $0) }
        let result = earned(state(entries: entries))
        XCTAssertTrue(result.contains("volume.10"))
        XCTAssertFalse(result.contains("volume.50"))
    }

    func test_volume_respectsHydrationFactor() {
        // 10L of beer (factor < 1) must not count as 10L effective.
        let entries = [HydrationEntry(date: day(0), volumeML: 10_000, source: .manual, fluidType: .beer)]
        XCTAssertFalse(earned(state(entries: entries)).contains("volume.10"))
    }

    func test_overflow_singleDayAt150Percent() {
        let entries = [entry(3000, dayOffset: 1)]
        XCTAssertTrue(earned(state(entries: entries)).contains("day.overflow"))
        XCTAssertFalse(earned(state(entries: [entry(2900, dayOffset: 1)])).contains("day.overflow"))
    }

    // MARK: - Explorer

    func test_explorer_countsDistinctFluidTypes() {
        let entries = [
            entry(200, dayOffset: 0, fluid: .water),
            entry(200, dayOffset: 0, fluid: .coffee),
            entry(200, dayOffset: 1, fluid: .greenTea),
        ]
        let result = earned(state(entries: entries))
        XCTAssertTrue(result.contains("explorer.first"))
        XCTAssertTrue(result.contains("explorer.3"))
        XCTAssertFalse(result.contains("explorer.8"))
    }

    func test_explorerFirst_waterOnlyDoesNotCount() {
        let entries = [entry(200, dayOffset: 0, fluid: .water)]
        XCTAssertFalse(earned(state(entries: entries)).contains("explorer.first"))
    }

    // MARK: - Dedication

    func test_goalDayMilestones_useLifetimeCounter() {
        let result = earned(state(goalCompletionCount: 30))
        XCTAssertTrue(result.contains("goal.7"))
        XCTAssertTrue(result.contains("goal.30"))
        XCTAssertFalse(result.contains("goal.100"))
    }

    func test_earlyBird_beforeSevenAM() {
        XCTAssertTrue(earned(state(entries: [entry(200, dayOffset: 0, hour: 6)])).contains("earlybird"))
        XCTAssertFalse(earned(state(entries: [entry(200, dayOffset: 0, hour: 7)])).contains("earlybird"))
    }

    func test_nightOwl_tenPMOrLater() {
        XCTAssertTrue(earned(state(entries: [entry(200, dayOffset: 0, hour: 22)])).contains("nightowl"))
        XCTAssertFalse(earned(state(entries: [entry(200, dayOffset: 0, hour: 21)])).contains("nightowl"))
    }

    func test_midnightSip_isTheZeroHour() {
        XCTAssertTrue(earned(state(entries: [entry(200, dayOffset: 0, hour: 0)])).contains("secret.midnight"))
        XCTAssertFalse(earned(state(entries: [entry(200, dayOffset: 0, hour: 1)])).contains("secret.midnight"))
    }

    func test_weekendWarrior_requiresBothWeekendDaysMet() {
        // 14 consecutive met days necessarily include a full Sat+Sun pair.
        let entries = (0..<14).map { entry(2000, dayOffset: $0) }
        XCTAssertTrue(earned(state(entries: entries)).contains("weekend.perfect"))
        XCTAssertFalse(earned(state(entries: [entry(2000, dayOffset: 0)])).contains("weekend.perfect"))
    }

    func test_iceReserves_atMaxTokens() {
        XCTAssertTrue(earned(state(streakFreezeTokens: 3)).contains("freeze.full"))
        XCTAssertFalse(earned(state(streakFreezeTokens: 2)).contains("freeze.full"))
    }

    // MARK: - Season

    func test_matchDay_winMilestones() {
        XCTAssertTrue(earned(state(matchDayWins: 1)).contains("matchday.first"))
        XCTAssertFalse(earned(state(matchDayWins: 1)).contains("matchday.golden"))
        XCTAssertTrue(earned(state(matchDayWins: 12)).contains("matchday.golden"))
    }

    // MARK: - Counter-backed secrets

    func test_counterSecrets() {
        let counters = EngagementCounters(siriLogCount: 1, widgetLogCount: 1, undoCount: 5)
        let result = earned(state(counters: counters))
        XCTAssertTrue(result.contains("secret.siri"))
        XCTAssertTrue(result.contains("secret.widget"))
        XCTAssertTrue(result.contains("secret.undo"))

        let below = EngagementCounters(siriLogCount: 0, widgetLogCount: 0, undoCount: 4)
        let none = earned(state(counters: below))
        XCTAssertFalse(none.contains("secret.siri"))
        XCTAssertFalse(none.contains("secret.undo"))
    }

    // MARK: - Zero goal safety

    func test_zeroGoal_earnsNoGoalRelativeBadges() {
        let entries = (0..<14).map { entry(2000, dayOffset: $0) }
        let result = earned(state(entries: entries), goal: 0)
        XCTAssertFalse(result.contains("streak.3"))
        XCTAssertFalse(result.contains("day.overflow"))
        XCTAssertFalse(result.contains("week.perfect"))
        // Volume and explorer badges don't depend on the goal.
        XCTAssertTrue(result.contains("volume.10"))
    }

    // MARK: - Persistence migration

    func test_persistedState_decodesLegacyPayloadWithoutAchievementFields() throws {
        // v4.1 payload: no unlockedAchievements / counters keys.
        var legacy = PersistedState.default
        legacy.entries = [entry(500, dayOffset: 0)]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var json = try JSONSerialization.jsonObject(with: encoder.encode(legacy)) as! [String: Any]
        json.removeValue(forKey: "unlockedAchievements")
        json.removeValue(forKey: "counters")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try decoder.decode(PersistedState.self, from: data)

        XCTAssertTrue(decoded.unlockedAchievements.isEmpty)
        XCTAssertEqual(decoded.counters, .zero)
        XCTAssertEqual(decoded.entries.count, 1)
    }

    func test_persistedState_roundTripsAchievementFields() throws {
        var s = PersistedState.default
        s.unlockedAchievements = ["streak.3": day(1)]
        s.counters = EngagementCounters(siriLogCount: 2, widgetLogCount: 3, undoCount: 4)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PersistedState.self, from: encoder.encode(s))

        XCTAssertEqual(decoded.unlockedAchievements.keys.first, "streak.3")
        XCTAssertEqual(decoded.counters.siriLogCount, 2)
        XCTAssertEqual(decoded.counters.undoCount, 4)
    }
}
