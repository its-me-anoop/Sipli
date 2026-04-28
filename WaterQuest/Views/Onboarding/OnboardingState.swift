import Foundation

enum ReminderCadence: String, CaseIterable, Identifiable, Equatable {
    case gentle
    case steady
    case intense

    var id: String { rawValue }
    var label: String {
        switch self {
        case .gentle: return "Gentle"
        case .steady: return "Steady"
        case .intense: return "On it"
        }
    }
    var perDayLabel: String {
        switch self {
        case .gentle: return "4×/day"
        case .steady: return "8×/day"
        case .intense: return "12×/day"
        }
    }
    var sublabel: String {
        switch self {
        case .gentle: return "Light taps"
        case .steady: return "Recommended"
        case .intense: return "Drill mode"
        }
    }
    var dailyCount: Int {
        switch self {
        case .gentle: return 4
        case .steady: return 8
        case .intense: return 12
        }
    }
}

struct OnboardingState: Equatable {
    var name: String
    var unitSystem: UnitSystem
    var weight: Double
    var activityLevel: ActivityLevel
    var customGoalEnabled: Bool
    var customGoalValue: Double          // in unit's volume unit (ml or oz)
    var prefersHealthKit: Bool
    var prefersWeatherGoal: Bool
    var wakeHour: Double                  // 0..24, fractional hours
    var sleepHour: Double                 // 0..24, fractional hours
    var cadence: ReminderCadence

    init(
        name: String = "",
        unitSystem: UnitSystem = .metric,
        weight: Double = 70,
        activityLevel: ActivityLevel = .steady,
        customGoalEnabled: Bool = false,
        customGoalValue: Double = 2400,
        prefersHealthKit: Bool = true,
        prefersWeatherGoal: Bool = true,
        wakeHour: Double = 7,
        sleepHour: Double = 22,
        cadence: ReminderCadence = .steady
    ) {
        self.name = name
        self.unitSystem = unitSystem
        self.weight = weight
        self.activityLevel = activityLevel
        self.customGoalEnabled = customGoalEnabled
        self.customGoalValue = customGoalValue
        self.prefersHealthKit = prefersHealthKit
        self.prefersWeatherGoal = prefersWeatherGoal
        self.wakeHour = wakeHour
        self.sleepHour = sleepHour
        self.cadence = cadence
    }

    var weightKg: Double { unitSystem.kg(from: weight) }

    var customGoalML: Double? {
        customGoalEnabled ? unitSystem.ml(from: customGoalValue) : nil
    }

    var canContinueFromName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var livePreviewGoalML: Double {
        GoalCalculator.previewDailyGoal(
            weightKg: weightKg,
            activity: activityLevel,
            customGoalML: customGoalML
        )
    }

    /// Daily target shown on the Target screen when "custom" is off — uses
    /// the suggested value directly (matches the design's `suggested = 2400`).
    var suggestedTargetML: Double { 2400 }

    var displayedTargetML: Double {
        customGoalEnabled ? unitSystem.ml(from: customGoalValue) : suggestedTargetML
    }

    /// Hours awake (positive number, wraps at 24).
    var awakeHours: Double {
        let diff = sleepHour - wakeHour
        return diff <= 0 ? diff + 24 : diff
    }

    func minutesFromHour(_ hour: Double) -> Int {
        let h = max(0, min(24, hour))
        let total = Int(round(h * 60))
        return total % (24 * 60)
    }

    var wakeMinutes: Int { minutesFromHour(wakeHour) }
    var sleepMinutes: Int { minutesFromHour(sleepHour) }

    func weightSliderRange() -> ClosedRange<Double> {
        unitSystem == .metric ? 35...150 : 77...330
    }

    func customGoalRange() -> ClosedRange<Double> {
        unitSystem == .metric ? 1000...4000 : 33...135
    }
}
