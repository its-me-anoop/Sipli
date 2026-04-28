import Foundation

enum GoalCalculator {
    static func dailyGoal(profile: UserProfile, weather: WeatherSnapshot?, workout: WorkoutSummary?) -> GoalBreakdown {
        let baseComputed = profile.weightKg * profile.activityLevel.multiplier
        let base = profile.customGoalML ?? baseComputed

        let weatherAdjustment: Double
        if profile.prefersWeatherGoal, let weather = weather {
            weatherAdjustment = weatherAdjustmentFor(tempC: weather.temperatureC, humidity: weather.humidityPercent)
        } else {
            weatherAdjustment = 0
        }

        let workoutAdjustment: Double
        if profile.prefersHealthKit, let workout = workout {
            workoutAdjustment = workout.exerciseMinutes * 12
        } else {
            workoutAdjustment = 0
        }

        let total = max(1200, base + weatherAdjustment + workoutAdjustment)
        return GoalBreakdown(baseML: base, weatherAdjustmentML: weatherAdjustment, workoutAdjustmentML: workoutAdjustment, totalML: total)
    }

    /// Goal preview shown during onboarding, before weather/HealthKit data sources are connected.
    /// Mirrors `dailyGoal(profile:weather:workout:)` minus the weather and workout adjustments —
    /// those streams only become available after the user grants the relevant permissions
    /// on the final onboarding step.
    static func previewDailyGoal(weightKg: Double, activity: ActivityLevel, customGoalML: Double?) -> Double {
        let computed = weightKg * activity.multiplier
        let base = customGoalML ?? computed
        return max(1200, base)
    }

    private static func weatherAdjustmentFor(tempC: Double, humidity: Double) -> Double {
        var adjustment: Double = 0
        switch tempC {
        case 30...:
            adjustment += 650
        case 26..<30:
            adjustment += 450
        case 22..<26:
            adjustment += 250
        case ..<5:
            adjustment -= 200
        default:
            break
        }

        switch humidity {
        case 80...:
            adjustment += 250
        case 70..<80:
            adjustment += 150
        default:
            break
        }

        return adjustment
    }
}
