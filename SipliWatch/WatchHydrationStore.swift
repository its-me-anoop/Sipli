import Foundation
import Combine
import WidgetKit
@preconcurrency import UserNotifications

/// Watch-side store. The Watch is a pure companion of the iPhone:
///   • It never writes to iCloud KVS — only the iPhone manages cloud sync.
///   • iPhone is the single source of truth; full state is received via WCSession.
///   • Watch optimistically adds entries locally and sends them to iPhone.
///   • Watch sends explicit deletion IDs to iPhone rather than inferring deletions.
@MainActor
final class WatchHydrationStore: ObservableObject {
    @Published var entries: [HydrationEntry] = []
    @Published var profile: UserProfile = .default
    @Published var goalBreakdown: GoalBreakdown = GoalBreakdown(baseML: 2450, weatherAdjustmentML: 0, workoutAdjustmentML: 0, totalML: 2450)
    @Published var hasPremiumAccess: Bool = false
    @Published var justReachedGoal: Bool = false

    var healthKitManager: WatchHealthKitManager?

    // Local-only cache (no iCloud writes).
    private let persistence = PersistenceService()
    // Entries logged on Watch not yet confirmed in an iPhone state push.
    private var pendingEntryIDs = Set<UUID>()

    init() {
        loadCachedState()
        // No iCloud KVS handler — Watch syncs exclusively with iPhone via WCSession.
        WatchSessionManager.shared.store = self
        WatchSessionManager.shared.activate()
    }

    // MARK: - Computed

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
        var result = Array(fromHistory)
        for fallback in defaults where result.count < 6 {
            if !result.contains(fallback) { result.append(fallback) }
        }
        return Array(result.prefix(6))
    }

    // MARK: - Actions

    func addIntake(volumeML: Double, fluidType: FluidType = .water) {
        let wasBelow = todayTotalML < goalBreakdown.totalML

        let entry = HydrationEntry(
            date: Date(),
            volumeML: volumeML,
            source: .watchManual,
            fluidType: fluidType
        )
        entries.append(entry)
        pendingEntryIDs.insert(entry.id)
        cacheLocally()
        WidgetCenter.shared.reloadAllTimelines()

        // Send new entry to iPhone — iPhone processes it and pushes full state back.
        WatchSessionManager.shared.sendNewEntry(entry)

        if wasBelow && todayTotalML >= goalBreakdown.totalML {
            justReachedGoal = true
            WatchHaptics.goalReached()
            suppressRemainingReminders()
        }

        if let hk = healthKitManager, hk.isAuthorized {
            Task { await hk.logWaterIntake(ml: volumeML) }
        }
    }

    func deleteEntry(_ entry: HydrationEntry) {
        entries.removeAll { $0.id == entry.id }
        pendingEntryIDs.remove(entry.id)
        cacheLocally()
        WidgetCenter.shared.reloadAllTimelines()
        // Tell iPhone to delete the entry so it can persist and push state back.
        WatchSessionManager.shared.sendDeletion(id: entry.id)
    }

    // MARK: - Sync

    /// Receives the iPhone's authoritative full state. Replaces local state entirely,
    /// preserving only entries that were logged on Watch and not yet confirmed.
    func applyRemoteState(_ state: PersistedState) {
        let wasBelow = todayTotalML < goalBreakdown.totalML

        // Retire pending entries that iPhone now acknowledges.
        pendingEntryIDs = pendingEntryIDs.filter { id in
            !state.entries.contains(where: { $0.id == id })
        }

        // Full replace from iPhone + any still-unconfirmed Watch entries.
        let pendingEntries = entries.filter { pendingEntryIDs.contains($0.id) }
        entries = (state.entries + pendingEntries).sorted { $0.date < $1.date }

        profile = state.profile
        hasPremiumAccess = state.hasPremiumAccess
        updateGoal(from: state)
        cacheLocally()
        WidgetCenter.shared.reloadAllTimelines()

        if wasBelow && todayTotalML >= goalBreakdown.totalML {
            justReachedGoal = true
            WatchHaptics.goalReached()
            suppressRemainingReminders()
        }
    }

    /// Called when the Watch app becomes active — asks iPhone to push its state.
    func requestSync() {
        WatchSessionManager.shared.sendSyncRequest()
    }

    // MARK: - Private

    /// Loads from the local cache file (no iCloud). Used at cold start while
    /// WCSession delivers the authoritative iPhone state.
    func loadCachedState() {
        let state = persistence.loadLocalOnly(PersistedState.self, fallback: .default)
        entries = state.entries
        profile = state.profile
        hasPremiumAccess = state.hasPremiumAccess
        updateGoal(from: state)
    }

    /// Writes current state to the local file only — never touches iCloud KVS.
    private func cacheLocally() {
        let state = PersistedState(
            entries: entries,
            profile: profile,
            lastWeather: nil,
            lastWorkout: .empty,
            hasPremiumAccess: hasPremiumAccess,
            premiumUpsellState: .default
        )
        persistence.saveLocalOnly(state)
    }

    private func updateGoal(from state: PersistedState) {
        let effectiveProfile = state.profile.applyingPremiumAccess(state.hasPremiumAccess)
        let weather = effectiveProfile.prefersWeatherGoal ? state.lastWeather : nil
        let workout = effectiveProfile.prefersHealthKit ? state.lastWorkout : nil
        goalBreakdown = GoalCalculator.dailyGoal(profile: effectiveProfile, weather: weather, workout: workout)
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
