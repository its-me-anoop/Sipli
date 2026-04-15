import Foundation
import Combine
import WidgetKit
@preconcurrency import UserNotifications

@MainActor
final class WatchHydrationStore: ObservableObject {
    @Published var entries: [HydrationEntry] = []
    @Published var profile: UserProfile = .default
    @Published var goalBreakdown: GoalBreakdown = GoalBreakdown(baseML: 2450, weatherAdjustmentML: 0, workoutAdjustmentML: 0, totalML: 2450)
    @Published var hasPremiumAccess: Bool = false
    @Published var justReachedGoal: Bool = false

    var healthKitManager: WatchHealthKitManager?

    private let persistence = PersistenceService()
    // IDs deleted during this session — excluded from the merge in saveState() so
    // local deletions aren't resurrected by a stale iCloud snapshot.
    private var deletedEntryIDs = Set<UUID>()

    init() {
        loadState()
        persistence.setRemoteDataChangeHandler { [weak self] _ in
            Task { @MainActor in
                self?.loadState()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        WatchSessionManager.shared.store = self
        WatchSessionManager.shared.activate()
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
        let defaults: [FluidType] = [.water, .coffee, .greenTea, .sparklingWater, .juice, .milk]

        let fromHistory = Dictionary(grouping: entries, by: \.fluidType)
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map(\.key)

        // Pad with defaults if history has fewer than 6 types
        var result = Array(fromHistory)
        for fallback in defaults where result.count < 6 {
            if !result.contains(fallback) {
                result.append(fallback)
            }
        }
        return Array(result.prefix(6))
    }

    func addIntake(volumeML: Double, fluidType: FluidType = .water) {
        let wasBelow = todayTotalML < goalBreakdown.totalML

        let entry = HydrationEntry(
            date: Date(),
            volumeML: volumeML,
            source: .watchManual,
            fluidType: fluidType
        )
        entries.append(entry)
        saveState()
        WidgetCenter.shared.reloadAllTimelines()

        if wasBelow && todayTotalML >= goalBreakdown.totalML {
            justReachedGoal = true
            WatchHaptics.goalReached()
            // Suppress remaining reminders for today
            suppressRemainingReminders()
        }

        if let hk = healthKitManager, hk.isAuthorized {
            Task {
                await hk.logWaterIntake(ml: volumeML)
            }
        }
    }

    func deleteEntry(_ entry: HydrationEntry) {
        deletedEntryIDs.insert(entry.id)
        entries.removeAll { $0.id == entry.id }
        saveState()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func loadState() {
        let state = persistence.load(PersistedState.self, fallback: .default)
        entries = state.entries.filter { !deletedEntryIDs.contains($0.id) }
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
        // Merge remote entries with in-memory entries by ID so that phone entries
        // delivered by iCloud between our last loadState() and this save are not lost.
        var byID = Dictionary(uniqueKeysWithValues: state.entries.map { ($0.id, $0) })
        for entry in entries { byID[entry.id] = entry }
        deletedEntryIDs.forEach { byID.removeValue(forKey: $0) }
        state.entries = byID.values.sorted { $0.date < $1.date }
        persistence.save(state)
        WatchSessionManager.shared.sendState(state)
    }

    /// Called by WatchSessionManager when the iPhone pushes a state update over WCSession.
    func applyRemoteState(_ state: PersistedState) {
        var byID = Dictionary(uniqueKeysWithValues: state.entries.map { ($0.id, $0) })
        for entry in entries where byID[entry.id] == nil {
            byID[entry.id] = entry
        }
        entries = byID.values
            .filter { !deletedEntryIDs.contains($0.id) }
            .sorted { $0.date < $1.date }
        profile = state.profile
        hasPremiumAccess = state.hasPremiumAccess

        let weather = state.profile.prefersWeatherGoal ? state.lastWeather : nil
        let workout = state.profile.prefersHealthKit ? state.lastWorkout : nil
        goalBreakdown = GoalCalculator.dailyGoal(
            profile: state.profile,
            weather: weather,
            workout: workout
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func suppressRemainingReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let reminderIds = requests
                .filter { $0.content.categoryIdentifier == "HYDRATION_REMINDER" }
                .map(\.identifier)
            if !reminderIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: reminderIds)
            }
        }
    }
}
