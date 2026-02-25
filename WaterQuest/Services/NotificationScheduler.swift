import Foundation
import UserNotifications
#if canImport(FoundationModels)
import FoundationModels
#endif

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

    // MARK: - Internal state
    /// Snapshot of entries used for the current scheduling pass.
    private var lastKnownEntries: [DateEntry] = []
    /// Whether we already fired an escalated nudge since the last log.
    private var didFireEscalation = false
    /// Stored profile for rescheduling from `onIntakeLogged`.
    private var currentProfile: UserProfile?
    /// Stored goal for rescheduling from `onIntakeLogged`.
    private var currentGoalML: Double = 2000

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
    func scheduleReminders(profile: UserProfile, entries: [HydrationEntry] = [], goalML: Double = 2000) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        currentProfile = profile
        currentGoalML = goalML
        lastKnownEntries = entries.map { DateEntry(date: $0.date, volumeML: $0.effectiveML) }
        didFireEscalation = false

        guard profile.remindersEnabled else { return }

        if profile.smartRemindersEnabled {
            scheduleSmartReminders(profile: profile, goalML: goalML)
        } else {
            scheduleClassicReminders(profile: profile)
        }
    }

    /// Call this when a new intake is logged so smart reminders reschedule
    /// around the latest activity.
    func onIntakeLogged(entry: HydrationEntry) {
        lastKnownEntries.append(DateEntry(date: entry.date, volumeML: entry.effectiveML))
        didFireEscalation = false

        guard let profile = currentProfile, profile.remindersEnabled, profile.smartRemindersEnabled else { return }
        // Cancel pending smart notifications and reschedule based on new state.
        let smartIds = (0..<20).map { "sipli.smart.\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: smartIds)
        scheduleSmartReminders(profile: profile, goalML: currentGoalML)
    }

    // MARK: - Smart reminders (pre-scheduled via UNNotification triggers)

    /// Schedules multiple upcoming notifications until sleep time so they
    /// fire even when the app is suspended by iOS.  Re-evaluated each time
    /// the app foregrounds, entries change, or settings change.
    private func scheduleSmartReminders(profile: UserProfile, goalML: Double) {
        let now = Date()
        let intervalSeconds = computeInterval(profile: profile)
        let calendar = Calendar.current

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
        let progress = goalML > 0 ? todayTotal / goalML : 0
        var index = 0
        var fireDate = nextFireDate

        while fireDate < sleepDate && index < 20 {
            let delay = fireDate.timeIntervalSince(now)
            guard delay >= 1 else {
                fireDate = fireDate.addingTimeInterval(intervalSeconds)
                continue
            }

            let body = curatedMessage(progress: progress, isEscalation: false)

            let content = UNMutableNotificationContent()
            content.title = "Sipli"
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(identifier: "sipli.smart.\(index)", content: content, trigger: trigger)
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

    // MARK: - Message generation

    private func generateMessage(progress: Double, todayTotalML: Double, goalML: Double, isEscalation: Bool) async -> String {
        // Try on-device AI first; fall back to curated pool.
        if let aiMessage = await generateAIMessage(progress: progress, todayTotalML: todayTotalML, goalML: goalML, isEscalation: isEscalation) {
            return aiMessage
        }
        return curatedMessage(progress: progress, isEscalation: isEscalation)
    }

    // MARK: - FoundationModels AI generation (Apple Intelligence devices only)

    private func generateAIMessage(progress: Double, todayTotalML: Double, goalML: Double, isEscalation: Bool) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
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
        return nil
    }

    // MARK: - Curated fallback messages

    private func curatedMessage(progress: Double, isEscalation: Bool) -> String {
        if isEscalation {
            return escalationMessages.randomElement() ?? "It's been a while — time for a sip!"
        }
        if progress < 0.25 {
            return earlyMessages.randomElement() ?? "Start your day right — grab some water!"
        }
        if progress < 0.6 {
            return midMessages.randomElement() ?? "Keep the momentum going — sip up!"
        }
        return lateMessages.randomElement() ?? "Almost there — a few more sips!"
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

    private func scheduleClassicReminders(profile: UserProfile) {
        let awakeMinutes = max(60, profile.sleepMinutes - profile.wakeMinutes)
        let count = max(1, min(12, Int(round(Double(awakeMinutes) / min(max(Double(awakeMinutes) / 8.0, 60), 150)))))
        let times = classicReminderTimes(wakeMinutes: profile.wakeMinutes, sleepMinutes: profile.sleepMinutes, count: count)
        let staticMessages = [
            "Sip time! Your future self is cheering.",
            "Take a water break — you deserve it.",
            "Quick check-in: a few sips goes far.",
            "A little hydration goes a long way.",
            "Tiny sip, big win. Let's go!"
        ]

        for (index, minutes) in times.enumerated() {
            var dateComponents = DateComponents()
            dateComponents.hour = minutes / 60
            dateComponents.minute = minutes % 60

            let content = UNMutableNotificationContent()
            content.title = "Sipli"
            content.body = staticMessages[index % staticMessages.count]
            content.sound = .default

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
}

// MARK: - Lightweight internal entry (avoids pulling in the full model)
private struct DateEntry {
    let date: Date
    let volumeML: Double
}
