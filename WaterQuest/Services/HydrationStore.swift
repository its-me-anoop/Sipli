import Foundation
import WidgetKit

@MainActor
final class HydrationStore: ObservableObject {
    @Published var entries: [HydrationEntry]
    @Published var profile: UserProfile
    @Published var lastWeather: WeatherSnapshot?
    @Published var lastWorkout: WorkoutSummary
    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var premiumUpsellState: PremiumUpsellState
    /// Lifetime count of days the user has hit their daily hydration goal.
    /// Observed by DashboardView to decide when to prompt for an App Store review.
    @Published private(set) var goalCompletionCount: Int
    /// Start-of-day of the most recent day the user hit their goal.
    /// Used by ``checkGoalCompletion()`` to avoid double-counting same-day crossings.
    @Published private(set) var lastGoalCompletionDate: Date?
    /// Match Day (football-summer challenge): match days won this season.
    @Published private(set) var matchDayWins: Int
    /// Start-of-day of the most recent match-day win (same-day dedupe).
    @Published private(set) var lastMatchDayWinDate: Date?
    /// Banked streak-freeze tokens.
    @Published private(set) var streakFreezeTokens: Int
    /// Days retroactively covered by a spent freeze token.
    @Published private(set) var streakFreezeDates: [Date]

    private let persistence = PersistenceService.shared

    /// Set by the app after both objects are created so the store can notify
    /// the scheduler when new intake is logged.
    weak var notificationScheduler: NotificationScheduler?

    init() {
        let state = persistence.load(PersistedState.self, fallback: .default)
        self.entries = state.entries
        self.profile = state.profile
        self.lastWeather = state.lastWeather
        self.lastWorkout = state.lastWorkout
        self.hasPremiumAccess = state.hasPremiumAccess
        self.premiumUpsellState = state.premiumUpsellState
        self.goalCompletionCount = state.goalCompletionCount
        self.lastGoalCompletionDate = state.lastGoalCompletionDate
        self.matchDayWins = state.matchDayWins
        self.lastMatchDayWinDate = state.lastMatchDayWinDate
        self.streakFreezeTokens = state.streakFreezeTokens
        self.streakFreezeDates = state.streakFreezeDates

        persistence.setRemoteDataChangeHandler { [weak self] data in
            guard let self else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let remoteState = try? decoder.decode(PersistedState.self, from: data) else { return }

            Task { @MainActor in
                self.applyRemoteState(remoteState)
            }
        }

        PhoneSessionManager.shared.store = self
        PhoneSessionManager.shared.activate()

        // One-time backfill for users who were on a pre-3.x build (where the
        // counter didn't exist). Credits them for historical goal-hitting days
        // so the review prompt fires when they next open the app, not only
        // after three future completions.
        backfillGoalCompletionCountIfNeeded()

        // Spend a banked freeze if yesterday broke an otherwise-live streak.
        applyStreakFreezeIfNeeded()
    }

    var dailyGoal: GoalBreakdown {
        let profile = effectiveProfile
        let workout = profile.prefersHealthKit ? lastWorkout : nil
        return GoalCalculator.dailyGoal(profile: profile, weather: activeWeather, workout: workout)
    }

    var activeWeather: WeatherSnapshot? {
        effectiveProfile.prefersWeatherGoal ? lastWeather : nil
    }

    var effectiveProfile: UserProfile {
        profile.applyingPremiumAccess(hasPremiumAccess)
    }

    var todayEntries: [HydrationEntry] {
        entries.filter { $0.date.isSameDay(as: Date()) }
    }

    var todayTotalML: Double {
        todayEntries.reduce(0) { $0 + $1.effectiveML }
    }

    /// Raw total without hydration factor adjustment (for display/HealthKit).
    var todayRawTotalML: Double {
        todayEntries.reduce(0) { $0 + $1.volumeML }
    }

    /// Fluid types ordered by lifetime log count, most-used first. Used by the
    /// intake picker so frequent drinks surface without scrolling.
    var rankedFluidTypes: [FluidType] {
        FluidType.ranked(from: entries)
    }

