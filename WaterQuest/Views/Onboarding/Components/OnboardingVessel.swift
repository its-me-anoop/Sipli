import SwiftUI

/// The single persistent onboarding bottle. One instance is owned by
/// `OnboardingView` and reused across every step so the water level animates
/// continuously. Wraps `LiquidProgressView` (masked-bottle liquid renderer).
struct OnboardingVessel: View {
    var fill: Double
    var placement: VesselPlacement
    var isComplete: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Bottle art width per placement. Height follows the asset's 1.36 ratio.
    private var width: CGFloat {
        switch placement {
        case .hero: return 168
        case .compact: return 72
        }
    }

    var body: some View {
        ZStack {
            completionGlow
            LiquidProgressView(
                progress: max(0, min(1, fill)),
                compositions: [FluidComposition(type: .water, proportion: 1.0)],
                isRegular: false,
                bottleWidth: width,
                bottleHeight: width * 1.36,
                showProgressLabel: false
            )
        }
        .frame(width: width, height: width * 1.36)
        .scaleEffect(isComplete && !reduceMotion ? 1.04 : 1.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isComplete)
        .accessibilityHidden(true)
    }

    /// A soft green halo behind the bottle at completion — the celebratory
    /// accent. The water itself stays blue; Done's confetti carries the colour.
    @ViewBuilder
    private var completionGlow: some View {
        if isComplete {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [OnboardingPalette.Bottle.green.opacity(0.45), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: width * 1.1
                    )
                )
                .frame(width: width * 2.2, height: width * 2.2)
                .blur(radius: 12)
        }
    }
}

#if DEBUG
#Preview("OnboardingVessel — placements & fills") {
    HStack(alignment: .bottom, spacing: 24) {
        OnboardingVessel(fill: 0.04, placement: .hero)
        OnboardingVessel(fill: 0.57, placement: .compact)
        OnboardingVessel(fill: 1.0, placement: .hero, isComplete: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(OnboardingPalette.paper)
}
#endif
