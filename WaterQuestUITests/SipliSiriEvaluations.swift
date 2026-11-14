// Siri Evaluations (iOS 27.3 Siri AI Developer Preview): scripted requests
// that check which Sipli tools Siri calls, with which values, and which app
// skills it loads. Only compiles where the SiriEvaluations framework exists
// (Xcode 27.3 beta and later).
//
// Running these:
// - Use a physical device that supports Apple Intelligence, set to a
//   supported language, with Developer Mode and Settings > Developer >
//   Enable UI Automation on. Siri AI isn't available in the Simulator.
// - The app must be signed by the same team as this test target.
// - Requests really run: the logging scenarios add drinks to the device's
//   Sipli data. Use a test device or account, not your personal log.
// - Siri's answers vary between runs. Run the suite more than once and treat
//   the metrics as a trend; improve intent and parameter descriptions or the
//   skills in WaterQuest/Skills.skillsbundle until they pass consistently.
#if canImport(SiriEvaluations)
import AppIntentsTesting
import Evaluations
import Foundation
import SiriEvaluations
import Testing
import XCTest

/// One evaluation type for every Sipli scenario; each test passes its own
/// name and dataset.
@available(iOS 27.3, *)
struct SipliSiriEvaluation: Evaluation {
    let name: String
    let dataset: SiriScenarioLoader
    /// Foregrounds Sipli before each scenario, so requests can leave out
    /// the app name the way people do while using the app.
    var launchesApp = false

    func subject(from sample: SiriScenario) async throws -> SiriScenarioSubject {
        if launchesApp {
            await launchSipli()
        }
        return try await SiriService.run(scenario: sample)
    }

    var evaluators: Evaluators {
        SiriExpectationEvaluator()
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        Self.computeSiriMetrics(into: &aggregator)
    }
}

@available(iOS 27.3, *)
enum SipliSiri {
    static let definitions = IntentDefinitions(bundleIdentifier: "com.waterquest.hydration")

    // Tools
    static let logWater = definitions.intents["LogWaterIntent"]
    static let logDrink = definitions.intents["LogDrinkIntent"]
    static let logAmount = definitions.intents["LogAmountIntent"]
    static let logDrinks = definitions.intents["LogDrinksIntent"]
    static let repeatLast = definitions.intents["RepeatLastDrinkIntent"]
    static let todaysHydration = definitions.intents["GetTodaysHydrationIntent"]
    static let remaining = definitions.intents["GetRemainingIntent"]
    static let streak = definitions.intents["GetStreakIntent"]
    static let findDrinks = definitions.intents["FindDrinksIntent"]
    static let updateDrink = definitions.intents["UpdateDrinkIntent"]
    static let deleteDrink = definitions.intents["DeleteDrinkIntent"]
    static let undoLast = definitions.intents["UndoLastIntakeIntent"]
    static let setGoal = definitions.intents["SetDailyGoalIntent"]

    // Skills (WaterQuest/Skills.skillsbundle)
    static let logDrinksSkill = definitions.skills["log-drinks"]
    static let checkInSkill = definitions.skills["hydration-check-in"]
    static let fixLogSkill = definitions.skills["fix-drink-log"]
}

@MainActor
private func launchSipli() {
    let app = XCUIApplication(bundleIdentifier: "com.waterquest.hydration")
    app.launchArguments += ["-hasOnboarded", "YES", "-spookySeason2026InvitePrompted", "YES"]
    app.launch()
}

// MARK: - Questions (read-only)

@available(iOS 27.3, *)
@Test(
    .evaluates(SipliSiriEvaluation(
        name: "Hydration questions",
        dataset: SiriScenarioLoader {
            SiriScenario {
                UserTurn("How much water have I had today in Sipli?") {
                    Calls { SipliSiri.todaysHydration }
                    Calls(.disallowed) {
                        SipliSiri.logWater
                        SipliSiri.logDrinks
                    }
                }
            }
            SiriScenario {
                UserTurn("Am I on track with my water in Sipli?") {
                    Calls(.unordered) { SipliSiri.remaining }
                    Loads(.preferred) { SipliSiri.checkInSkill }
                }
            }
            SiriScenario {
                UserTurn("What's my streak in Sipli?") {
                    Calls { SipliSiri.streak }
                }
            }
            SiriScenario {
                UserTurn("What did I drink yesterday in Sipli?") {
                    Calls { SipliSiri.findDrinks }
                    Calls(.disallowed) { SipliSiri.todaysHydration }
                }
            }
            SiriScenario {
                UserTurn("How much coffee did I have this week in Sipli?") {
                    Calls {
                        SipliSiri.findDrinks
                            .expect(drink: .equals("coffee"))
                    }
                }
            }
        }
    ))
)
func hydrationQuestions() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: .intentsAllPass)) >= 0.8)
}

// MARK: - Logging (writes drinks)

@available(iOS 27.3, *)
@Test(
    .evaluates(SipliSiriEvaluation(
        name: "Logging drinks",
        dataset: SiriScenarioLoader {
            SiriScenario {
                UserTurn("Log a latte in Sipli") {
                    Calls { SipliSiri.logDrink }
                    Calls(.disallowed) { SipliSiri.deleteDrink }
                }
            }
            SiriScenario {
                UserTurn("In Sipli, I had two coffees and a glass of water this morning") {
                    Calls { SipliSiri.logDrinks }
                    Loads(.preferred) { SipliSiri.logDrinksSkill }
                }
            }
            SiriScenario {
                UserTurn("Same again in Sipli") {
                    Calls { SipliSiri.repeatLast }
                }
            }
        }
    ))
)
func loggingDrinks() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: .intentsAllPass)) >= 0.8)
}

// MARK: - Fixing the log and the goal (foreground, no app name)

@available(iOS 27.3, *)
@Test(
    .evaluates(SipliSiriEvaluation(
        name: "Fixing the log",
        dataset: SiriScenarioLoader {
            // Correction right after logging changes the drink, never logs another.
            SiriScenario {
                UserTurn("Log 300 ml of latte")
                UserTurn("Actually it was 400 ml") {
                    Calls {
                        SipliSiri.updateDrink
                            .expect(amountML: .matches(#Predicate<Int> { $0 == 400 }))
                    }
                    Calls(.disallowed) {
                        SipliSiri.logWater
                        SipliSiri.logAmount
                        SipliSiri.logDrinks
                    }
                }
            }
            SiriScenario {
                UserTurn("Undo my last drink") {
                    Calls { SipliSiri.undoLast }
                    Calls(.disallowed) { SipliSiri.deleteDrink }
                }
            }
            SiriScenario {
                UserTurn("Set my goal to 2.5 litres") {
                    Calls {
                        SipliSiri.setGoal
                            .expect(goalML: .matches(#Predicate<Int> { $0 == 2500 }))
                    }
                }
            }
        },
        launchesApp: true
    ))
)
func fixingTheLog() async throws {
    let result = EvaluationContext.current.result
    #expect(result.aggregateValue(.mean(of: .intentsAllPass)) >= 0.8)
}
#endif