    var todayCompositions: [FluidComposition] {
        let total = max(1, todayTotalML) // Avoid division by zero
        var grouped: [FluidType: Double] = [:]

        for entry in todayEntries {
            grouped[entry.fluidType, default: 0] += entry.effectiveML
        }

        // Convert to proportions and sort by volume descending
        return grouped
            .map { FluidComposition(type: $0.key, proportion: $0.value / total) }
            .sorted { $0.proportion > $1.proportion }
    }

    /// Assemble an immutable snapshot of everything the notification scheduler
    /// needs. Called from every site that reschedules reminders.
    func buildNotificationContext() -> NotificationContext {
        NotificationContext(
            profile: effectiveProfile,
            entries: entries,
            goalML: dailyGoal.totalML,
            currentStreak: currentStreak,
            hasPremiumAccess: hasPremiumAccess,
            capturedAt: Date()
        )
    }

    /// Freeze-aware goal streak, shared with Insights and the widget via
    /// ``StreakCalculator``.
    var currentStreak: Int {
        StreakCalculator.currentStreak(
            entries: entries,
            goalML: dailyGoal.totalML,
            freezeDates: streakFreezeDates
        )
    }

    @discardableResult
    func addIntake(amount: Double, unitSystem: UnitSystem? = nil, source: HydrationSource = .manual, fluidType: FluidType = .water, note: String? = nil) -> HydrationEntry {
        let units = unitSystem ?? profile.unitSystem
        let ml = units.ml(from: amount)
        let entry = HydrationEntry(date: Date(), volumeML: ml, source: source, fluidType: fluidType, note: note)
        entries.append(entry)
        notificationScheduler?.onIntakeLogged(entry: entry, context: buildNotificationContext())
        checkGoalCompletion()
        persist()
        IntentDonationService.donateLogWater(amount: entry.volumeML, fluidType: entry.fluidType)
        return entry
    }

    /// Increments ``goalCompletionCount`` the first time today's total crosses
    /// the daily goal on a given day. Monotonic — never decrements if the user
    /// later deletes entries.
    ///
    /// Apple's review-request API handles its own throttling (max 3 prompts
    /// per user per year), so we count every qualifying day and let iOS decide
    /// whether to show the modal.
    private func checkGoalCompletion() {
        let goalML = dailyGoal.totalML
        guard goalML > 0, todayTotalML >= goalML else { return }

        let today = Calendar.current.startOfDay(for: Date())
        registerMatchDayWinIfNeeded(today: today)

        if let last = lastGoalCompletionDate,
           Calendar.current.isDate(last, inSameDayAs: today) {
            return // already counted today
        }

        goalCompletionCount += 1
        lastGoalCompletionDate = today

        // Every 7th consecutive goal day banks a streak freeze (capped).
        let streak = currentStreak
        if streak > 0, streak % StreakCalculator.freezeEarnInterval == 0 {
            streakFreezeTokens = min(StreakCalculator.maxFreezeTokens, streakFreezeTokens + 1)
        }
    }

    /// Match Day: hitting the daily goal during the football-summer window
    /// wins the day's match. Deduped per day; monotonic like the review counter.
    private func registerMatchDayWinIfNeeded(today: Date) {
        guard MatchDay.isActive() else { return }
        if let last = lastMatchDayWinDate,
           Calendar.current.isDate(last, inSameDayAs: today) {
            return
        }
        matchDayWins += 1
        lastMatchDayWinDate = today
    }

    /// Spends one banked freeze token to cover yesterday when it broke an
    /// otherwise-live streak. Deterministic and idempotent — the consumed day
    /// is recorded in ``streakFreezeDates`` so every process (widget, watch)
    /// computes the same streak from persisted state.
    private func applyStreakFreezeIfNeeded() {
        guard let day = StreakCalculator.freezeConsumableDate(
            entries: entries,
            goalML: dailyGoal.totalML,
            freezeDates: streakFreezeDates,
            tokens: streakFreezeTokens
        ) else { return }

        streakFreezeTokens -= 1
        streakFreezeDates.append(day)
        persist()
    }

