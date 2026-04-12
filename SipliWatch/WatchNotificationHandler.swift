import UserNotifications

enum WatchNotificationHandler {
    static let categoryIdentifier = "HYDRATION_REMINDER"
    static let logActionIdentifier = "LOG_WATER_ACTION"

    static func registerCategories() {
        let logAction = UNNotificationAction(
            identifier: logActionIdentifier,
            title: "Log 250ml 💧",
            options: .foreground
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [logAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    @MainActor
    static func handleAction(identifier: String, store: WatchHydrationStore) {
        if identifier == logActionIdentifier {
            store.addIntake(volumeML: 250, fluidType: .water)
            WatchHaptics.success()
        }
    }
}
