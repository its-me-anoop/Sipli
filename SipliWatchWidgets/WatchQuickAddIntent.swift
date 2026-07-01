import AppIntents
import WidgetKit
import WatchKit

struct WatchQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Quickly log 250ml of water from the Watch.")
    static var openAppWhenRun: Bool = false

    /// watchOS 27: complications execute this in the watch widget extension.
    @available(watchOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.widgetKitExtension] }

    func perform() async throws -> some IntentResult {
        // Coordinated read-modify-write against the shared state file so a
        // complication tap can't race the watch app's own writes.
        PersistenceService().update(PersistedState.self, fallback: .default) { state in
            state.entries.append(
                HydrationEntry(
                    date: Date(),
                    volumeML: 250,
                    source: .watchManual,
                    fluidType: .water
                )
            )
        }
        WidgetCenter.shared.reloadAllTimelines()

        WKInterfaceDevice.current().play(.success)

        return .result()
    }
}
