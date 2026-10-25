import Testing
import CoreGraphics
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

/// Regression coverage for the geometry shared by settings, editors, and plans.
struct FoldPaneGeometryTests {
    @Test func unfoldedColumnIsCenteredAndCapped() {
        let pane = FoldResolver.singlePane(in: CGSize(width: 1000, height: 400), division: nil)
        #expect(pane == CGRect(x: 190, y: 0, width: 620, height: 400))
    }

    @Test func bookFoldTakesPrecedenceOverWideLandscape() {
        let fold = FoldDivision(frame: CGRect(x: 480, y: 0, width: 24, height: 400))
        let pane = FoldResolver.singlePane(in: CGSize(width: 1000, height: 400), division: fold)
        #expect(pane == CGRect(x: 504, y: 0, width: 496, height: 400))
        #expect(!pane.intersects(fold.frame))
    }

    @Test func tabletopUsesRoomierBottomPane() {
        let fold = FoldDivision(frame: CGRect(x: 0, y: 240, width: 700, height: 24))
        let pane = FoldResolver.singlePane(in: CGSize(width: 700, height: 600), division: fold)
        #expect(pane == CGRect(x: 40, y: 264, width: 620, height: 336))
        #expect(!pane.intersects(fold.frame))
    }

    @Test func tabletopCanUseTopPaneWithKeyboardBelow() {
        let fold = FoldDivision(frame: CGRect(x: 0, y: 300, width: 700, height: 24))
        let pane = FoldResolver.singlePane(in: CGSize(width: 700, height: 400), division: fold)
        #expect(pane == CGRect(x: 40, y: 0, width: 620, height: 300))
    }

    @Test func clippedFoldEdgeKeepsItsOriginalAxis() {
        let fold = FoldDivision(frame: CGRect(x: 100, y: 0, width: 24, height: 8), axis: .vertical)
        let pane = FoldResolver.singlePane(in: CGSize(width: 300, height: 8), division: fold)
        #expect(pane == CGRect(x: 124, y: 0, width: 176, height: 8))
    }
}
