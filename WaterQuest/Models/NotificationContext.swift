import Foundation

/// Immutable snapshot of the state a notification-scheduling pass needs.
///
/// Callers (`HydrationStore`, `WaterQuestApp`, `SettingsView`) assemble a
/// context and hand it to ``NotificationScheduler``. The scheduler stays
/// pure — given the same context it produces the same schedule — which
/// keeps it easy to reason about and easy to test.
///
/// Phase 1 fields only. Phase 2 adds `weather` and `recentWorkout`; later
/// phases add `reminderAnchors`, `lastLogAt`, and `logTimeHistogram`.
struct NotificationContext {
    let profile: UserProfile
    let entries: [HydrationEntry]
    let goalML: Double
    let currentStreak: Int
    let hasPremiumAccess: Bool

    /// Effective ml logged today (sum of ``HydrationEntry/effectiveML``).
    var todayTotalML: Double {
        let now = Date()
        return entries
            .filter { $0.date.isSameDay(as: now) }
            .reduce(0) { $0 + $1.effectiveML }
    }

    /// Today's progress ratio, clamped to `[0, 1]`. Returns `0` when the
    /// goal is zero or negative.
    var progress: Double {
        guard goalML > 0 else { return 0 }
        return min(1, todayTotalML / goalML)
    }
}
