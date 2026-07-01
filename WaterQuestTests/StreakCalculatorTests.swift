import XCTest
@testable import Sipli

/// Tests for the unified, freeze-aware streak algorithm that replaced the
/// three inlined copies (store / insights / widget).
final class StreakCalculatorTests: XCTestCase {

    private let calendar = Calendar.current
    /// Fixed "now" mid-afternoon so start-of-day math is unambiguous.
    private var now: Date {
        calendar.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!
            .addingTimeInterval(10 * 3600) // 10:00 that day
    }

    private func entry(_ ml: Double, dayOffset: Int) -> HydrationEntry {
        HydrationEntry(date: day(dayOffset), volumeML: ml, source: .manual)
    }

    // MARK: - Base algorithm (parity with the old implementations)

    func test_streak_countsConsecutiveGoalDays_endingToday() {
        let entries = [entry(2000, dayOffset: 0), entry(2000, dayOffset: 1), entry(2000, dayOffset: 2)]
        XCTAssertEqual(
            StreakCalculator.currentStreak(entries: entries, goalML: 2000, now: now),
            3
        )
    }

    func test_streak_todayNotMetYet_anchorsOnYesterday() {
        let entries = [entry(500, dayOffset: 0), entry(2000, dayOffset: 1), entry(2000, dayOffset: 2)]
        XCTAssertEqual(
            StreakCalculator.currentStreak(entries: entries, goalML: 2000, now: now),
            2,
            "an unfinished today must not break the run"
        )
    }

    func test_streak_gapBreaksRun() {
        let entries = [entry(2000, dayOffset: 0), entry(2000, dayOffset: 2)] // day 1 missing
        XCTAssertEqual(
            StreakCalculator.currentStreak(entries: entries, goalML: 2000, now: now),
            1
        )
    }

    func test_streak_zeroGoal_isZero() {
        XCTAssertEqual(
            StreakCalculator.currentStreak(entries: [entry(2000, dayOffset: 0)], goalML: 0, now: now),
            0
        )
    }

    func test_streak_effectiveML_respectsHydrationFactor() {
        // 2000 ml coffee at 0.8 factor = 1600 effective — misses a 2000 goal.
        let entries = [HydrationEntry(date: day(0), volumeML: 2000, source: .manual, fluidType: .coffee)]
        XCTAssertEqual(
            StreakCalculator.currentStreak(entries: entries, goalML: 2000, now: now),
            0
        )
    }

    // MARK: - Freezes

    func test_streak_frozenDayBridgesGap() {
        let entries = [entry(2000, dayOffset: 0), entry(2000, dayOffset: 2), entry(2000, dayOffset: 3)]
        let frozen = [calendar.startOfDay(for: day(1))]
        XCTAssertEqual(
            StreakCalculator.currentStreak(entries: entries, goalML: 2000, freezeDates: frozen, now: now),
            4,
            "a frozen day counts as goal-met"
        )
    }

    func test_freezeConsumableDate_yesterdayMissed_withPriorStreak() {
        let entries = [entry(2000, dayOffset: 2), entry(2000, dayOffset: 3)] // yesterday empty
        let date = StreakCalculator.freezeConsumableDate(
            entries: entries, goalML: 2000, freezeDates: [], tokens: 1, now: now
        )
        XCTAssertEqual(date, calendar.startOfDay(for: day(1)))
    }

    func test_freezeConsumableDate_noTokens_returnsNil() {
        let entries = [entry(2000, dayOffset: 2)]
        XCTAssertNil(
            StreakCalculator.freezeConsumableDate(
                entries: entries, goalML: 2000, freezeDates: [], tokens: 0, now: now
            )
        )
    }

    func test_freezeConsumableDate_noPriorStreak_returnsNil() {
        // Nothing before yesterday — a freeze must not start a streak.
        XCTAssertNil(
            StreakCalculator.freezeConsumableDate(
                entries: [], goalML: 2000, freezeDates: [], tokens: 2, now: now
            )
        )
    }

    func test_freezeConsumableDate_yesterdayMet_returnsNil() {
        let entries = [entry(2000, dayOffset: 1), entry(2000, dayOffset: 2)]
        XCTAssertNil(
            StreakCalculator.freezeConsumableDate(
                entries: entries, goalML: 2000, freezeDates: [], tokens: 1, now: now
            )
        )
    }

    func test_freezeConsumableDate_alreadyFrozen_returnsNil() {
        let entries = [entry(2000, dayOffset: 2)]
        let frozen = [calendar.startOfDay(for: day(1))]
        XCTAssertNil(
            StreakCalculator.freezeConsumableDate(
                entries: entries, goalML: 2000, freezeDates: frozen, tokens: 1, now: now
            ),
            "the same day must never consume two tokens"
        )
    }
}
