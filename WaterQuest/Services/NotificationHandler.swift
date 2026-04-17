import Foundation
import UserNotifications

/// Forwarding target for notification default-taps. The app sets this on
/// `NotificationHandler.shared` so default taps can surface the deep-link
/// signal via the existing `@State var deepLinkAddIntake` plumbing in
/// ``WaterQuestApp``.
protocol NotificationDeepLinkForwarding: AnyObject {
    func openAddIntake()
}

/// `UNUserNotificationCenterDelegate` singleton. Installed once in
/// ``WaterQuestApp`` at launch. Holds a weak ``HydrationStore`` so
/// action taps can log intake silently from the lock screen.
///
/// The singleton pattern is intentional: the `UNUserNotificationCenter`
/// delegate API is a singleton on the iOS side too, and the handler needs
/// to exist before any `@StateObject` is initialized so cold launches
/// triggered by a notification tap don't drop the tap on the floor.
@MainActor
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationHandler()

    weak var store: HydrationStore?
    weak var deepLinkForwarder: NotificationDeepLinkForwarding?

    private override init() { super.init() }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when the app is foregrounded and a notification arrives.
    /// Default behavior suppresses the banner; return `.banner` so the
    /// user still sees the reminder even while using the app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Called when the user taps a notification or an action button.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        Task { @MainActor in
            self.handle(actionID: actionID)
            completionHandler()
        }
    }

    // MARK: - Action dispatch

    private func handle(actionID: String) {
        switch actionID {
        case NotificationActionID.log250ml.rawValue:
            logAmount(ml: 250)
        case NotificationActionID.log500ml.rawValue:
            logAmount(ml: 500)
        case NotificationActionID.snooze1h.rawValue:
            snoozeOneHour()
        case UNNotificationDefaultActionIdentifier:
            deepLinkForwarder?.openAddIntake()
        default:
            break
        }
    }

    private func logAmount(ml: Double) {
        guard let store = store else { return }
        _ = store.addIntake(
            amount: ml,
            unitSystem: .metric,
            source: .manual,
            fluidType: .water,
            note: nil
        )
    }

    private func snoozeOneHour() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let smart = requests
                .filter { $0.identifier.hasPrefix("sipli.smart.") }
            if let next = smart.min(by: { lhs, rhs in
                let l = (lhs.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
                let r = (rhs.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
                return l < r
            }) {
                center.removePendingNotificationRequests(withIdentifiers: [next.identifier])
            }

            let content = UNMutableNotificationContent()
            content.title = "Sipli"
            content.body = "Here's your snoozed reminder — sip time!"
            content.sound = .default
            content.categoryIdentifier = NotificationCategoryID.hydrationReminder.rawValue
            content.userInfo = ["deepLink": "sipli://add-intake"]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
            let request = UNNotificationRequest(
                identifier: "sipli.snooze.\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error = error {
                    #if DEBUG
                    print("NotificationHandler: failed to schedule snooze — \(error)")
                    #endif
                }
            }
        }
    }
}