    /// One-time backfill for users upgrading from a build that predates the
    /// goal-completion counter. Scans historical entries and approximates the
    /// number of days the user hit their goal by comparing each day's total
    /// against the *current* daily goal.
    ///
    /// This is an approximation — historical weather/workout adjustments are
    /// not reconstructed, so if the user's current goal is higher than past
    /// goals were, this slightly under-counts. Conservative is fine: we want
    /// the counter to credit committed users without over-crediting.
    ///
    /// Only runs once, gated by the sentinel "count is 0 AND date is nil",
    /// which can only be true on a fresh install or an upgrade from a build
    /// before these fields existed. Calling again after a successful backfill
    /// is a no-op because the date will be set.
    private func backfillGoalCompletionCountIfNeeded() {
        guard goalCompletionCount == 0, lastGoalCompletionDate == nil else { return }
        guard !entries.isEmpty else { return }

        let currentGoalML = dailyGoal.totalML
        guard currentGoalML > 0 else { return }

        // Group today's and older entries by start-of-day.
        var totalByDay: [Date: Double] = [:]
        let calendar = Calendar.current
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            totalByDay[day, default: 0] += entry.effectiveML
        }

        // Count distinct days where the total met the current goal.
        let qualifyingDays = totalByDay.filter { $0.value >= currentGoalML }
        guard !qualifyingDays.isEmpty else { return }

