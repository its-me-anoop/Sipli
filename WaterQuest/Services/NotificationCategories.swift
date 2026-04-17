import Foundation
import UserNotifications

/// Stable identifiers for notification categories. String values are the
/// identifiers iOS stores — changing them is a breaking change, so only
/// add new cases, never rename.
enum NotificationCategoryID: String {
    case hydrationReminder = "HYDRATION_REMINDER"
    // Phase 2: case hydrationCelebration = "HYDRATION_CELEBRATION"
    // Phase 3: case hydrationComeback     = "HYDRATION_COMEBACK"
    // Phase 3: case hydrationWorkout      = "HYDRATION_WORKOUT"
}

/// Stable identifiers for action buttons. Same rules as
/// ``NotificationCategoryID`` — additive only.
enum NotificationActionID: String {
    case log250ml = "LOG_250ML"
    case log500ml = "LOG_500ML"
    case snooze1h = "SNOOZE_1H"
    // Phase 3: case logGlassComeback = "LOG_GLASS_COMEBACK"
    // Phase 3: case notToday         = "NOT_TODAY"
    // Phase 3: case logGlassWorkout  = "LOG_GLASS_WORKOUT"
}

/// Factory and registration helper for all notification categories used by
/// the iPhone app. Call ``registerAll()`` once at app launch.
enum NotificationCategories {

    /// Every category the app registers with the system.
    static var all: [UNNotificationCategory] {
        [hydrationReminder]
    }

    /// Register the full set with ``UNUserNotificationCenter``. Call once
    /// during app launch, before any notifications are scheduled.
    static func registerAll() {
        UNUserNotificationCenter.current().setNotificationCategories(Set(all))
    }

    private static var hydrationReminder: UNNotificationCategory {
        let log250 = UNNotificationAction(
            identifier: NotificationActionID.log250ml.rawValue,
            title: "Log 250 ml",
            options: []
        )
        let log500 = UNNotificationAction(
            identifier: NotificationActionID.log500ml.rawValue,
            title: "Log 500 ml",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: NotificationActionID.snooze1h.rawValue,
            title: "Snooze 1 hr",
            options: []
        )
        return UNNotificationCategory(
            identifier: NotificationCategoryID.hydrationReminder.rawValue,
            actions: [log250, log500, snooze],
            intentIdentifiers: [],
            options: []
        )
    }
}
