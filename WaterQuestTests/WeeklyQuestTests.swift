import XCTest
@testable import Sipli

final class WeeklyQuestTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date {
        calendar.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
    }

    /// A date `offset` days into the current week (0 = week start), at `hour`.
    private func weekDay(_ offset: Int, hour: Int = 10) -> Date {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        return calendar.date(byAdding: .day, value: offset, to: weekStart)!
            .addingTimeInterval(TimeInterval(hour) * 3600)
    }

    private func entry(_ ml: Double, weekDayOffset: Int, hour: Int = 10, fluid: FluidType = .water) -> HydrationEntry {
        HydrationEntry(date: weekDay(weekDayOffset, hour: hour), volumeML: ml, source: .manual, fluidType: fluid)
    }

    // MARK: - Rotation

    func test_activeQuests_areDeterministicForSameWeek() {
        let a = WeeklyQuests.active(for: now, calendar: calendar)
        let b = WeeklyQuests.active(for: now, calendar: calendar)
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(Set(a.map(\.id)).count, 3, "the three active quests must be distinct")
    }

    func test_activeQuests_sameWithinWeek_differAcrossWeeks() {
        let midWeek = calendar.date(byAdding: .hour, value: 30, to: calendar.dateInterval(of: .weekOfYear, for: now)!.start)!
        XCTAssertEqual(
            WeeklyQuests.active(for: now, calendar: calendar).map(\.id),
            WeeklyQuests.active(for: midWeek, calendar: calendar).map(\.id)
        )

        // Across many consecutive weeks the rotation must not be constant.
        let selections = (0..<8).map { offset -> [String] in
            let week = calendar.date(byAdding: .weekOfYear, value: offset, to: now)!
            return WeeklyQuests.active(for: week, calendar: calendar).map(\.id)
        }
        XCTAssertTrue(Set(selections).count > 1, "8 consecutive weeks should not all pick the same quests")
    }

    // MARK: - Progress

    private func progress(_ quest: WeeklyQuest, entries: [HydrationEntry], goal: Double = 2000) -> QuestProgress {
        WeeklyQuests.progress(for: quest, entries: entries, goalML: goal, freezeDates: [], now: now, calendar: calendar)
    }

    func test_goalDays_countsDaysMeetingGoalThisWeek() {
        let quest = WeeklyQuest(id: "t", title: "", detail: "", symbol: "", kind: .goalDays, target: 5)
        let entries = [entry(2000, weekDayOffset: 0), entry(2000, weekDayOffset: 1), entry(500, weekDayOffset: 2)]
        let p = progress(quest, entries: entries)
        XCTAssertEqual(p.done, 2)
        XCTAssertEqual(p.target, 5)
        XCTAssertFalse(p.isComplete)
    }

    func test_variety_countsDistinctFluidsThisWeek() {
        let quest = WeeklyQuest(id: "t", title: "", detail: "", symbol: "", kind: .varietyCount, target: 3)
        let entries = [
            entry(200, weekDayOffset: 0, fluid: .water),
            entry(200, weekDayOffset: 0, fluid: .coffee),
            entry(200, weekDayOffset: 1, fluid: .coffee),
        ]
        XCTAssertEqual(progress(quest, entries: entries).done, 2)
    }

    func test_morningLogs_countBeforeNoon() {
        let quest = WeeklyQuest(id: "t", title: "", detail: "", symbol: "", kind: .morningLogs, target: 3)
        let entries = [
            entry(200, weekDayOffset: 0, hour: 8),
            entry(200, weekDayOffset: 0, hour: 11),
            entry(200, weekDayOffset: 1, hour: 12), // noon — not morning
        ]
        XCTAssertEqual(progress(quest, entries: entries).done, 2)
    }

    func test_volumeLitres_sumsEffectiveML() {
        let quest = WeeklyQuest(id: "t", title: "", detail: "", symbol: "", kind: .volumeLitres, target: 10)
        let entries = [entry(3000, weekDayOffset: 0), entry(2500, weekDayOffset: 1)]
        XCTAssertEqual(progress(quest, entries: entries).done, 5, "5.5L floors to 5")
    }

    func test_loggingDays_countsDistinctDaysWithAnyEntry() {
        let quest = WeeklyQuest(id: "t", title: "", detail: "", symbol: "", kind: .loggingDays, target: 7)
        let entries = [
            entry(100, weekDayOffset: 0, hour: 8),
            entry(100, weekDayOffset: 0, hour: 18),
            entry(100, weekDayOffset: 2),
        ]
        XCTAssertEqual(progress(quest, entries: entries).done, 2)
    }

    func test_progress_ignoresEntriesFromOtherWeeks() {
        let quest = WeeklyQuest(id: "t", title: "", detail: "", symbol: "", kind: .loggingDays, target: 7)
        let lastWeek = calendar.date(byAdding: .day, value: -8, to: now)!
        let old = HydrationEntry(date: lastWeek, volumeML: 2000, source: .manual)
        XCTAssertEqual(progress(quest, entries: [old]).done, 0)
    }

    func test_isComplete_capsAtTarget() {
        let quest = WeeklyQuest(id: "t", title: "", detail: "", symbol: "", kind: .morningLogs, target: 2)
        let entries = (0..<4).map { entry(100, weekDayOffset: $0, hour: 8) }
        let p = progress(quest, entries: entries)
        XCTAssertTrue(p.isComplete)
        XCTAssertEqual(p.done, 2, "display value caps at the target")
    }

    func test_daysRemainingInWeek_isBetween0And6() {
        let d = WeeklyQuests.daysRemaining(now: now, calendar: calendar)
        XCTAssertTrue((0...6).contains(d))
    }
}
