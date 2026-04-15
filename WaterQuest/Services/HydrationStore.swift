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
        persist()
        return entry
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
        persist()
    }

    func syncHealthKitEntriesRange(_ healthKitEntries: [HydrationEntry], days: Int) {
        let cappedDays = max(1, min(30, days))
        guard let start = Calendar.current.date(byAdding: .day, value: -cappedDays + 1, to: Calendar.current.startOfDay(for: Date())) else { return }
        entries.removeAll { $0.source == .healthKit && $0.date >= start }
        entries.append(contentsOf: healthKitEntries)
        entries.sort { $0.date < $1.date }
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
            earthDay2026Earned: earthDay2026Earned
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
        WidgetCenter.shared.reloadAllTimelines()

        // If the phone had entries the remote didn't know about, push them back to
        // iCloud so the Watch picks them up on its next sync.
        if hadExtraLocal { persist() }
    }
}
