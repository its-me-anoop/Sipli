import AppIntents
import WidgetKit

struct WatchQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Quickly log 250ml of water from the Watch.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let persistence = PersistenceService()
        var state = persistence.load(PersistedState.self, fallback: .default)

        let entry = HydrationEntry(
            date: Date(),
            volumeML: 250,
            source: .watchManual,
            fluidType: .water
        )

        state.entries.append(entry)
        persistence.save(state)
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
