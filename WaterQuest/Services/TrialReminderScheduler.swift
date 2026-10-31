import Foundation
@preconcurrency import UserNotifications

/// The slice of the notification centre the trial reminder needs. A
/// protocol so tests can swap in a fake.
@MainActor
protocol TrialNotificationCentering: AnyObject {
    func reminderAvailability() async -> TrialReminderAvailability
    /// Requests quiet, prompt-free delivery to Notification Center.
    func requestProvisionalAuthorization() async -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
}

@MainActor
protocol TrialReminderScheduling {
    func reminderAvailability() async -> TrialReminderAvailability
    /// Returns `true` when a reminder was scheduled.
    @discardableResult
    func scheduleReminder(at date: Date, trialEnd: Date) async -> Bool
}

/// Schedules the one-off "your trial ends soon" notification promised on
/// the paywall timeline. Uses its own identifier so the smart hydration
/// reminder teardown never removes it.
@MainActor
final class TrialReminderScheduler: TrialReminderScheduling {
    static let identifier = "sipli.trial.ending"

    private let center: TrialNotificationCentering
    private let now: () -> Date
    private let calendar: Calendar

    init(
        center: TrialNotificationCentering = SystemTrialNotificationCenter(),
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.center = center
        self.now = now
        self.calendar = calendar
    }

    func reminderAvailability() async -> TrialReminderAvailability {
        await center.reminderAvailability()
    }

    @discardableResult
    func scheduleReminder(at date: Date, trialEnd: Date) async -> Bool {
        guard date > now() else { return false }

        switch await center.reminderAvailability() {
        case .denied:
            return false
        case .notDetermined:
            guard await center.requestProvisionalAuthorization() else { return false }
        case .authorized, .provisional:
            break
        }

        center.removePendingRequests(withIdentifiers: [Self.identifier])

        let days = max(1, calendar.dateComponents([.day], from: date, to: trialEnd).day ?? 1)
        let content = UNMutableNotificationContent()
        content.title = days == 1
            ? "Your Sipli trial ends tomorrow"
            : "Your Sipli trial ends in \(days) days"
        content.body = "Keep your adaptive goals and insights, or cancel anytime in Settings > Apple ID > Subscriptions."
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}

/// Real notification centre adapter.
@MainActor
final class SystemTrialNotificationCenter: TrialNotificationCentering {
    nonisolated init() {}

    private var center: UNUserNotificationCenter { .current() }

    func reminderAvailability() async -> TrialReminderAvailability {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .ephemeral: return .authorized
        case .provisional: return .provisional
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        @unknown default: return .denied
        }
    }

    func requestProvisionalAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .provisional])) ?? false
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
