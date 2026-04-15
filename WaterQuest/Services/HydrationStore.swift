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
    @Published var earthDayBannerDismissed: Bool
    @Published var earthDay2026Earned: Bool
    /// Lifetime count of days the user has hit their daily hydration goal.
    /// Observed by DashboardView to decide when to prompt for an App Store review.
    @Published private(set) var goalCompletionCount: Int
    /// Start-of-day of the most recent day the user hit their goal.
    /// Used by ``checkGoalCompletion()`` to avoid double-counting same-day crossings.
    @Published private(set) var lastGoalCompletionDate: Date?

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
        self.earthDayBannerDismissed = state.earthDay2026BannerDismissed
        self.earthDay2026Earned = state.earthDay2026Earned
        self.goalCompletionCount = state.goalCompletionCount
        self.lastGoalCompletionDate = state.lastGoalCompletionDate

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

    @discardableResult
    func addIntake(amount: Double, unitSystem: UnitSystem? = nil, source: HydrationSource = .manual, fluidType: FluidType = .water, note: String? = nil) -> HydrationEntry {
        let units = unitSystem ?? profile.unitSystem
        let ml = units.ml(from: amount)
        let entry = HydrationEntry(date: Date(), volumeML: ml, source: source, fluidType: fluidType, note: note)
        entries.append(entry)
        notificationScheduler?.onIntakeLogged(entry: entry)
        if !earthDay2026Earned, EarthDayEvent.isEarthDay(entry.date) {
            earthDay2026Earned = true
        }
        checkGoalCompletion()
        persist()
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
        if let last = lastGoalCompletionDate,
           Calendar.current.isDate(last, inSameDayAs: today) {
            return // already counted today
        }

        goalCompletionCount += 1
        lastGoalCompletionDate = today
    }

    func dismissEarthDayBanner() {
        guard !earthDayBannerDismissed else { return }
        earthDayBannerDismissed = true
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
            earthDay2026BannerDismissed: earthDayBannerDismissed,
            earthDay2026Earned: earthDay2026Earned,
            goalCompletionCount: goalCompletionCount,
            lastGoalCompletionDate: lastGoalCompletionDate
        )
        persistence.save(state)
        PhoneSessionManager.shared.sendState(state)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Called by PhoneSessionManager when the Watch sends state via WCSession.
    /// Merges entries only — does not overwrite iPhone-authoritative fields
    /// (profile, weather, workout, premium) which the Watch never modifies.
    func mergeWatchState(_ state: PersistedState) {
        var byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        var hadNew = false
        for entry in state.entries where byID[entry.id] == nil {
            byID[entry.id] = entry
            hadNew = true
        }
        guard hadNew else { return }
        entries = byID.values.sorted { $0.date < $1.date }
        checkGoalCompletion()
        persist()
    }

    func applyRemoteState(_ state: PersistedState) {
        // Merge entries by ID: add any remote entries the phone doesn't have yet,
        // and keep any local entries the remote snapshot doesn't include (logged on
        // phone since the Watch's last iCloud save).
        var byID = Dictionary(uniqueKeysWithValues: state.entries.map { ($0.id, $0) })
        for entry in entries where byID[entry.id] == nil {
            byID[entry.id] = entry
        }
        let hadExtraLocal = byID.count > state.entries.count
        entries = byID.values.sorted { $0.date < $1.date }

        profile = state.profile
        lastWeather = state.lastWeather
        lastWorkout = state.lastWorkout
        hasPremiumAccess = state.hasPremiumAccess
        premiumUpsellState = state.premiumUpsellState
        earthDayBannerDismissed = state.earthDay2026BannerDismissed
        earthDay2026Earned = state.earthDay2026Earned

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
        // In case the merged entries bring today above goal but the remote
        // state didn't reflect that yet (e.g., an old snapshot).
        checkGoalCompletion()

        WidgetCenter.shared.reloadAllTimelines()

        // If the phone had entries the remote didn't know about, push them back to
        // iCloud so the Watch picks them up on its next sync.
        if hadExtraLocal { persist() }
    }
}
