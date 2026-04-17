import Foundation
import UserNotifications
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Logical slot for a reminder message. Slots decouple copy selection from
/// raw progress thresholds so later phases (celebration, workout, comeback)
/// can add new tiers without reshaping the API.
enum MessageSlot: Equatable {
    case first       // early in the day or low progress
    case mid         // midday or mid progress
    case late        // late day or high progress
    case escalation  // streak at risk (Phase 4 wires this to time-sensitive)
    // Phase 2: case celebration
    // Phase 3: case workout, case comeback
}

/// Intelligent notification scheduler that adapts to user activity.
///
/// **Smart mode** (default):
///   - Pre-schedules reminders as local notifications so they fire even
///     when the app is backgrounded or suspended by iOS.
///   - Skips scheduling when the daily goal is already met.
///   - Reschedules whenever a new intake is logged or the app returns
///     to the foreground, keeping reminders aligned with real activity.
///   - On Apple Intelligence devices, generates unique motivational copy via
///     FoundationModels when the app is foregrounded; falls back to curated
///     messages for background-scheduled notifications.
///
/// **Classic mode** (smartRemindersEnabled = false):
///   - Behaves like the original fixed-schedule reminders.
@MainActor
final class NotificationScheduler: ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Configuration
    /// Minimum seconds between any two delivered notifications.
    private let minimumGapSeconds: Double = 1800 // 30 min

    /// How many seconds of silence before we consider the user "quiet".
    private let quietThresholdMultiplier: Double = 2.0
    private let smartIdentifierPrefix = "sipli.smart."

    // MARK: - Internal state
    /// Snapshot of entries used for the current scheduling pass.
    private var lastKnownEntries: [DateEntry] = []
    /// Whether we already fired an escalated nudge since the last log.
    private var didFireEscalation = false
    /// Reserved: Phase 2+ will read this when escalation state needs to
    /// survive across scheduling passes. Currently assigned but unread.
    private var currentContext: NotificationContext?
    /// Monotonic batch identifier so smart request IDs are never reused.
    private var smartBatchID: Int = 0

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            authorizationStatus = .denied
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Public scheduling entry-point

    /// Call this whenever the profile, entries, or app lifecycle change.
    /// Tears down previous notifications and schedules fresh ones.
    func scheduleReminders(context: NotificationContext) {
        // Clear only scheduler-owned pending requests. `sipli.snooze.*` and
        // other out-of-band notifications (e.g. future workout anchors in
        // Phase 3) survive this call.
        // removeAllDeliveredNotifications() is also deliberately NOT called —
        // wiping the user's Notification Center on every foreground destroys
        // their history. Task 11 drops that stale call entirely.
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let schedulerIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("sipli.smart.") || $0.hasPrefix("sipli.classic.") }
            if !schedulerIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: schedulerIDs)
            }
        }

        currentContext = context
        lastKnownEntries = context.entries.map { DateEntry(date: $0.date, volumeML: $0.effectiveML) }
        didFireEscalation = false

        guard context.profile.remindersEnabled else { return }

        if context.profile.smartRemindersEnabled {
            scheduleSmartReminders(context: context)
        } else {
            scheduleClassicReminders(context: context)
        }
    }

    /// Call this when a new intake is logged so smart reminders reschedule
    /// around the latest activity.
    func onIntakeLogged(entry: HydrationEntry, context: NotificationContext) {
        lastKnownEntries.append(DateEntry(date: entry.date, volumeML: entry.effectiveML))
        didFireEscalation = false
        currentContext = context

        guard context.profile.remindersEnabled, context.profile.smartRemindersEnabled else { return }
        clearPendingSmartReminders {
            self.scheduleSmartReminders(context: context)
        }
    }

    // MARK: - Smart reminders (pre-scheduled via UNNotification triggers)

    /// Schedules multiple upcoming notifications until sleep time so they
    /// fire even when the app is suspended by iOS.  Re-evaluated each time
    /// the app foregrounds, entries change, or settings change.
    private func scheduleSmartReminders(context: NotificationContext) {
        let profile = context.profile
        let goalML = context.goalML
        let now = Date()
        let intervalSeconds = computeInterval(profile: profile)
        let calendar = Calendar.current
        smartBatchID += 1
        let batchID = smartBatchID

        let currentMinutes = calendar.component(.hour, from: now) * 60
            + calendar.component(.minute, from: now)

        // Past sleep time — nothing to schedule today.
        guard currentMinutes < profile.sleepMinutes else { return }

        // Goal already met — no reminders needed.
        let todayTotal = lastKnownEntries
            .filter { $0.date.isSameDay(as: now) }
            .reduce(0.0) { $0 + $1.volumeML }
        guard todayTotal < goalML else { return }

        // Determine next fire time based on most recent intake.
        let mostRecentEntry = lastKnownEntries
            .filter { $0.date.isSameDay(as: now) }
            .max(by: { $0.date < $1.date })

        var nextFireDate: Date
        if let recent = mostRecentEntry {
            nextFireDate = recent.date.addingTimeInterval(intervalSeconds)
        } else {
            // No entries today — fire one interval after wake time.
            let wakeDate = calendar.date(bySettingHour: profile.wakeMinutes / 60,
                                          minute: profile.wakeMinutes % 60,
                                          second: 0, of: now) ?? now
            nextFireDate = wakeDate.addingTimeInterval(intervalSeconds)
        }

        // If overdue, fire soon.
        if nextFireDate <= now {
            nextFireDate = now.addingTimeInterval(60)
        }

        // End of awake window today.
        guard let sleepDate = calendar.date(bySettingHour: profile.sleepMinutes / 60,
                                             minute: profile.sleepMinutes % 60,
                                             second: 0, of: now) else { return }

        // Pre-schedule reminders until sleep time (capped at 20).
        var index = 0
        var fireDate = nextFireDate

        while fireDate < sleepDate && index < 20 {
            let delay = fireDate.timeIntervalSince(now)
            guard delay >= 1 else {
                fireDate = fireDate.addingTimeInterval(intervalSeconds)
                continue
            }

            let slot = slotFor(context: context)
            let body = messageFor(context: context, slot: slot)

            let content = UNMutableNotificationContent()
            content.title = "Sipli"
            content.body = body
            content.sound = .default
            content.categoryIdentifier = NotificationCategoryID.hydrationReminder.rawValue

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(identifier: "\(smartIdentifierPrefix)\(batchID).\(index)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)

            fireDate = fireDate.addingTimeInterval(intervalSeconds)
            index += 1
        }
    }

    /// Base interval between reminders, auto-calculated from awake hours.
    /// Targets ~8 reminders per day, clamped to 60–150 minutes.
    private func computeInterval(profile: UserProfile) -> Double {
        let awakeMinutes = max(60, profile.sleepMinutes - profile.wakeMinutes)
        let intervalMinutes = Double(awakeMinutes) / 8.0
        let clamped = min(max(intervalMinutes, 60), 150) // 1hr floor, 2.5hr ceiling
        return clamped * 60.0 // convert to seconds
    }

    // MARK: - FoundationModels AI generation (Apple Intelligence devices only)

    private func generateAIMessage(progress: Double, todayTotalML: Double, goalML: Double, isEscalation: Bool) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await _generateAIMessageWithFoundationModels(progress: progress, todayTotalML: todayTotalML, goalML: goalML, isEscalation: isEscalation)
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func _generateAIMessageWithFoundationModels(progress: Double, todayTotalML: Double, goalML: Double, isEscalation: Bool) async -> String? {
        guard SystemLanguageModel.default.isAvailable else { return nil }

        let percentText = String(format: "%.0f", progress * 100)
        let escalationHint = isEscalation
            ? " The user has been inactive for a while, so gently encourage them to drink."
            : ""

        let prompt = """
            Generate a single short (max 12 words), friendly, motivational hydration reminder.
            The user has completed \(percentText)% of their daily water goal (\(Int(todayTotalML)) of \(Int(goalML)) ml).\(escalationHint)
            Reply with ONLY the reminder text. No quotes, no punctuation beyond one exclamation mark.
            """

        let session = LanguageModelSession(instructions: """
            You are a cheerful hydration coach inside a mobile app called Sipli.
            You write short, warm, motivational nudges to help people drink more water.
            Keep every response under 12 words. Be encouraging, never guilt-tripping.
            """)

        do {
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
    #endif

    // MARK: - Message selection

    /// Entry point used by both smart and classic scheduling paths. Picks a
    /// curated message appropriate for the slot; the AI wire-up (see
    /// `scheduleAIReplacement(...)`) can later swap the first-fire notification
    /// for a generated message.
    func messageFor(context: NotificationContext, slot: MessageSlot) -> String {
        switch slot {
        case .first:
            return earlyMessages.randomElement() ?? "Start your day right — grab some water!"
        case .mid:
            return midMessages.randomElement() ?? "Keep the momentum going — sip up!"
        case .late:
            return lateMessages.randomElement() ?? "Almost there — a few more sips!"
        case .escalation:
            return escalationMessages.randomElement() ?? "It's been a while — time for a sip!"
        }
    }

    /// Convenience: picks a slot from raw progress when the caller doesn't
    /// have a specific one in mind (e.g. an ordinary smart reminder).
    func slotFor(context: NotificationContext) -> MessageSlot {
        let p = context.progress
        if p < 0.25 { return .first }
        if p < 0.6  { return .mid }
        return .late
    }

    private let escalationMessages = [
        "It's been a while — time for a sip!",
        "Your body's been waiting. Water up!",
        "A quiet stretch calls for a quiet sip.",
        "One glass can make a difference — give it a go!",
        "Check in with yourself: when did you last drink?"
    ]

    private let earlyMessages = [
        "Morning hydration kickstarts your day.",
        "Start fresh — a glass of water is all it takes.",
        "Your body woke up thirsty. Help it out!",
        "First sip of the day — let's go!"
    ]

    private let midMessages = [
        "Midday check-in: how's your water intake?",
        "A quick sip keeps the energy flowing.",
        "Halfway there — keep sipping!",
        "Take a water break and claim some XP."
    ]

    private let lateMessages = [
        "Almost at your goal — one more glass!",
        "The finish line is close. Sip it home!",
        "You're doing great — just a bit more.",
        "You're so close — finish strong!"
    ]

    // MARK: - Classic (fixed-schedule) reminders

    private func scheduleClassicReminders(context: NotificationContext) {
        let profile = context.profile
        let awakeMinutes = max(60, profile.sleepMinutes - profile.wakeMinutes)
        let count = max(1, min(12, Int(round(Double(awakeMinutes) / min(max(Double(awakeMinutes) / 8.0, 60), 150)))))
        let times = classicReminderTimes(wakeMinutes: profile.wakeMinutes, sleepMinutes: profile.sleepMinutes, count: count)
        for (index, minutes) in times.enumerated() {
            var dateComponents = DateComponents()
            dateComponents.hour = minutes / 60
            dateComponents.minute = minutes % 60

            let slot = classicSlot(forMinutes: minutes, context: context)

            let content = UNMutableNotificationContent()
            content.title = "Sipli"
            content.body = messageFor(context: context, slot: slot)
            content.sound = .default
            content.categoryIdentifier = NotificationCategoryID.hydrationReminder.rawValue

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "sipli.classic.\(index)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func classicReminderTimes(wakeMinutes: Int, sleepMinutes: Int, count: Int) -> [Int] {
        let adjustedCount = max(1, min(12, count))
        let span = max(1, sleepMinutes - wakeMinutes)
        let gap = span / adjustedCount
        return (0..<adjustedCount).map { wakeMinutes + $0 * gap }
    }

    /// Maps a classic reminder's schedule time to a slot. Classic mode
    /// reminders repeat daily so progress isn't known at schedule time;
    /// time-of-day is the only signal.
    private func classicSlot(forMinutes minutes: Int, context: NotificationContext) -> MessageSlot {
        let wake = context.profile.wakeMinutes
        let sleep = context.profile.sleepMinutes
        let awakeMinutes = max(1, sleep - wake)
        let relative = Double(minutes - wake) / Double(awakeMinutes)
        if relative < 0.33 { return .first }
        if relative < 0.66 { return .mid }
        return .late
    }

    private func clearPendingSmartReminders(completion: @escaping @MainActor () -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [smartIdentifierPrefix] requests in
            let smartIds = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(smartIdentifierPrefix) }

            if !smartIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: smartIds)
            }

            Task { @MainActor in
                completion()
            }
        }
    }
}

// MARK: - Lightweight internal entry (avoids pulling in the full model)
private struct DateEntry {
    let date: Date
    let volumeML: Double
}
