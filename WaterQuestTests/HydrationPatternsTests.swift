import XCTest
@testable import Sipli

final class HydrationPatternsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private let locale = Locale(identifier: "en_US")

    /// Wednesday 11 Nov 2026 at the given time (UTC).
    private func today(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: hour, minute: minute))!
    }

    private func day(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: today(hour, minute))!
    }

    private func entry(_ date: Date, _ ml: Double, _ fluid: FluidType = .water) -> HydrationEntry {
        HydrationEntry(date: date, volumeML: ml, source: .manual, fluidType: fluid)
    }

    /// Seven past days with the same daily rhythm.
    private func routine(days: ClosedRange<Int> = 1...7, _ slots: [(Int, Int, Double)]) -> [HydrationEntry] {
        days.flatMap { offset in slots.map { entry(day(offset, $0.0, $0.1), $0.2) } }
    }

    private func analyze(_ entries: [HydrationEntry], now: Date, goal: Double = 2500,
                         wake: Int = 7 * 60, sleep: Int = 22 * 60) -> HydrationPatterns {
        HydrationPatterns.analyze(entries: entries, goalML: goal, unit: .metric,
                                  wakeMinutes: wake, sleepMinutes: sleep,
                                  now: now, calendar: calendar, locale: locale)
    }

    // MARK: Data threshold

    func testNeedsThreeLoggedDaysBeforeClaimingPatterns() {
        let entries = routine(days: 1...2, [(8, 0, 500), (15, 0, 1000)])
        let patterns = analyze(entries, now: today(12))
        XCTAssertTrue(patterns.insights.isEmpty)
        XCTAssertNil(patterns.top)
        XCTAssertNil(patterns.quietWindow)
    }

    // MARK: Pace

    func testBehindUsualPaceIsTheTopInsight() throws {
        let entries = routine([(8, 0, 500), (10, 0, 500), (15, 0, 1000)]) + [entry(today(9), 200)]
        let patterns = analyze(entries, now: today(11))
        let top = try XCTUnwrap(patterns.top)
        XCTAssertEqual(top.kind, .pace)
        XCTAssertEqual(patterns.usualByNowML, 1000)
        XCTAssertTrue(top.title.localizedCaseInsensitiveContains("usual pace"), top.title)
        XCTAssertTrue(top.detail.contains("1000 ml"), top.detail)
        XCTAssertTrue(top.detail.contains("200 ml"), top.detail)
    }

    func testAheadOfUsualPaceIsCelebrated() throws {
        let entries = routine([(8, 0, 500), (10, 0, 500), (15, 0, 1000)]) + [entry(today(8), 800), entry(today(10), 700)]
        let pace = try XCTUnwrap(analyze(entries, now: today(11)).insights.first { $0.kind == .pace })
        XCTAssertTrue(pace.title.localizedCaseInsensitiveContains("ahead"), pace.title)
    }

    func testNoPaceInsightOnceGoalIsMet() {
        let entries = routine([(8, 0, 500), (10, 0, 500), (15, 0, 1000)]) + [entry(today(9), 2600)]
        XCTAssertFalse(analyze(entries, now: today(11)).insights.contains { $0.kind == .pace })
    }

    // MARK: Quiet window

    func testFindsTheQuietestThreeHourStretch() throws {
        let entries = routine([(8, 0, 400), (10, 0, 400), (11, 30, 400), (18, 0, 600), (20, 0, 500)])
        let patterns = analyze(entries, now: today(9))
        let window = try XCTUnwrap(patterns.quietWindow)
        XCTAssertEqual(window.startHour, 13)
        XCTAssertEqual(window.endHour, 16)
        let insight = try XCTUnwrap(patterns.insights.first { $0.kind == .quietWindow })
        XCTAssertTrue(insight.title.replacingOccurrences(of: "\u{202F}", with: " ").contains("1 PM"), insight.title)
    }

    func testEvenRhythmHasNoQuietWindow() {
        let entries = routine([(8, 0, 400), (11, 0, 400), (14, 0, 400), (17, 0, 400), (20, 0, 400)])
        XCTAssertNil(analyze(entries, now: today(9)).quietWindow)
    }

    // MARK: First sip

    func testLateFirstDrinkIsSurfaced() throws {
        let entries = routine([(10, 30, 500), (14, 0, 800), (19, 0, 800)])
        let insight = try XCTUnwrap(analyze(entries, now: today(9)).insights.first { $0.kind == .firstSip })
        XCTAssertTrue(insight.title.contains("10:30"), insight.title)
        XCTAssertTrue(insight.detail.contains("3 hours"), insight.detail)
    }

    func testEarlyFirstDrinkIsNotFlagged() {
        let entries = routine([(7, 15, 500), (14, 0, 800), (19, 0, 800)])
        XCTAssertFalse(analyze(entries, now: today(9)).insights.contains { $0.kind == .firstSip })
    }

    // MARK: Weekend rhythm

    func testLighterWeekendsAreNoticed() throws {
        // 7 Nov (offset 4) and 8 Nov (offset 3) 2026 are a Saturday and Sunday.
        var entries: [HydrationEntry] = []
        for offset in 1...7 {
            let weekend = offset == 3 || offset == 4
            entries.append(entry(day(offset, 9), weekend ? 600 : 1200))
            entries.append(entry(day(offset, 16), weekend ? 400 : 1000))
        }
        let insight = try XCTUnwrap(analyze(entries, now: today(9)).insights.first { $0.kind == .weekendRhythm })
        XCTAssertTrue(insight.title.localizedCaseInsensitiveContains("lighter"), insight.title)
    }

    // MARK: Drink mix

    func testReducedHydrationDrinksShareIsSurfaced() throws {
        let entries = routine([(8, 0, 400), (12, 0, 500)]).map { e -> HydrationEntry in
            calendar.component(.hour, from: e.date) == 8 ? entry(e.date, 600, .latte) : e
        }
        let insight = try XCTUnwrap(analyze(entries, now: today(9)).insights.first { $0.kind == .drinkMix })
        XCTAssertTrue(insight.title.contains("Latte"), insight.title)
        XCTAssertTrue(insight.title.contains("55%"), insight.title)
    }

    // MARK: Trend & consistency

    func testWeekOverWeekRiseAndConsistency() throws {
        let lastWeek = routine(days: 7...13, [(9, 0, 1000)])
        let thisWeek = routine(days: 1...6, [(9, 0, 1400)])
        let patterns = analyze(lastWeek + thisWeek + [entry(today(8), 1400)], now: today(9))
        let trend = try XCTUnwrap(patterns.insights.first { $0.kind == .trend })
        XCTAssertTrue(trend.title.hasPrefix("Up"), trend.title)
        let consistency = try XCTUnwrap(patterns.insights.first { $0.kind == .consistency })
        XCTAssertTrue(consistency.title.contains("13 of the last 14"), consistency.title)
    }

    func testInsightsAreOrderedByPriority() {
        let entries = routine([(10, 30, 500), (11, 0, 400), (19, 0, 800)])
        let priorities = analyze(entries, now: today(15)).insights.map(\.priority)
        XCTAssertEqual(priorities, priorities.sorted(by: >))
    }

    // MARK: Model grounding

    func testCoachPromptCarriesOnlyAppFactsAsData() {
        let entries = routine([(8, 0, 500), (10, 0, 500), (15, 0, 1000)]) + [entry(today(9), 200)]
        let patterns = analyze(entries, now: today(11))
        let prompt = patterns.coachPrompt
        for insight in patterns.insights {
            XCTAssertTrue(prompt.contains(insight.title), "Prompt is missing \(insight.title)")
        }
        XCTAssertTrue(prompt.contains("200 ml"))
        XCTAssertTrue(prompt.contains("2500 ml"))
    }

    // MARK: Proactive nudge

    func testPatternNudgeFiresAtStartOfQuietWindowToday() throws {
        let entries = routine([(8, 0, 400), (10, 0, 400), (11, 30, 400), (18, 0, 600), (20, 0, 500)])
        let patterns = analyze(entries, now: today(9))
        let nudge = try XCTUnwrap(patterns.proactiveNudge(now: today(9), calendar: calendar))
        XCTAssertEqual(nudge.fireDate, today(13))
        XCTAssertFalse(nudge.body.isEmpty)
    }

    func testPatternNudgeSkipsWhenWindowPassedOrGoalMet() {
        let entries = routine([(8, 0, 400), (10, 0, 400), (11, 30, 400), (18, 0, 600), (20, 0, 500)])
        XCTAssertNil(analyze(entries, now: today(14)).proactiveNudge(now: today(14), calendar: calendar))
        let met = analyze(entries + [entry(today(8), 2600)], now: today(9))
        XCTAssertNil(met.proactiveNudge(now: today(9), calendar: calendar))
    }

    // MARK: Weekly recap

    func testWeeklyRecapIsScheduledForSundayEvening() {
        let fire = WeeklyRecapNudge.nextFireDate(after: today(9), sleepMinutes: 22 * 60, calendar: calendar)
        XCTAssertEqual(fire, calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 19)))
    }

    func testWeeklyRecapMovesEarlierForEarlySleepers() {
        let fire = WeeklyRecapNudge.nextFireDate(after: today(9), sleepMinutes: 20 * 60, calendar: calendar)
        XCTAssertEqual(fire, calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 18)))
    }
}
