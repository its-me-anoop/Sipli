import Testing
@testable import Sipli

struct OnboardingVesselModelTests {

    @Test func welcomeFillIsNonZeroFloor() {
        // Welcome reads "waiting to be filled", not broken-empty.
        #expect(OnboardingStep.welcome.fillFraction > 0)
        #expect(OnboardingStep.welcome.fillFraction < 0.1)
    }

    @Test func doneFillIsFull() {
        #expect(OnboardingStep.done.fillFraction == 1.0)
    }

    @Test func fillIsMonotonicNonDecreasing() {
        let steps = OnboardingStep.allCases.sorted { $0.rawValue < $1.rawValue }
        for (a, b) in zip(steps, steps.dropFirst()) {
            #expect(a.fillFraction <= b.fillFraction, "\(a) should not fill more than \(b)")
        }
    }

    @Test func middleStepsUseSeventhsOfTheFlow() {
        #expect(abs(OnboardingStep.name.fillFraction - 1.0/7.0) < 0.0001)
        #expect(abs(OnboardingStep.target.fillFraction - 4.0/7.0) < 0.0001)
        #expect(abs(OnboardingStep.notifications.fillFraction - 6.0/7.0) < 0.0001)
    }

    @Test func weightAndTargetAreCompact() {
        #expect(OnboardingStep.weight.vesselPlacement == .compact)
        #expect(OnboardingStep.target.vesselPlacement == .compact)
    }

    @Test func everyNonCompactStepIsHero() {
        let compactSteps: Set<OnboardingStep> = [.weight, .target]
        for step in OnboardingStep.allCases where !compactSteps.contains(step) {
            #expect(step.vesselPlacement == .hero, "\(step) should be hero")
        }
    }

    @Test func onlyDoneIsComplete() {
        for step in OnboardingStep.allCases {
            #expect(step.isComplete == (step == .done))
        }
    }
}
