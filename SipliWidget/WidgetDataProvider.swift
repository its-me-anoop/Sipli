import Foundation

struct WidgetData {
    let todayEntries: [HydrationEntry]
    let todayTotalML: Double
    let goal: GoalBreakdown
    let streak: Int
    let unitSystem: UnitSystem
}

enum WidgetDataProvider {
    static func load() -> WidgetData {
        let persistence = PersistenceService()
        let state = persistence.load(PersistedState.self, fallback: .default)
        let effectiveProfile = state.profile.applyingPremiumAccess(state.hasPremiumAccess)

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let todayEntries = state.entries
            .filter { calendar.isDate($0.date, inSameDayAs: startOfToday) }
            .sorted { $0.date > $1.date }

        let todayTotalML = todayEntries.reduce(0) { $0 + $1.effectiveML }

        let goal = GoalCalculator.dailyGoal(
            profile: effectiveProfile,
            weather: effectiveProfile.prefersWeatherGoal ? state.lastWeather : nil,
            workout: effectiveProfile.prefersHealthKit ? state.lastWorkout : nil
        )

        // Shared, freeze-aware streak — identical math to the app and Insights.
        let streak = StreakCalculator.currentStreak(
            entries: state.entries,
            goalML: goal.totalML,
            freezeDates: state.streakFreezeDates
        )

        return WidgetData(
            todayEntries: todayEntries,
            todayTotalML: todayTotalML,
            goal: goal,
            streak: streak,
            unitSystem: effectiveProfile.unitSystem
        )
    }
}
