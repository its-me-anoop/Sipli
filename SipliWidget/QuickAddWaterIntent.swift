import AppIntents
import Foundation
import WidgetKit

struct QuickAddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Quickly add water intake from the widget.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount (ml)")
    var amountML: Double

    init() {
        self.amountML = 250
    }

    init(amountML: Double) {
        self.amountML = amountML
    }

    func perform() async throws -> some IntentResult {
        let persistence = PersistenceService()
        var state = persistence.load(PersistedState.self, fallback: .default)

        let clampedAmount = min(max(amountML, 50), 2_000)
        let entry = HydrationEntry(
            date: Date(),
            volumeML: clampedAmount,
            source: .manual,
            fluidType: .water
        )

        state.entries.append(entry)
        persistence.save(state)
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
