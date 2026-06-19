import SwiftUI

/// The single persistent onboarding bottle. One instance is owned by
/// `OnboardingView` and reused across every step so the water level animates
/// continuously. Wraps `LiquidProgressView` (masked-bottle liquid renderer).
///
/// The bottle gently floats while idle (honouring Reduce Motion) so the screen
/// feels alive, and its `size` can be driven dynamically by the coordinator so
/// the bottle shrinks to fit smaller screens without ever overlapping content.
struct OnboardingVessel: View {
    var fill: Double
    var placement: VesselPlacement
    var isComplete: Bool = false
    /// Explicit bottle art width. When nil, falls back to a per-placement
    /// default. Height always follows the asset's 1.36 ratio.
    var size: CGFloat? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob: CGFloat = 0

    private var width: CGFloat {
        if let size { return size }
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
        .scaleEffect(isComplete && !reduceMotion ? 1.06 : 1.0)
        .offset(y: bob)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isComplete)
        .accessibilityHidden(true)
        .onAppear { startBob() }
    }

    /// Gentle perpetual float so the vessel feels alive between steps.
    private func startBob() {
        guard !reduceMotion, bob == 0 else { return }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            bob = -7
        }
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
