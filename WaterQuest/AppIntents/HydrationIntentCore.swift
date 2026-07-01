import Foundation

/// Pure, side-effect-free logic shared by the App Intents
/// (`LogWaterIntent`, `GetTodaysHydrationIntent`, `UndoLastIntakeIntent`).
///
/// Everything here operates on a `PersistedState` value with `now` injected,
/// so it is fully unit-testable without touching disk, iCloud, or the
/// `@MainActor` store. The intents are thin wrappers that load the state, call
/// into this core, then save and fire side effects (widget reload, donation).
///
/// Goal is computed from `profile` + `lastWeather` only (no workout) — a quick
/// Siri/Shortcuts log doesn't reach for live HealthKit; the full goal is
/// recomputed in-app when the store reloads.
enum HydrationIntentCore {
    /// Accepted intake range in millilitres, mirroring the in-app intake slider.
    static let minML: Double = 50
    static let maxML: Double = 2000

    static func clampAmount(_ ml: Int) -> Double {
        min(max(Double(ml), minML), maxML)
    }

    static func goalML(for state: PersistedState) -> Double {
        GoalCalculator.dailyGoal(
            profile: state.profile,
            weather: state.lastWeather,
            workout: nil
        ).totalML
    }

    static func todayTotalML(_ state: PersistedState, now: Date) -> Double {
        state.entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
            .reduce(0) { $0 + $1.effectiveML }
    }

    static func percent(total: Double, goal: Double) -> Int {
        goal > 0 ? Int((total / goal) * 100) : 0
    }

    // MARK: - Intent operations

    @discardableResult
    static func logWater(
        into state: inout PersistedState,
        amountInMilliliters: Int,
        fluidType: FluidType,
        now: Date
    ) -> (entry: HydrationEntry, dialog: String, compactDialog: String) {
        let clampedML = clampAmount(amountInMilliliters)
        let entry = HydrationEntry(date: now, volumeML: clampedML, source: .manual, fluidType: fluidType)
        state.entries.append(entry)

        let pct = percent(total: todayTotalML(state, now: now), goal: goalML(for: state))
        let dialog = "Logged \(Int(clampedML)) mL of \(label(for: fluidType)). You're at \(pct)% of today's goal."
        let compact = "\(Int(clampedML)) mL \(label(for: fluidType)) logged — \(pct)% of goal"
        return (entry, dialog, compact)
    }

    static func todaysHydrationDialog(state: PersistedState, now: Date) -> String {
        let goal = goalML(for: state)
        let total = todayTotalML(state, now: now)
        let pct = percent(total: total, goal: goal)
        return "You've had \(Int(total)) mL of water today — \(pct)% of your \(Int(goal)) mL goal."
    }

    /// Short variant for visual surfaces (Shortcuts banners, Spotlight) on
    /// iOS 27, where `systemContext.isVoiceOnly` distinguishes spoken from
    /// on-screen delivery. Voice always gets the full-sentence dialog.
    static func todaysHydrationCompact(state: PersistedState, now: Date) -> String {
        let goal = goalML(for: state)
        let total = todayTotalML(state, now: now)
        let pct = percent(total: total, goal: goal)
        return "\(Int(total)) / \(Int(goal)) mL — \(pct)%"
    }

    @discardableResult
    static func undoLastToday(
        from state: inout PersistedState,
        now: Date
    ) -> (removed: HydrationEntry?, dialog: String, compactDialog: String) {
        let todayIndices = state.entries.indices.filter {
            Calendar.current.isDate(state.entries[$0].date, inSameDayAs: now)
        }
        guard let idx = todayIndices.max(by: { state.entries[$0].date < state.entries[$1].date }) else {
            let nothing = "There's nothing logged today to undo."
            return (nil, nothing, nothing)
        }
        let removed = state.entries.remove(at: idx)
        let pct = percent(total: todayTotalML(state, now: now), goal: goalML(for: state))
        let dialog = "Removed your last \(label(for: removed.fluidType)) (\(Int(removed.volumeML)) mL). You're now at \(pct)% of today's goal."
        let compact = "Removed \(Int(removed.volumeML)) mL \(label(for: removed.fluidType)) — \(pct)% of goal"
        return (removed, dialog, compact)
    }

    // MARK: - Helpers

    private static func label(for fluidType: FluidType) -> String {
        fluidType == .water ? "water" : fluidType.displayName.lowercased()
    }
}
