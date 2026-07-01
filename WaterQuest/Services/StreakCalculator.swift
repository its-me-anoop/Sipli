import Foundation

/// Single source of truth for the goal-streak algorithm, extracted from the
/// three call sites that previously inlined it (`HydrationStore`,
/// `InsightsViewModel`, `WidgetDataProvider`). Shared with the widget target,
/// so it must stay pure: no store, no singletons, everything injected.
///
/// A day counts toward the streak when its effective intake meets the goal
/// OR the day was covered by a streak freeze (see `PersistedState.streakFreezeDates`).
/// The streak is the run of consecutive counting days ending today (if today
/// counts) or yesterday (if today doesn't count yet — the user still has time).
enum StreakCalculator {
    /// Maximum days scanned backwards; mirrors the historical 90-day window.
    static let lookbackDays = 90

    /// Maximum freeze tokens a user can bank.
    static let maxFreezeTokens = 3

    /// A freeze token is earned every time the streak reaches a multiple of this.
    static let freezeEarnInterval = 7

    static func currentStreak(
        entries: [HydrationEntry],
        goalML: Double,
        freezeDates: [Date] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard goalML > 0 else { return 0 }
        let today = calendar.startOfDay(for: now)
        let frozen = Set(freezeDates.map { calendar.startOfDay(for: $0) })

        var totalByDay: [Date: Double] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            totalByDay[day, default: 0] += entry.effectiveML
        }

        func counts(_ day: Date) -> Bool {
            (totalByDay[day] ?? 0) >= goalML || frozen.contains(day)
        }

        // Anchor on today if it already counts, otherwise on yesterday.
        var anchor = today
        if !counts(anchor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            anchor = yesterday
        }

        var streak = 0
        for offset in 0..<lookbackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: anchor) else { break }
            if counts(day) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    /// Whether a freeze should be spent to bridge yesterday's gap.
    ///
    /// Conditions: yesterday missed the goal and isn't already frozen, the user
    /// has a token, and there was a live streak running into the day before
    /// yesterday (freezes preserve streaks, they don't start them).
    /// Returns the start-of-day date to freeze, or nil.
    static func freezeConsumableDate(
        entries: [HydrationEntry],
        goalML: Double,
        freezeDates: [Date],
        tokens: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard tokens > 0, goalML > 0 else { return nil }
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }

        let frozen = Set(freezeDates.map { calendar.startOfDay(for: $0) })
        guard !frozen.contains(yesterday) else { return nil }

        var yesterdayTotal = 0.0
        for entry in entries where calendar.isDate(entry.date, inSameDayAs: yesterday) {
            yesterdayTotal += entry.effectiveML
        }
        guard yesterdayTotal < goalML else { return nil }

        // Require a streak that ended the day before yesterday.
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: yesterday) else { return nil }
        let priorStreak = currentStreak(
            entries: entries,
            goalML: goalML,
            freezeDates: freezeDates,
            now: dayBefore,
            calendar: calendar
        )
        guard priorStreak >= 1 else { return nil }

        return yesterday
    }
}
