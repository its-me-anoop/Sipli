import XCTest
@testable import Sipli

final class OnboardingStateTests: XCTestCase {
    // MARK: - previewDailyGoal

    func test_previewGoal_metricBasic_matchesFormula() {
        let goal = GoalCalculator.previewDailyGoal(
            weightKg: 70,
            activity: .steady,
            customGoalML: nil
        )
        // 70 kg × 35 (steady multiplier) = 2450
        XCTAssertEqual(goal, 2450, accuracy: 0.0001)
    }

    func test_previewGoal_chillVsIntense_differs() {
        let chill = GoalCalculator.previewDailyGoal(weightKg: 70, activity: .chill, customGoalML: nil)
        let intense = GoalCalculator.previewDailyGoal(weightKg: 70, activity: .intense, customGoalML: nil)
        XCTAssertGreaterThan(intense, chill)
        XCTAssertEqual(chill, 70 * 32, accuracy: 0.0001)
        XCTAssertEqual(intense, 70 * 38, accuracy: 0.0001)
    }

    func test_previewGoal_customGoalOverridesBase() {
        let goal = GoalCalculator.previewDailyGoal(
            weightKg: 70,
            activity: .intense,
            customGoalML: 3000
        )
        XCTAssertEqual(goal, 3000, accuracy: 0.0001)
    }

    func test_previewGoal_floorAt1200() {
        let goal = GoalCalculator.previewDailyGoal(
            weightKg: 30,
            activity: .chill,
            customGoalML: nil
        )
        XCTAssertEqual(goal, 1200, accuracy: 0.0001)
    }

    func test_previewGoal_matchesGoalCalculatorWithoutAdjustments() {
        for (kg, activity) in [(50.0, ActivityLevel.chill), (70.0, .steady), (95.0, .intense)] {
            let profile = UserProfile(
                name: "T",
                unitSystem: .metric,
                weightKg: kg,
                activityLevel: activity,
                customGoalML: nil,
                remindersEnabled: true,
                wakeMinutes: 7 * 60,
                sleepMinutes: 22 * 60,
                prefersWeatherGoal: false,
                prefersHealthKit: false,
                smartRemindersEnabled: false
            )
            let real = GoalCalculator.dailyGoal(profile: profile, weather: nil, workout: nil).totalML
            let preview = GoalCalculator.previewDailyGoal(
                weightKg: kg,
                activity: activity,
                customGoalML: nil
            )
            XCTAssertEqual(preview, real, accuracy: 0.0001, "kg=\(kg) activity=\(activity)")
        }
    }

    // MARK: - canContinueFromName

    func test_state_canContinueFromName_emptyName_false() {
        let state = OnboardingState(name: "")
        XCTAssertFalse(state.canContinueFromName)
    }

    func test_state_canContinueFromName_whitespaceName_false() {
        let state = OnboardingState(name: "   \n\t  ")
        XCTAssertFalse(state.canContinueFromName)
    }

    func test_state_canContinueFromName_validName_true() {
        let state = OnboardingState(name: "Anoop")
        XCTAssertTrue(state.canContinueFromName)
    }

    // MARK: - State conversions

    func test_state_weightKg_metricPassthrough() {
        let state = OnboardingState(unitSystem: .metric, weight: 75)
        XCTAssertEqual(state.weightKg, 75, accuracy: 0.0001)
    }

    func test_state_weightKg_imperialConverts() {
        let state = OnboardingState(unitSystem: .imperial, weight: 154)
        XCTAssertEqual(state.weightKg, UnitSystem.imperial.kg(from: 154), accuracy: 0.0001)
    }

    func test_state_customGoalML_disabled_isNil() {
        let state = OnboardingState(customGoalEnabled: false, customGoalValue: 2200)
        XCTAssertNil(state.customGoalML)
    }

    func test_state_customGoalML_enabledMetric() {
        let state = OnboardingState(unitSystem: .metric, customGoalEnabled: true, customGoalValue: 2500)
        XCTAssertEqual(state.customGoalML ?? -1, 2500, accuracy: 0.0001)
    }

    func test_state_livePreviewGoalML_combinesWeightAndActivity() {
        let state = OnboardingState(
            unitSystem: .metric,
            weight: 80,
            activityLevel: .intense,
            customGoalEnabled: false
        )
        XCTAssertEqual(state.livePreviewGoalML, 80 * 38, accuracy: 0.0001)
    }

    // MARK: - Awake hours

    func test_state_awakeHours_normalDay() {
        let state = OnboardingState(wakeHour: 7, sleepHour: 22)
        XCTAssertEqual(state.awakeHours, 15, accuracy: 0.0001)
    }

    func test_state_awakeHours_overnight() {
        let state = OnboardingState(wakeHour: 22, sleepHour: 6)
        XCTAssertEqual(state.awakeHours, 8, accuracy: 0.0001)
    }

    func test_state_wakeMinutes_correctConversion() {
        let state = OnboardingState(wakeHour: 6.5)
        XCTAssertEqual(state.wakeMinutes, 6 * 60 + 30)
    }

    // MARK: - Step navigation

    func test_step_next_fromWelcome_returnsName() {
        XCTAssertEqual(OnboardingStep.welcome.next(), .name)
    }

    func test_step_next_fromDone_returnsNil() {
        XCTAssertNil(OnboardingStep.done.next())
    }

    func test_step_previous_fromWelcome_returnsNil() {
        XCTAssertNil(OnboardingStep.welcome.previous())
    }

    func test_step_displayedTotal_isSeven() {
        XCTAssertEqual(OnboardingStep.displayedTotal, 7)
    }

    func test_step_count_isEight() {
        XCTAssertEqual(OnboardingStep.count, 8)
    }

    // MARK: - Cadence

    func test_cadence_defaultIsSteady() {
        let state = OnboardingState()
        XCTAssertEqual(state.cadence, .steady)
    }

    func test_cadence_dailyCounts() {
        XCTAssertEqual(ReminderCadence.gentle.dailyCount, 4)
        XCTAssertEqual(ReminderCadence.steady.dailyCount, 8)
        XCTAssertEqual(ReminderCadence.intense.dailyCount, 12)
    }

    // MARK: - Answer chips

    func test_answerChips_atWelcome_returnsEmpty() {
        let state = OnboardingState(name: "Maya")
        XCTAssertTrue(state.answerChips(upTo: .welcome).isEmpty)
    }

    func test_answerChips_atWeight_includesNameOnly() {
        let state = OnboardingState(name: "Maya")
        let chips = state.answerChips(upTo: .weight)
        XCTAssertEqual(chips.count, 1)
        XCTAssertEqual(chips.first?.id, "name")
        XCTAssertEqual(chips.first?.value, "Maya")
    }

    func test_answerChips_atTarget_includesAllPriorAnswers() {
        let state = OnboardingState(name: "Maya", weight: 70, activityLevel: .steady)
        let chips = state.answerChips(upTo: .target)
        XCTAssertEqual(chips.map(\.id), ["name", "weight", "activity"])
    }
}
