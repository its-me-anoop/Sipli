import SwiftUI
import WidgetKit
import AppIntents

/// Control Center / Lock Screen quick-log button (iOS 18+).
///
/// One tap logs 250 ml of water through the same `QuickAddWaterIntent` the
/// interactive widget buttons use — the coordinated `PersistenceService.update`
/// write path, so it's safe alongside the app and Siri.
@available(iOS 18.0, *)
struct SipliQuickLogControl: ControlWidget {
    static let kind = "SipliQuickLogControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuickAddWaterIntent(amountML: 250)) {
                Label("Log 250 ml", systemImage: "drop.fill")
            }
        }
        .displayName("Log Water")
        .description("Log 250 ml of water with one tap.")
    }
}
