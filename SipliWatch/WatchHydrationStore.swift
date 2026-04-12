import Foundation
import Combine

@MainActor
final class WatchHydrationStore: ObservableObject {
    @Published var entries: [HydrationEntry] = []
    @Published var profile: UserProfile = .default
    @Published var goalBreakdown: GoalBreakdown = GoalBreakdown(baseML: 2450, weatherAdjustmentML: 0, workoutAdjustmentML: 0, totalML: 2450)
    @Published var hasPremiumAccess: Bool = false

    private let persistence = PersistenceService()

    init() {
        loadState()
        persistence.setRemoteDataChangeHandler { [weak self] _ in
            Task { @MainActor in
                self?.loadState()
            }
        }
    }

    var todayEntries: [HydrationEntry] {
        let startOfDay = Date().startOfDay
        return entries.filter { $0.date >= startOfDay }
    }

    var todayTotalML: Double {
        todayEntries.reduce(0) { $0 + $1.effectiveML }
    }

    var todayDrinkCount: Int {
        todayEntries.count
    }

    var progress: Double {
        guard goalBreakdown.totalML > 0 else { return 0 }
        return min(todayTotalML / goalBreakdown.totalML, 1.0)
    }

    var remainingML: Double {
        max(goalBreakdown.totalML - todayTotalML, 0)
    }

    var topFluidTypes: [FluidType] {
        let counts = Dictionary(grouping: entries, by: \.fluidType)
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map(\.key)

        if counts.isEmpty {
            return [.water, .coffee, .greenTea, .sparklingWater, .juice, .milk]
        }
        return Array(counts)
    }

    func addIntake(volumeML: Double, fluidType: FluidType = .water) {
        let entry = HydrationEntry(
            date: Date(),
            volumeML: volumeML,
            source: .watchManual,
            fluidType: fluidType
        )
        entries.append(entry)
        saveState()
    }

    func deleteEntry(_ entry: HydrationEntry) {
        entries.removeAll { $0.id == entry.id }
        saveState()
    }

    func loadState() {
        let state = persistence.load(PersistedState.self, fallback: .default)
        entries = state.entries
        profile = state.profile
        hasPremiumAccess = state.hasPremiumAccess

        let weather = state.profile.prefersWeatherGoal ? state.lastWeather : nil
        let workout = state.profile.prefersHealthKit ? state.lastWorkout : nil
        goalBreakdown = GoalCalculator.dailyGoal(
            profile: state.profile,
            weather: weather,
            workout: workout
        )
    }

    private func saveState() {
        var state = persistence.load(PersistedState.self, fallback: .default)
        state.entries = entries
        persistence.save(state)
    }
}
