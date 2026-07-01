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

    // iOS 27 SDK API — fenced to Xcode 27 (Swift 6.4); the public App Store
    // toolchain is Xcode 26.6 (Swift 6.3) until Xcode 27 goes GM.
    #if compiler(>=6.4)
    /// iOS 27: interactive widget buttons execute this in the widget
    /// extension process — declare that so the system doesn't probe others.
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.widgetKitExtension] }
    #endif

    func perform() async throws -> some IntentResult {
        let clampedAmount = min(max(amountML, 50), 2_000)

        // Coordinated read-modify-write: the widget process and the app (or
        // Siri) can log at the same moment on the same shared file.
        PersistenceService().update(PersistedState.self, fallback: .default) { state in
            state.entries.append(
                HydrationEntry(
                    date: Date(),
                    volumeML: clampedAmount,
                    source: .manual,
                    fluidType: .water
                )
            )
        }
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
