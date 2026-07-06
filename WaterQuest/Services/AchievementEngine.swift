import Foundation

/// Pure achievement evaluation, in the same spirit as `StreakCalculator`:
/// no store, no singletons, everything injected, safe to call from any target.
///
/// `earned` returns every badge whose condition the given state satisfies
/// *right now*. Unlocks are latched by the caller (`HydrationStore`) into
/// `PersistedState.unlockedAchievements` — the engine never revokes, so a
/// milestone stays earned even after the underlying streak breaks.
///
/// Goal-relative conditions use the *current* goal, the same approximation
/// `HydrationStore.backfillGoalCompletionCountIfNeeded()` already established
/// for historical days.
enum AchievementEngine {

    static func earned(
        state: PersistedState,
        goalML: Double,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Set<String> {
        var ids: Set<String> = []

        // Shared aggregates, computed once.
        var totalByDay: [Date: Double] = [:]
        var lifetimeEffectiveML = 0.0
        var distinctFluids = Set<FluidType>()
        var hasEarlyBird = false, hasNightOwl = false, hasMidnight = false

        for entry in state.entries {
            let dayStart = calendar.startOfDay(for: entry.date)
            totalByDay[dayStart, default: 0] += entry.effectiveML
            lifetimeEffectiveML += entry.effectiveML
            distinctFluids.insert(entry.fluidType)

            let hour = calendar.component(.hour, from: entry.date)
            if hour < 7 { hasEarlyBird = true }
            if hour >= 22 { hasNightOwl = true }
            if hour == 0 { hasMidnight = true }
        }

        let frozen = Set(state.streakFreezeDates.map { calendar.startOfDay(for: $0) })
        let metDays: Set<Date>
        let metDaysUnfrozen: Set<Date>
        if goalML > 0 {
            let unfrozen = Set(totalByDay.filter { $0.value >= goalML }.keys)
            metDaysUnfrozen = unfrozen
            metDays = unfrozen.union(frozen)
        } else {
            metDays = []
            metDaysUnfrozen = []
        }

        // MARK: Consistency
        let longest = longestRun(of: metDays, calendar: calendar)
        for threshold in [3, 7, 14, 30, 60, 100] where longest >= threshold {
            ids.insert("streak.\(threshold)")
        }
        // Perfect Week/Weekend promise "hit your goal", so frozen days don't
        // count — unlike streak milestones, where a freeze preserving the run
        // is the whole point of the token.
        if hasPerfectWeek(metDays: metDaysUnfrozen, calendar: calendar) {
            ids.insert("week.perfect")
        }

        // MARK: Volume
        for litres in [10, 50, 100, 250, 500] where lifetimeEffectiveML >= Double(litres) * 1000 {
            ids.insert("volume.\(litres)")
        }
        if goalML > 0, totalByDay.values.contains(where: { $0 >= goalML * 1.5 }) {
            ids.insert("day.overflow")
        }

        // MARK: Explorer
        if distinctFluids.contains(where: { $0 != .water }) {
            ids.insert("explorer.first")
        }
        for count in [3, 8, 15] where distinctFluids.count >= count {
            ids.insert("explorer.\(count)")
        }

        // MARK: Dedication
        for count in [7, 30, 100] where state.goalCompletionCount >= count {
            ids.insert("goal.\(count)")
        }
        if hasEarlyBird { ids.insert("earlybird") }
        if hasNightOwl { ids.insert("nightowl") }
        if hasPerfectWeekend(metDays: metDaysUnfrozen, calendar: calendar) {
            ids.insert("weekend.perfect")
        }
        if state.streakFreezeTokens >= StreakCalculator.maxFreezeTokens {
            ids.insert("freeze.full")
        }

        // MARK: Season
        if state.matchDayWins >= 1 { ids.insert("matchday.first") }
        if state.matchDayWins >= MatchDay.winsForGoldenBottle { ids.insert("matchday.golden") }

        // MARK: Secret
        if hasMidnight { ids.insert("secret.midnight") }
        if state.counters.siriLogCount >= 1 { ids.insert("secret.siri") }
        if state.counters.widgetLogCount >= 1 { ids.insert("secret.widget") }
        if state.counters.undoCount >= 5 { ids.insert("secret.undo") }
        if longestRun(of: metDaysUnfrozen, calendar: calendar) >= 30 {
            ids.insert("secret.purist")
        }

        return ids
    }

    // MARK: - Helpers

    /// Longest run of consecutive calendar days in `days`.
    private static func longestRun(of days: Set<Date>, calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var longest = 1
        var current = 1
        for (previous, day) in zip(sorted, sorted.dropFirst()) {
            if let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    /// True when some calendar week has all 7 days goal-met.
    private static func hasPerfectWeek(metDays: Set<Date>, calendar: Calendar) -> Bool {
        var metPerWeek: [String: Int] = [:]
        for day in metDays {
            let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: day)
            guard let week = comps.weekOfYear, let year = comps.yearForWeekOfYear else { continue }
            let key = "\(year)-\(week)"
            metPerWeek[key, default: 0] += 1
            if metPerWeek[key] == 7 { return true }
        }
        return false
    }

    /// True when a Saturday and its following Sunday are both goal-met.
    private static func hasPerfectWeekend(metDays: Set<Date>, calendar: Calendar) -> Bool {
        for day in metDays where calendar.component(.weekday, from: day) == 7 {
            if let sunday = calendar.date(byAdding: .day, value: 1, to: day),
               metDays.contains(calendar.startOfDay(for: sunday)) {
                return true
            }
        }
        return false
    }
}
