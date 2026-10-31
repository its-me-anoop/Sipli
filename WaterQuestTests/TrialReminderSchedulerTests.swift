import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import Sipli

/// In-memory stand-in for the notification centre so scheduling can be
/// checked without touching the device's real notifications.
@MainActor
final class FakeTrialNotificationCenter: TrialNotificationCentering {
    var availability: TrialReminderAvailability
    var grantsProvisional: Bool
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []
    private(set) var provisionalRequests = 0

    init(availability: TrialReminderAvailability, grantsProvisional: Bool = true) {
        self.availability = availability
        self.grantsProvisional = grantsProvisional
    }

    func reminderAvailability() async -> TrialReminderAvailability { availability }

    func requestProvisionalAuthorization() async -> Bool {
        provisionalRequests += 1
        if grantsProvisional { availability = .provisional }
        return grantsProvisional
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }
}

@MainActor
@Suite("TrialReminderScheduler", .tags(.subscription))
struct TrialReminderSchedulerTests {

    private let now = Date(timeIntervalSince1970: 1_793_000_000)
    private var reminder: Date { now.addingTimeInterval(28 * 86_400) }
    private var trialEnd: Date { now.addingTimeInterval(30 * 86_400) }

    @Test("Schedules one reminder at the reminder date")
    func schedulesReminder() async {
        let center = FakeTrialNotificationCenter(availability: .authorized)
        let scheduler = TrialReminderScheduler(center: center, now: { now })

        let scheduled = await scheduler.scheduleReminder(at: reminder, trialEnd: trialEnd)

        #expect(scheduled)
        #expect(center.addedRequests.count == 1)
        let request = center.addedRequests.first
        #expect(request?.identifier == TrialReminderScheduler.identifier)
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.repeats == false)
        #expect(trigger?.nextTriggerDate().map { abs($0.timeIntervalSince(reminder)) < 1 } == true)
    }

    @Test("Replaces any earlier trial reminder instead of stacking them")
    func replacesEarlierReminder() async {
        let center = FakeTrialNotificationCenter(availability: .authorized)
        let scheduler = TrialReminderScheduler(center: center, now: { now })

        _ = await scheduler.scheduleReminder(at: reminder, trialEnd: trialEnd)

        #expect(center.removedIdentifiers == [TrialReminderScheduler.identifier])
    }

    @Test("Asks quietly for provisional permission when the user hasn't decided")
    func requestsProvisionalWhenUndetermined() async {
        let center = FakeTrialNotificationCenter(availability: .notDetermined)
        let scheduler = TrialReminderScheduler(center: center, now: { now })

        let scheduled = await scheduler.scheduleReminder(at: reminder, trialEnd: trialEnd)

        #expect(center.provisionalRequests == 1)
        #expect(scheduled)
    }

    @Test("Does nothing when notifications are denied")
    func skipsWhenDenied() async {
        let center = FakeTrialNotificationCenter(availability: .denied)
        let scheduler = TrialReminderScheduler(center: center, now: { now })

        let scheduled = await scheduler.scheduleReminder(at: reminder, trialEnd: trialEnd)

        #expect(!scheduled)
        #expect(center.addedRequests.isEmpty)
    }

    @Test("Never schedules a reminder in the past")
    func skipsPastDate() async {
        let center = FakeTrialNotificationCenter(availability: .authorized)
        let scheduler = TrialReminderScheduler(center: center, now: { now })

        let scheduled = await scheduler.scheduleReminder(
            at: now.addingTimeInterval(-60),
            trialEnd: trialEnd
        )

        #expect(!scheduled)
        #expect(center.addedRequests.isEmpty)
    }

    @Test("The reminder says when the trial ends and how to manage it")
    func reminderCopy() async {
        let center = FakeTrialNotificationCenter(availability: .authorized)
        let scheduler = TrialReminderScheduler(center: center, now: { now })

        _ = await scheduler.scheduleReminder(at: reminder, trialEnd: trialEnd)

        let content = center.addedRequests.first?.content
        #expect(content?.title == "Your Sipli trial ends in 2 days")
        #expect(content?.body.contains("Settings") == true)
    }
}
