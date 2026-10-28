import XCTest
@testable import Sipli

@MainActor
final class LivingInsightTests: XCTestCase {
    private var now: Date { Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 14))! }
    private func entry(_ volume: Double = 250, date: Date? = nil, source: HydrationSource = .manual) -> HydrationEntry {
        HydrationEntry(date: date ?? now, volumeML: volume, source: source)
    }
    private func snapshot(_ entries: [HydrationEntry], goal: Double = 2000, date: Date? = nil) -> LivingInsightSnapshot {
        LivingInsightSnapshot(entries: entries, goalML: goal, now: date ?? now, unit: .metric)
    }
    private func coordinator() -> LivingBottleCoordinator {
        let name = "LivingInsightTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return LivingBottleCoordinator(defaults: defaults)
    }
    func testSnapshotDetectsSameCountEditsGoalsUnitsAndRollover() {
        let original = entry()
        var edited = original; edited.volumeML = 500
        XCTAssertNotEqual(snapshot([original]), snapshot([edited]))
        XCTAssertNotEqual(snapshot([original]), snapshot([original], goal: 2500))
        let tomorrow = now.addingTimeInterval(86400)
        XCTAssertEqual(snapshot([original], date: tomorrow).totalML, 0)
        XCTAssertNotEqual(snapshot([original]), snapshot([original], date: tomorrow))
        XCTAssertNotEqual(snapshot([original]), LivingInsightSnapshot(entries: [original], goalML: 2000, now: now, unit: .imperial))
    }
    func testWelcomeIsGentleAndRateLimitedAndNeverAtGoal() {
        let old = entry(500, date: now.addingTimeInterval(-5 * 3600))
        var policy = BottleFeedbackPolicy()
        XCTAssertTrue(policy.welcomes(snapshot: snapshot([old]), now: now))
        XCTAssertFalse(policy.welcomes(snapshot: snapshot([]), now: now))
        XCTAssertFalse(policy.welcomes(snapshot: snapshot([old], goal: 500), now: now))
        policy.lastWelcome = now
        XCTAssertFalse(policy.welcomes(snapshot: snapshot([old]), now: now.addingTimeInterval(3600)))
        policy.lastWelcome = nil; policy.snoozedUntil = now.addingTimeInterval(86400)
        XCTAssertFalse(policy.welcomes(snapshot: snapshot([old]), now: now))
    }
    func testAcknowledgementRejectsExcessHealthImportsAndUndoReplay() {
        var policy = BottleFeedbackPolicy()
        let log = entry()
        XCTAssertTrue(policy.acknowledge(log, snapshot: snapshot([log]), now: now))
        XCTAssertFalse(policy.acknowledge(entry(), snapshot: snapshot([log]), now: now.addingTimeInterval(100)))
        XCTAssertFalse(policy.acknowledge(entry(1000), snapshot: snapshot([]), now: now))
        XCTAssertFalse(policy.acknowledge(entry(600), snapshot: snapshot([entry(2100)]), now: now))
        XCTAssertFalse(policy.acknowledge(entry(100, source: .healthKit), snapshot: snapshot([]), now: now))
        XCTAssertFalse(policy.acknowledge(entry(0), snapshot: snapshot([]), now: now))
    }
    func testActiveEntryDefersFeedbackAndDeletionInvalidatesIt() {
        let c = coordinator()
        c.update(snapshot([]), now: now, canPresent: true, useAI: false)
        let log = entry()
        c.update(snapshot([log]), now: now, canPresent: false, useAI: false)
        XCTAssertNil(c.notice)
        c.update(snapshot([]), now: now, canPresent: false, useAI: false)
        c.present(now: now, allowed: true)
        XCTAssertNil(c.notice)
    }
    func testSavePresentsOnlyOnceAndBackgroundNeverReplays() {
        let c = coordinator()
        c.update(snapshot([]), now: now, canPresent: true, useAI: false)
        c.update(snapshot([entry()]), now: now, canPresent: false, useAI: false)
        c.present(now: now, allowed: true)
        XCTAssertEqual(c.notice?.purpose, .logged)
        let id = c.notice!.id
        c.expire(id); c.present(now: now.addingTimeInterval(5), allowed: true)
        XCTAssertNil(c.notice)
        c.background(); c.present(now: now.addingTimeInterval(6), allowed: true)
        XCTAssertNil(c.notice)
        XCTAssertFalse(c.onDeviceWording)
        XCTAssertEqual(c.wording, c.snapshot?.fallback)
    }
    func testWelcomeDismissalSurvivesCoordinatorRestart() {
        let defaults = UserDefaults(suiteName: "LivingDismiss." + UUID().uuidString)!
        let old = entry(500, date: now.addingTimeInterval(-5 * 3600))
        let s = snapshot([old])
        let c = LivingBottleCoordinator(defaults: defaults)
        c.update(s, now: now, canPresent: true, useAI: false)
        XCTAssertEqual(c.notice?.purpose, .returning)
        c.dismiss(now: now)
        let reopened = LivingBottleCoordinator(defaults: defaults)
        reopened.update(s, now: now.addingTimeInterval(60), canPresent: true, useAI: false)
        XCTAssertNil(reopened.notice)
    }
    func testInvalidArithmeticAndOverGoalCopyStaySafe() {
        let s = snapshot([entry(-100), entry(.nan), entry(2500)])
        XCTAssertEqual(s.totalML, 2500)
        XCTAssertEqual(s.progress, 1)
        for tone in [BottleTone.calm, .warm, .practical] {
            XCTAssertEqual(BottleCopy.text(tone: tone, purpose: .insight, snapshot: s), s.fallback)
            XCTAssertEqual(BottleCopy.text(tone: tone, purpose: .logged, snapshot: s), "Added to your log.")
        }
    }
    func testAnalyticsCacheRefreshesForCorrectionsAndDayChanges() {
        let model = InsightsViewModel()
        let original = entry()
        model.recompute(entries: [original], dailyGoalML: 2000, timeframe: .weekly, heatmapMonthOffset: 0, now: now)
        XCTAssertEqual(model.chartData.last?.totalML, 250)
        var edited = original; edited.volumeML = 600
        model.recompute(entries: [edited], dailyGoalML: 2000, timeframe: .weekly, heatmapMonthOffset: 0, now: now)
        XCTAssertEqual(model.chartData.last?.totalML, 600)
        model.recompute(entries: [edited], dailyGoalML: 2000, timeframe: .weekly, heatmapMonthOffset: 0, now: now.addingTimeInterval(86400))
        XCTAssertEqual(model.chartData.last?.totalML, 0)
        model.recompute(entries: [], dailyGoalML: 2000, timeframe: .weekly, heatmapMonthOffset: 0, now: now.addingTimeInterval(86400))
        XCTAssertTrue(model.chartData.allSatisfy { $0.totalML == 0 })
    }

    func testStaleAsyncWordingCannotReplaceNewFacts() async throws {
        var completion: CheckedContinuation<BottleTone?, Never>?
        let defaults = UserDefaults(suiteName: "LivingAsync." + UUID().uuidString)!
        let c = LivingBottleCoordinator(defaults: defaults, toneGenerator: { _ in
            await withCheckedContinuation { completion = $0 }
        })
        c.update(snapshot([entry()]), now: now, canPresent: false, useAI: true)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertNotNil(completion)
        let changed = snapshot([entry(500)])
        c.update(changed, now: now, canPresent: false, useAI: false)
        completion?.resume(returning: .warm)
        await Task.yield()
        XCTAssertEqual(c.wording, changed.fallback)
        XCTAssertFalse(c.onDeviceWording)
    }

    func testWelcomeOnlyOccursOnOpeningAndWaitsForEntryFlow() {
        let c = coordinator()
        let old = entry(500, date: now.addingTimeInterval(-5 * 3600))
        c.entryFlowActive = true
        c.update(snapshot([old]), now: now, canPresent: true, useAI: false)
        XCTAssertNil(c.notice)
        c.entryFlowActive = false
        c.present(now: now, allowed: true)
        XCTAssertEqual(c.notice?.purpose, .returning)
        c.dismiss(now: now)
        c.present(now: now.addingTimeInterval(90000), allowed: true)
        XCTAssertNil(c.notice, "An open screen must not create repeated welcome messages")
    }

    func testBrownAccentsAndSelectedGlyphsHaveContrastInBothThemes() {
        func luminance(_ v:[Double])->Double {
            let c=v.map { $0 <= 0.04045 ? $0/12.92 : pow(($0+0.055)/1.055,2.4) }
            return c[0]*0.2126+c[1]*0.7152+c[2]*0.0722
        }
        func ratio(_ a:[Double],_ b:[Double])->Double {
            let x=luminance(a),y=luminance(b);return (max(x,y)+0.05)/(min(x,y)+0.05)
        }
        // Representative white and dark elevated card surfaces; native captures verify the actual UI.
        for isDark in [false,true] {
            let surface = isDark ? [44.0/255,44.0/255,46.0/255] : [1.0,1.0,1.0]
            for fluid in FluidType.allCases where fluid.usesBrownAccent {
                let fg = fluid.brownAccentComponents(isDark:isDark)!
                let chip=zip(fg,surface).map { $0*0.14+$1*0.86 }
                XCTAssertGreaterThanOrEqual(ratio(fg,chip),4.5,"\(fluid) dark=\(isDark)")
                XCTAssertGreaterThanOrEqual(ratio(fluid.selectionComponents(isDark:isDark),fg),4.5)
                if isDark {
                    let disabled=zip(fg,surface).map { $0*0.5+$1*0.5 }
                    XCTAssertGreaterThanOrEqual(ratio(disabled,surface),3)
                }
            }
        }
    }


}
