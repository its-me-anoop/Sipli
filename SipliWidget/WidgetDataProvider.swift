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

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let todayEntries = state.entries
            .filter { calendar.isDate($0.date, inSameDayAs: startOfToday) }
            .sorted { $0.date > $1.date }

        let todayTotalML = todayEntries.reduce(0) { $0 + $1.effectiveML }

        let goal = GoalCalculator.dailyGoal(
            profile: state.profile,
            weather: state.lastWeather,
            workout: state.lastWorkout
        )

        let streak = calculateStreak(entries: state.entries, goalML: goal.totalML)

        return WidgetData(
            todayEntries: todayEntries,
            todayTotalML: todayTotalML,
            goal: goal,
            streak: streak,
            unitSystem: state.profile.unitSystem
        )
    }

    private static func calculateStreak(entries: [HydrationEntry], goalML: Double) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        let todayTotal = entries
            .filter { calendar.isDate($0.date, inSameDayAs: checkDate) }
            .reduce(0) { $0 + $1.effectiveML }

        if todayTotal < goalML {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        for dayOffset in 0..<90 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: checkDate) else { break }
            let dayTotal = entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.effectiveML }

            if dayTotal >= goalML {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }
}
