import XCTest
@testable import Sipli

/// Tests for the Quick Log preset learner.
final class QuickLogPresetsTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date { Date() }

    private func entry(
        _ ml: Double,
        fluid: FluidType = .water,
        daysAgo: Int = 1,
        source: HydrationSource = .manual
    ) -> HydrationEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        return HydrationEntry(date: date, volumeML: ml, source: source, fluidType: fluid)
    }

    func test_emptyHistory_returnsDefaults() {
        let presets = QuickLogPresets.presets(from: [], allowAllFluids: true, now: now)
        XCTAssertEqual(presets, QuickLogPresets.defaults())
    }

    func test_mostFrequentHabitRanksFirst() {
        let entries = [
            entry(250, fluid: .coffee), entry(250, fluid: .coffee), entry(250, fluid: .coffee),
            entry(500, fluid: .water),
        ]
        let presets = QuickLogPresets.presets(from: entries, allowAllFluids: true, now: now)
        XCTAssertEqual(presets.first, QuickLogPresets.Preset(fluidType: .coffee, amountML: 250))
    }

    func test_amountsBucketToNearestFifty() {
        let entries = [entry(240), entry(255), entry(260)]
        let presets = QuickLogPresets.presets(from: entries, allowAllFluids: true, now: now)
        XCTAssertEqual(presets.first, QuickLogPresets.Preset(fluidType: .water, amountML: 250))
    }

    func test_freeTier_surfacesOnlyWater() {
        let entries = [
            entry(250, fluid: .coffee), entry(250, fluid: .coffee),
            entry(500, fluid: .water),
        ]
        let presets = QuickLogPresets.presets(from: entries, allowAllFluids: false, now: now)
        XCTAssertTrue(presets.allSatisfy { $0.fluidType == .water })
        XCTAssertEqual(presets.first, QuickLogPresets.Preset(fluidType: .water, amountML: 500))
    }

    func test_nonManualAndStaleEntries_ignored() {
        let entries = [
            entry(300, source: .healthKit),          // not manual
            entry(400, daysAgo: 45),                 // stale
        ]
        let presets = QuickLogPresets.presets(from: entries, allowAllFluids: true, now: now)
        XCTAssertEqual(presets, QuickLogPresets.defaults())
    }

    func test_paddedWithDefaults_withoutDuplicates() {
        let entries = [entry(250), entry(250)] // learned: water 250 (a default too)
        let presets = QuickLogPresets.presets(from: entries, allowAllFluids: true, now: now)
        XCTAssertEqual(presets.count, 3)
        XCTAssertEqual(Set(presets.map(\.id)).count, 3, "no duplicate presets")
        XCTAssertEqual(presets.first, QuickLogPresets.Preset(fluidType: .water, amountML: 250))
    }
}
