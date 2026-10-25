import SwiftUI

/// Where the persistent onboarding vessel sits for a given step.
/// `.hero` = tall and central (light steps); `.compact` = small, in the
/// header strip so input-heavy steps keep their vertical space.
enum VesselPlacement: Equatable {
    case hero
    case compact
}

enum OnboardingStep: Int, CaseIterable, Equatable {
    case welcome      // 0
    case name         // 1
    case weight       // 2
    case activity     // 3
    case target       // 4
    case schedule     // 5
    case notifications // 6
    case done         // 7

    var index: Int { rawValue }
    /// Total *displayed* steps in the stepper — the "01 / 07" indicator excludes the Done celebration.
    static var displayedTotal: Int { 7 }
    static var count: Int { allCases.count }

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    func previous() -> OnboardingStep? {
        guard rawValue > 0 else { return nil }
        return OnboardingStep(rawValue: rawValue - 1)
    }
}

enum OnboardingNavDirection {
    case forward
    case backward
}

private struct OnboardingQuestionInHeroKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var onboardingQuestionInHero: Bool {
        get { self[OnboardingQuestionInHeroKey.self] }
        set { self[OnboardingQuestionInHeroKey.self] = newValue }
    }
}

extension OnboardingStep {
    var hasQuestion: Bool { self != .welcome && self != .done }
}

/// Shared question copy lets the coordinator move the question alongside the
/// bottle on a split display without duplicating it in the answer pane.
struct OnboardingQuestion: View {
    let step: OnboardingStep
    var fontSize: CGFloat = 40

    private var copy: (String, String) {
        switch step {
        case .name: ("What should we\n", "call you?")
        case .weight: ("You weigh\n", "about how much?")
        case .activity: ("How active\n", "is your average day?")
        case .target: ("Pour the perfect\n", "daily amount.")
        case .schedule: ("When are you\n", "awake?")
        case .notifications: ("How loud\nshould we ", "nudge?")
        case .welcome, .done: ("", "")
        }
    }

    var body: some View {
        (Text(copy.0).foregroundStyle(OnboardingPalette.ink)
            + Text(copy.1).italic().foregroundStyle(OnboardingPalette.water))
            .font(.editorialSerif(fontSize, relativeTo: .largeTitle))
            .lineSpacing(-2)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Reflows the same controls without duplicating their state or keyboard focus.
struct OnboardingAnswerLayout: Layout {
    var minimumColumnWidth: CGFloat = 240
    var spacing: CGFloat = 24

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minimumColumnWidth * 2 + spacing
        let columns = width >= minimumColumnWidth * 2 + spacing
        let childWidth = columns ? (width - spacing) / 2 : width
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: childWidth, height: nil)) }
        return CGSize(width: width, height: columns ? (sizes.map(\.height).max() ?? 0)
                      : sizes.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, sizes.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = bounds.width >= minimumColumnWidth * 2 + spacing
        let childWidth = columns ? (bounds.width - spacing) / 2 : bounds.width
        var y = bounds.minY
        for (index, subview) in subviews.enumerated() {
            let childProposal = ProposedViewSize(width: childWidth, height: nil)
            let size = subview.sizeThatFits(childProposal)
            subview.place(at: CGPoint(x: columns ? bounds.minX + CGFloat(index) * (childWidth + spacing) : bounds.minX,
                                     y: columns ? bounds.midY - size.height / 2 : y),
                          anchor: .topLeading, proposal: childProposal)
            if !columns { y += size.height + spacing }
        }
    }
}

/// Answer chip displayed in the AnswerChipStack at the top of subsequent steps.
struct OnboardingAnswerChip: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
}

extension OnboardingStep {
    /// Fraction of the vessel filled while this step is on screen.
    /// Welcome floors at a small non-zero level so the empty bottle reads as
    /// "waiting"; each step pours one measure; Done brims full.
    var fillFraction: Double {
        if self == .welcome { return 0.04 }
        return min(1.0, Double(rawValue) / Double(OnboardingStep.displayedTotal))
    }

    /// Placement of the persistent vessel for this step.
    var vesselPlacement: VesselPlacement {
        switch self {
        case .weight, .target: return .compact
        default: return .hero
        }
    }

    /// True only on the celebration step — drives the vessel's completion accent.
    var isComplete: Bool { self == .done }
}

extension OnboardingState {
    /// Build the chip stack of previous answers, capped at `step`'s position.
    func answerChips(upTo step: OnboardingStep) -> [OnboardingAnswerChip] {
        var chips: [OnboardingAnswerChip] = []
        let s = step.rawValue
        if s > 1, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chips.append(.init(id: "name", label: "NAME", value: name))
        }
        if s > 2 {
            let formatted = "\(Int(weight)) \(unitSystem.bodyWeightUnit)"
            chips.append(.init(id: "weight", label: "WEIGHT", value: formatted))
        }
        if s > 3 {
            chips.append(.init(id: "activity", label: "ACTIVITY", value: activityLevel.label))
        }
        if s > 4 {
            chips.append(.init(id: "target", label: "DAILY TARGET", value: formattedTarget()))
        }
        if s > 5 {
            chips.append(.init(id: "awake", label: "AWAKE", value: "\(formatHour(wakeHour)) – \(formatHour(sleepHour))"))
        }
        return chips
    }

    private func formattedTarget() -> String {
        let ml = displayedTargetML
        switch unitSystem {
        case .metric:
            return String(format: "%.1f L", ml / 1000.0)
        case .imperial:
            let oz = unitSystem.amount(fromML: ml)
            return "\(Int(oz)) oz"
        }
    }

    func formatHour(_ hour: Double) -> String {
        let hr = Int(floor(hour))
        let m = Int(round((hour - Double(hr)) * 60.0))
        let normalisedH = (hr + (m == 60 ? 1 : 0)) % 24
        let normalisedM = m == 60 ? 0 : m
        let ampm = normalisedH >= 12 ? "pm" : "am"
        let h12 = ((normalisedH % 12) == 0) ? 12 : (normalisedH % 12)
        return normalisedM == 0 ? "\(h12)\(ampm)" : "\(h12):\(String(format: "%02d", normalisedM))\(ampm)"
    }
}
