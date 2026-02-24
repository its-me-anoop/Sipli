import Foundation
import SwiftUI

// MARK: - Hydration Tip Model
struct HydrationTip: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let category: Category
    let generatedAt: Date

    enum Category {
        case tip, reminder, encouragement, celebration

        var icon: String {
            switch self {
            case .tip: return "lightbulb.fill"
            case .reminder: return "bell.fill"
            case .encouragement: return "hands.clap.fill"
            case .celebration: return "party.popper.fill"
            }
        }

        var color: Color {
            switch self {
            case .tip: return Theme.lagoon
            case .reminder: return Theme.coral
            case .encouragement: return Theme.mint
            case .celebration: return Theme.sun
            }
        }

        var label: String {
            switch self {
            case .tip: return "Hydration Tip"
            case .reminder: return "Reminder"
            case .encouragement: return "Keep Going!"
            case .celebration: return "Goal Reached!"
            }
        }
    }
}

// MARK: - Time of Day
enum TimeOfDay: String {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"

    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
}

// MARK: - Hydration AI Service
/// Provides AI-powered hydration tips and insights using Apple's on-device Foundation Models
@MainActor
final class HydrationAIService: ObservableObject {
    @Published private(set) var currentTip: HydrationTip?
    @Published private(set) var isGenerating = false
    @Published private(set) var isAvailable = false
    @Published private(set) var errorMessage: String?

    init() {
        checkAvailability()
        // Generate initial tip
        Task {
            await generateTip(
                currentIntake: 0,
                goalML: 2000,
                weatherTemp: nil,
                exerciseMinutes: 0,
                timeOfDay: TimeOfDay.current
            )
        }
    }

    // MARK: - Availability Check
    func checkAvailability() {
        // FoundationModels requires iOS 26+
        // For now, we'll use static tips and the AI features will be available when iOS 26 ships
        isAvailable = false
        errorMessage = nil
    }

    // MARK: - Generate Hydration Tip
    func generateTip(
        currentIntake: Double,
        goalML: Double,
        weatherTemp: Double?,
        exerciseMinutes: Int,
        timeOfDay: TimeOfDay
    ) async {
        isGenerating = true

        // Use contextual static tips (AI integration ready for iOS 26)
        let progress = goalML > 0 ? Int((currentIntake / goalML) * 100) : 0

        withAnimation(Theme.fluidSpring) {
            currentTip = getContextualTip(
                progress: progress,
                weatherTemp: weatherTemp,
                exerciseMinutes: exerciseMinutes,
                timeOfDay: timeOfDay
            )
        }

        isGenerating = false
    }

    // MARK: - Generate Motivational Message
    func generateMotivation(for achievement: String) async -> String? {
        // Returns nil until iOS 26 Foundation Models are available
        return nil
    }

    // MARK: - Private Helpers
    private func getContextualTip(
        progress: Int,
        weatherTemp: Double?,
        exerciseMinutes: Int,
        timeOfDay: TimeOfDay
    ) -> HydrationTip {
        let category = categorize(progress: progress, timeOfDay: timeOfDay)
        let message = selectMessage(
            category: category,
            progress: progress,
            weatherTemp: weatherTemp,
            exerciseMinutes: exerciseMinutes,
            timeOfDay: timeOfDay
        )

        return HydrationTip(
            message: message,
            category: category,
            generatedAt: Date()
        )
    }

    private func categorize(progress: Int, timeOfDay: TimeOfDay) -> HydrationTip.Category {
        if progress >= 100 {
            return .celebration
        } else if progress < 30 && (timeOfDay == .afternoon || timeOfDay == .evening) {
            return .reminder
        } else if progress >= 70 {
            return .encouragement
        } else {
            return .tip
        }
    }

    private func selectMessage(
        category: HydrationTip.Category,
        progress: Int,
        weatherTemp: Double?,
        exerciseMinutes: Int,
        timeOfDay: TimeOfDay
    ) -> String {
        switch category {
        case .celebration:
            return celebrationMessages.randomElement() ?? "Amazing! You've hit your goal!"

        case .reminder:
            if let temp = weatherTemp, temp > 25 {
                return hotWeatherReminders.randomElement() ?? "It's warm out there - drink up!"
            }
            if exerciseMinutes > 30 {
                return exerciseReminders.randomElement() ?? "After that workout, your body needs water!"
            }
            return generalReminders[timeOfDay]?.randomElement() ?? "Time for a hydration break!"

        case .encouragement:
            return generalEncouragements.randomElement() ?? "You're doing great! Almost there!"

        case .tip:
            return getTipForContext(timeOfDay: timeOfDay, weatherTemp: weatherTemp, exerciseMinutes: exerciseMinutes)
        }
    }

