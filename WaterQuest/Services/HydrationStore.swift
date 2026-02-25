import Foundation
import WidgetKit

@MainActor
final class HydrationStore: ObservableObject {
    @Published var entries: [HydrationEntry]
    @Published var profile: UserProfile
    @Published var lastWeather: WeatherSnapshot?
    @Published var lastWorkout: WorkoutSummary

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
    }

    var dailyGoal: GoalBreakdown {
        GoalCalculator.dailyGoal(profile: profile, weather: activeWeather, workout: lastWorkout)
    }

    var activeWeather: WeatherSnapshot? {
        profile.prefersWeatherGoal ? lastWeather : nil
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
        persist()
        return entry
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
            lastWorkout: lastWorkout
        )
        persistence.save(state)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