        goalCompletionCount = qualifyingDays.count
        lastGoalCompletionDate = qualifyingDays.keys.max()
        persist()
    }

    func deleteEntry(_ entry: HydrationEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func updateEntry(id: UUID, volumeML: Double, fluidType: FluidType? = nil, note: String?) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].volumeML = volumeML
        if let fluidType { entries[index].fluidType = fluidType }
        entries[index].note = note
        checkGoalCompletion()
        persist()
    }

    func updateProfile(_ update: (inout UserProfile) -> Void) {
        var copy = profile
        update(&copy)
        profile = copy
        persist()
    }

    func updateWeather(_ snapshot: WeatherSnapshot) {
        lastWeather = snapshot
        persist()
    }

    func updateWorkout(_ summary: WorkoutSummary) {
        lastWorkout = summary
        persist()
    }

    func updatePremiumAccess(_ hasPremiumAccess: Bool) {
        guard self.hasPremiumAccess != hasPremiumAccess else { return }
        self.hasPremiumAccess = hasPremiumAccess
        if hasPremiumAccess {
            premiumUpsellState = .default
        }
        persist()
    }

    func dismissPremiumUpsell(now: Date = Date()) {
        var nextState = premiumUpsellState
        nextState.dismissCount += 1
        nextState.nextEligibleAt = Calendar.current.date(
            byAdding: .day,
            value: Int.random(in: 30...60),
            to: now.startOfDay
        )
        premiumUpsellState = nextState
        persist()
    }

    func syncHealthKitEntries(_ healthKitEntries: [HydrationEntry], for date: Date = Date()) {
        entries.removeAll { $0.source == .healthKit && $0.date.isSameDay(as: date) }
        entries.append(contentsOf: healthKitEntries)
        entries.sort { $0.date < $1.date }
        checkGoalCompletion()
        persist()
    }

    func syncHealthKitEntriesRange(_ healthKitEntries: [HydrationEntry], days: Int) {
        let cappedDays = max(1, min(30, days))
        guard let start = Calendar.current.date(byAdding: .day, value: -cappedDays + 1, to: Calendar.current.startOfDay(for: Date())) else { return }
        entries.removeAll { $0.source == .healthKit && $0.date >= start }
        entries.append(contentsOf: healthKitEntries)
        entries.sort { $0.date < $1.date }
        checkGoalCompletion()
        persist()
    }

    func resetToday() {
        entries.removeAll { $0.date.isSameDay(as: Date()) }
        persist()
    }

    private func persist() {
        let state = PersistedState(
            entries: entries,
            profile: profile,
            lastWeather: lastWeather,
            lastWorkout: lastWorkout,
            hasPremiumAccess: hasPremiumAccess,
            premiumUpsellState: premiumUpsellState,
            goalCompletionCount: goalCompletionCount,
            lastGoalCompletionDate: lastGoalCompletionDate,
            matchDayWins: matchDayWins,
            lastMatchDayWinDate: lastMatchDayWinDate,
            streakFreezeTokens: streakFreezeTokens,
            streakFreezeDates: streakFreezeDates
        )
        persistence.save(state)
        PhoneSessionManager.shared.sendState(state)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Called by PhoneSessionManager when Watch sends a new entry via WCSession.
    func addWatchEntry(_ entry: HydrationEntry) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        entries.sort { $0.date < $1.date }
        notificationScheduler?.onIntakeLogged(entry: entry, context: buildNotificationContext())
        checkGoalCompletion()
        persist()
    }

    /// Called by PhoneSessionManager when Watch deletes an entry via WCSession.
    func deleteEntry(byID id: UUID) {
        guard entries.contains(where: { $0.id == id }) else { return }
        entries.removeAll { $0.id == id }
        persist()
    }

    /// Push current state to Watch — used when Watch requests a sync on foreground.
    func pushStateToWatch() {
        let state = PersistedState(
            entries: entries,
            profile: profile,
            lastWeather: lastWeather,
            lastWorkout: lastWorkout,
            hasPremiumAccess: hasPremiumAccess,
            premiumUpsellState: premiumUpsellState,
            goalCompletionCount: goalCompletionCount,
            lastGoalCompletionDate: lastGoalCompletionDate,
            matchDayWins: matchDayWins,
            lastMatchDayWinDate: lastMatchDayWinDate,
            streakFreezeTokens: streakFreezeTokens,
            streakFreezeDates: streakFreezeDates
        )
        PhoneSessionManager.shared.sendState(state)
    }

    /// Reloads persisted state from disk and merges it into the in-memory store.
    ///
    /// Fixes a data-loss window: App Intents (Siri/Shortcuts) and widgets write
    /// hydration entries directly to the shared store on disk. The in-memory
    /// `HydrationStore` only loads at `init`, so without this the next in-app
    /// `persist()` would overwrite those entries with its stale snapshot. Called
    /// when the app returns to the foreground; merges by id so entries logged
    /// in-app since the last save are preserved while external writes are picked
    /// up, and re-runs goal-completion accounting.
    func reloadFromDisk() {
        let state = persistence.load(PersistedState.self, fallback: .default)
        applyRemoteState(state)
    }

    func applyRemoteState(_ state: PersistedState) {
        // Merge entries by ID: take the loaded snapshot as the source of truth,
        // and keep any local entries it doesn't include (logged on this device
        // since the snapshot was saved).
        let merged = HydrationMerge.mergeByID(local: entries, incoming: state.entries)
        let hadExtraLocal = merged.count > state.entries.count
        entries = merged

        profile = state.profile
        lastWeather = state.lastWeather
        lastWorkout = state.lastWorkout
        hasPremiumAccess = state.hasPremiumAccess
        premiumUpsellState = state.premiumUpsellState

        // Monotonic merge of the review-prompt counter: take whichever side
        // has progressed further. Dates are compared loosely — the later one wins.
        goalCompletionCount = max(goalCompletionCount, state.goalCompletionCount)
        if let remote = state.lastGoalCompletionDate {
            if let local = lastGoalCompletionDate {
                lastGoalCompletionDate = max(local, remote)
            } else {
                lastGoalCompletionDate = remote
            }
        }

        // Match Day wins merge monotonically like the review counter.
        matchDayWins = max(matchDayWins, state.matchDayWins)
        if let remote = state.lastMatchDayWinDate {
            lastMatchDayWinDate = lastMatchDayWinDate.map { max($0, remote) } ?? remote
        }

        // Freeze dates union (a freeze recorded anywhere really happened);
        // tokens take the larger side — capped, so a rare double-credit from a
        // multi-device race is bounded and harmless.
        let mergedFreezes = Set(streakFreezeDates).union(state.streakFreezeDates)
        streakFreezeDates = mergedFreezes.sorted()
        streakFreezeTokens = min(
            StreakCalculator.maxFreezeTokens,
            max(streakFreezeTokens, state.streakFreezeTokens)
        )

        // In case the merged entries bring today above goal but the remote
        // state didn't reflect that yet (e.g., an old snapshot).
        checkGoalCompletion()
        applyStreakFreezeIfNeeded()

        WidgetCenter.shared.reloadAllTimelines()

        // If the phone had entries the remote didn't know about, push them back to
        // iCloud so the Watch picks them up on its next sync.
        if hadExtraLocal { persist() }
    }
}