    private func getTipForContext(timeOfDay: TimeOfDay, weatherTemp: Double?, exerciseMinutes: Int) -> String {
        if let temp = weatherTemp, temp > 28 {
            return hotWeatherTips.randomElement() ?? "Hot day! Aim for extra water intake."
        }

        if exerciseMinutes > 0 {
            return exerciseTips.randomElement() ?? "Great workout! Replenish those fluids."
        }

        return generalTips[timeOfDay]?.randomElement() ?? "Stay hydrated!"
    }

    // MARK: - Message Collections
    private let celebrationMessages = [
        "Goal crushed! You're a hydration champion!",
        "100% complete! Your body thanks you!",
        "Amazing work! You've mastered hydration today!",
        "Victory! You've conquered your water goal!",
        "Incredible! Full hydration achieved!"
    ]

    private let hotWeatherReminders = [
        "The heat is on! Your body needs extra fluids.",
        "Warm weather alert! Time to top up on water.",
        "Hot day = more water needed. Let's go!",
        "Beat the heat with a refreshing drink!"
    ]

    private let exerciseReminders = [
        "Post-workout hydration is key to recovery!",
        "Your muscles are thirsty after that exercise!",
        "Replenish what you sweated out - drink up!",
        "Active day? Your body needs extra water!"
    ]

    private let generalReminders: [TimeOfDay: [String]] = [
        .morning: [
            "Morning reminder: Start your day with water!",
            "Your body is ready for hydration!",
            "A glass of water helps wake you up!"
        ],
        .afternoon: [
            "Afternoon check-in: How's your water intake?",
            "Midday is prime hydration time!",
            "Don't let the afternoon slump catch you - drink water!"
        ],
        .evening: [
            "Evening reminder: Still time to hit your goal!",
            "Wind down with some water.",
            "A few more glasses before bedtime!"
        ],
        .night: [
            "Night hydration helps your body recover.",
            "A small sip before sleep is beneficial!",
            "End your day on a hydrated note."
        ]
    ]

    private let generalEncouragements = [
        "You're so close to your goal! Keep going!",
        "Fantastic progress! The finish line is near!",
        "You've got this! Just a bit more to go!",
        "Impressive! You're making waves today!"
    ]

    private let hotWeatherTips = [
        "Hot weather tip: Add a slice of lemon for a refreshing twist!",
        "When it's warm, try to sip water every 15-20 minutes.",
        "Room temperature water absorbs faster on hot days.",
        "Set reminders during heat waves to stay on track!"
    ]

    private let exerciseTips = [
        "Pro tip: Drink water 30 minutes before and after exercise.",
        "For every hour of exercise, aim for an extra 16oz of water.",
        "Feeling fatigued? It might be dehydration from your workout!",
        "Electrolytes are great, but don't forget plain water too!"
    ]

    private let generalTips: [TimeOfDay: [String]] = [
        .morning: [
            "Start with a glass of water before your coffee!",
            "Morning hydration kickstarts your metabolism.",
            "Your body dehydrates overnight - time to refuel!",
            "Pro tip: Keep a water bottle by your bed."
        ],
        .afternoon: [
            "Feeling tired? Often it's actually thirst in disguise!",
            "A glass before lunch helps with digestion.",
            "Afternoon slump? Water can boost your energy!",
            "Keep water visible on your desk as a reminder."
        ],
        .evening: [
            "Hydrate before dinner for better digestion.",
            "Evening is a great time to catch up on your goal!",
            "Herbal tea counts toward your water intake too!",
            "Set a goal to finish a bottle before sunset."
        ],
        .night: [
            "A small amount of water before bed aids recovery.",
            "Don't overdo it at night to avoid disrupting sleep.",
            "Reflect on your day's hydration achievements!",
            "Tomorrow is a new day for hydration goals!"
        ]
    ]
}
