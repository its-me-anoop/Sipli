import Foundation

enum ActivityLevel: String, Codable, CaseIterable {
    case chill
    case steady
    case intense

    var label: String {
        switch self {
        case .chill: return "Chill"
        case .steady: return "Steady"
        case .intense: return "Intense"
        }
    }

    var multiplier: Double {
        switch self {
        case .chill: return 32.0
        case .steady: return 35.0
        case .intense: return 38.0
        }
    }
}

struct UserProfile: Codable {
    var name: String
    var unitSystem: UnitSystem
    var weightKg: Double
    var activityLevel: ActivityLevel
    var customGoalML: Double?
    var remindersEnabled: Bool
    var wakeMinutes: Int
    var sleepMinutes: Int
    var prefersWeatherGoal: Bool
    var prefersHealthKit: Bool
    var smartRemindersEnabled: Bool

    init(
        name: String,
        unitSystem: UnitSystem,
        weightKg: Double,
        activityLevel: ActivityLevel,
        customGoalML: Double?,
        remindersEnabled: Bool,
        wakeMinutes: Int,
        sleepMinutes: Int,
        prefersWeatherGoal: Bool,
        prefersHealthKit: Bool,
        smartRemindersEnabled: Bool
    ) {
        self.name = name
        self.unitSystem = unitSystem
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.customGoalML = customGoalML
        self.remindersEnabled = remindersEnabled
        self.wakeMinutes = wakeMinutes
        self.sleepMinutes = sleepMinutes
        self.prefersWeatherGoal = prefersWeatherGoal
        self.prefersHealthKit = prefersHealthKit
        self.smartRemindersEnabled = smartRemindersEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        unitSystem = try container.decode(UnitSystem.self, forKey: .unitSystem)
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        activityLevel = try container.decode(ActivityLevel.self, forKey: .activityLevel)
        customGoalML = try container.decodeIfPresent(Double.self, forKey: .customGoalML)
        remindersEnabled = try container.decode(Bool.self, forKey: .remindersEnabled)
        wakeMinutes = try container.decode(Int.self, forKey: .wakeMinutes)
        sleepMinutes = try container.decode(Int.self, forKey: .sleepMinutes)
        prefersWeatherGoal = try container.decode(Bool.self, forKey: .prefersWeatherGoal)
        prefersHealthKit = try container.decode(Bool.self, forKey: .prefersHealthKit)
        smartRemindersEnabled = try container.decode(Bool.self, forKey: .smartRemindersEnabled)
        // dailyReminderCount was removed — ignore if present in old data
    }

    static let `default` = UserProfile(
        name: "",
        unitSystem: .metric,
        weightKg: 70,
        activityLevel: .steady,
        customGoalML: nil,
        remindersEnabled: true,
        wakeMinutes: 7 * 60,
        sleepMinutes: 22 * 60,
        prefersWeatherGoal: true,
        prefersHealthKit: true,
        smartRemindersEnabled: true
    )
}

extension UserProfile {
    func applyingPremiumAccess(_ hasPremiumAccess: Bool) -> UserProfile {
        guard !hasPremiumAccess else { return self }

        var copy = self
        copy.prefersWeatherGoal = false
        copy.prefersHealthKit = false
        copy.smartRemindersEnabled = false
        return copy
    }
}
