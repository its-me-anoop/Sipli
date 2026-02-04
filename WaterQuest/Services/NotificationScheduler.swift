import Foundation
import UserNotifications
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Intelligent notification scheduler that adapts to user activity.
///
/// **Smart mode** (default):
///   - Skips a reminder when the user logged water within the current interval.
///   - Skips reminders once the daily goal is met.
///   - Escalates the wait (up to 2× the normal interval) when the user has been
///     quiet, then fires a single gentle nudge — never more than one escalated
///     notification in a row.
///   - On Apple Intelligence devices, generates unique motivational copy via
///     FoundationModels; falls back to curated messages otherwise.
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

    // MARK: - Internal state (not persisted; rebuilt on each schedule call)
    /// Snapshot of entries used for the current scheduling pass.
    private var lastKnownEntries: [DateEntry] = []
    /// Whether we already fired an escalated nudge since the last log.
    private var didFireEscalation = false
    /// The active background polling task.
    private var pollingTask: Task<Void, Never>?

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

    /// Call this whenever the profile or entries change.  It tears down any
    /// previous classic notifications and (re-)starts the smart loop if needed.
    func scheduleReminders(profile: UserProfile, entries: [HydrationEntry] = [], goalML: Double = 2000) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        pollingTask?.cancel()
        pollingTask = nil

        guard profile.remindersEnabled else { return }

        if profile.smartRemindersEnabled {
            // Snapshot lightweight date+volume pairs for the polling loop.
            lastKnownEntries = entries.map { DateEntry(date: $0.date, volumeML: $0.volumeML) }
            didFireEscalation = false
            startSmartLoop(profile: profile, goalML: goalML)
        } else {
            scheduleClassicReminders(profile: profile)
        }
    }

    /// Call this when a new intake is logged so the smart loop can react
    /// immediately (cancel any pending escalation, reset state).
    func onIntakeLogged(entry: HydrationEntry) {
        lastKnownEntries.append(DateEntry(date: entry.date, volumeML: entry.volumeML))
        didFireEscalation = false
        // Remove any pending smart notification that hasn't fired yet.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["waterquest.smart"])
    }

    // MARK: - Smart reminder loop

    private func startSmartLoop(profile: UserProfile, goalML: Double) {
        let intervalSeconds = computeInterval(profile: profile)
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.evaluateAndMaybeNotify(profile: profile, goalML: goalML, intervalSeconds: intervalSeconds)
                // Sleep until the next evaluation window.
                do {
                    try await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                } catch {
                    break // Task was cancelled
                }
            }
        }
    }

    private func evaluateAndMaybeNotify(profile: UserProfile, goalML: Double, intervalSeconds: Double) async {
        let now = Date()

        // --- Outside the awake window? Do nothing. ---
        let currentMinutes = Calendar.current.component(.hour, from: now) * 60
            + Calendar.current.component(.minute, from: now)
        guard currentMinutes >= profile.wakeMinutes && currentMinutes < profile.sleepMinutes else { return }

        // --- Goal already met today? Skip. ---
        let todayTotal = lastKnownEntries
            .filter { $0.date.isSameDay(as: now) }
            .reduce(0.0) { $0 + $1.volumeML }
        guard todayTotal < goalML else { return }

        // --- Logged water recently (within one interval)? Skip. ---
        let mostRecentEntry = lastKnownEntries
            .filter { $0.date.isSameDay(as: now) }
            .max(by: { $0.date < $1.date })
        if let recent = mostRecentEntry {
            let elapsed = now.timeIntervalSince(recent.date)
            if elapsed < intervalSeconds { return }
        }

        // --- Determine whether this is a gentle nudge or an escalation nudge. ---
        let isQuiet: Bool
        if let recent = mostRecentEntry {
            isQuiet = now.timeIntervalSince(recent.date) >= intervalSeconds * quietThresholdMultiplier
        } else {
            // No entries at all today — first-of-day nudge, not an escalation.
            isQuiet = false
        }

        // If quiet but we already fired one escalation, wait longer — skip this cycle.
        if isQuiet && didFireEscalation { return }

        // --- Build and deliver the notification. ---
        let progress = goalML > 0 ? todayTotal / goalML : 0
        let body = await generateMessage(progress: progress, todayTotalML: todayTotal, goalML: goalML, isEscalation: isQuiet)

        let content = UNMutableNotificationContent()
        content.title = "Hydration Quest"
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "waterquest.smart", content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Notification could not be scheduled; nothing to recover.
        }

        if isQuiet { didFireEscalation = true }
    }

    /// Base interval between reminders, derived from wake/sleep span and count.
    private func computeInterval(profile: UserProfile) -> Double {
        let span = max(60, profile.sleepMinutes - profile.wakeMinutes) // minutes
        let count = max(1, min(12, profile.dailyReminderCount))
        return Double(span / count) * 60.0 // convert to seconds
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
                You are a cheerful hydration coach inside a mobile app called WaterQuest.
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
        "Don't forget your streak — one glass does it.",
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
        "Hydrate to keep your streak alive."
    ]

    // MARK: - Classic (fixed-schedule) reminders

    private func scheduleClassicReminders(profile: UserProfile) {
        let times = classicReminderTimes(wakeMinutes: profile.wakeMinutes, sleepMinutes: profile.sleepMinutes, count: profile.dailyReminderCount)
        let staticMessages = [
            "Sip time! Your future self is cheering.",
            "Take a water break and claim some XP.",
            "Quest check-in: a few sips goes far.",
            "Hydrate to keep your streak alive.",
            "Tiny sip, big win. Let's go!"
        ]

        for (index, minutes) in times.enumerated() {
            var dateComponents = DateComponents()
            dateComponents.hour = minutes / 60
            dateComponents.minute = minutes % 60

            let content = UNMutableNotificationContent()
            content.title = "Hydration Quest"
            content.body = staticMessages[index % staticMessages.count]
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "waterquest.classic.\(index)", content: content, trigger: trigger)
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


