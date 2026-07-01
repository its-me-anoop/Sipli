import XCTest
@testable import Sipli

/// Tests for the Weekly Digest's pure stats aggregation.
final class WeeklyStatsTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date {
        calendar.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
    }

    private func entry(_ ml: Double, dayOffset: Int) -> HydrationEntry {
        let day = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now))!
        return HydrationEntry(date: day.addingTimeInterval(9 * 3600), volumeML: ml, source: .manual)
    }

    func test_emptyWeek() {
        let stats = WeeklyStats.compute(entries: [], goalML: 2000, now: now)
        XCTAssertEqual(stats.totalML, 0)
        XCTAssertEqual(stats.activeDays, 0)
        XCTAssertEqual(stats.goalHits, 0)
        XCTAssertNil(stats.bestDayName)
        XCTAssertNil(stats.weekOverWeekPercent)
        XCTAssertFalse(stats.staticDigest.isEmpty)
    }

    func test_totals_activeDays_goalHits() {
        let entries = [
            entry(2000, dayOffset: 0),  // goal hit
            entry(1000, dayOffset: 1),  // active, no hit
            entry(2500, dayOffset: 2),  // goal hit
        ]
        let stats = WeeklyStats.compute(entries: entries, goalML: 2000, now: now)
        XCTAssertEqual(stats.totalML, 5500)
        XCTAssertEqual(stats.activeDays, 3)
        XCTAssertEqual(stats.goalHits, 2)
        XCTAssertEqual(stats.bestDayML, 2500)
        XCTAssertNotNil(stats.bestDayName)
        XCTAssertEqual(stats.averageML, 5500.0 / 7, accuracy: 0.01)
    }

    func test_entriesOlderThanSevenDays_excludedFromThisWeek() {
        let entries = [entry(2000, dayOffset: 0), entry(9999, dayOffset: 8)]
        let stats = WeeklyStats.compute(entries: entries, goalML: 2000, now: now)
        XCTAssertEqual(stats.totalML, 2000)
    }

    func test_weekOverWeek_percentChange() {
        let entries = [
            entry(3000, dayOffset: 0),   // this week: 3000
            entry(2000, dayOffset: 10),  // last week: 2000
        ]
        let stats = WeeklyStats.compute(entries: entries, goalML: 2000, now: now)
        XCTAssertEqual(stats.weekOverWeekPercent ?? 0, 50, accuracy: 0.01)
    }

    func test_weekOverWeek_nilWithoutPriorData() {
        let stats = WeeklyStats.compute(entries: [entry(2000, dayOffset: 0)], goalML: 2000, now: now)
        XCTAssertNil(stats.weekOverWeekPercent)
    }

    func test_staticDigest_mentionsStrongWeek() {
        let entries = (0..<7).map { entry(2500, dayOffset: $0) }
        let stats = WeeklyStats.compute(entries: entries, goalML: 2000, now: now)
        XCTAssertTrue(stats.staticDigest.contains("7"), "digest was: \(stats.staticDigest)")
    }

    func test_digestPromptBuilder_containsCoreNumbers() throws {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { throw XCTSkip("Requires iOS 26") }
        let entries = [entry(2000, dayOffset: 0), entry(1500, dayOffset: 1)]
        let stats = WeeklyStats.compute(entries: entries, goalML: 2000, now: now)
        let prompt = SipliIntelligence.digestPrompt(stats: stats)
        XCTAssertTrue(prompt.contains("3500"), "prompt was: \(prompt)")
        XCTAssertTrue(prompt.contains("2 active days"), "prompt was: \(prompt)")
        #else
        throw XCTSkip("FoundationModels unavailable")
        #endif
    }
}
