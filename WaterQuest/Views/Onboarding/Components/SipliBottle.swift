import SwiftUI

/// Onboarding bottle — uses the existing dashboard `LiquidProgressView`
/// which masks animated water inside the real `bottle` asset PNG. The fill
/// argument controls the water level (0…1).
struct SipliBottle: View {
    var fill: Double = 0.6
    var size: CGFloat = 220
    /// Currently unused — `LiquidProgressView` always animates internally,
    /// honouring `accessibilityReduceMotion`. Kept for API parity with the
    /// HTML prototype's call sites.
    var animated: Bool = true

    var body: some View {
        LiquidProgressView(
            progress: clampedFill,
            compositions: [FluidComposition(type: .water, proportion: 1.0)],
            isRegular: false,
            bottleWidth: size,
            bottleHeight: size * 1.36,
            showProgressLabel: false
        )
        .accessibilityHidden(true)
    }

    private var clampedFill: Double {
        max(0, min(1, fill))
    }
}

/// Brand mark — uses the actual app icon asset.
struct SipliMark: View {
    var size: CGFloat = 24
    var animated: Bool = false

    var body: some View {
        Image("sipliIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("SipliBottle — multiple fills") {
    HStack(spacing: 18) {
        SipliBottle(fill: 0.10, size: 90)
        SipliBottle(fill: 0.40, size: 90)
        SipliBottle(fill: 0.62, size: 90)
        SipliBottle(fill: 0.95, size: 90)
    }
    .padding()
    .background(OnboardingPalette.paper)
}

#Preview("SipliMark sizes") {
    HStack(spacing: 18) {
        SipliMark(size: 22)
        SipliMark(size: 36)
        SipliMark(size: 64)
    }
    .padding()
    .background(OnboardingPalette.paper)
}
#endif
