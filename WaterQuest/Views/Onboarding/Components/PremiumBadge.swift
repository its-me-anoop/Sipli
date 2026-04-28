import SwiftUI

/// Small "Premium" pill that replaces a toggle when the user lacks
/// subscription access. Sun-coloured to match the AI-calibrated badge.
struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text("Premium")
                .font(.sipliMono(11, weight: .semibold))
                .tracking(0.4)
        }
        .foregroundStyle(OnboardingPalette.sun)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(OnboardingPalette.ink))
        .accessibilityLabel("Premium")
    }
}

/// Convenience wrapper that swaps between a real toggle and a tap-to-open
/// paywall pill based on `isPremium`.
struct PremiumGatedToggle: View {
    @Binding var isOn: Bool
    let isPremium: Bool
    var tint: Color = OnboardingPalette.water
    let onPaywall: () -> Void
    var onToggle: ((Bool) -> Void)? = nil

    var body: some View {
        if isPremium {
            SipliToggle(isOn: $isOn, tint: tint, onToggle: onToggle)
        } else {
            Button(action: onPaywall) {
                PremiumBadge()
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        PremiumBadge()
        PremiumGatedToggle(
            isOn: .constant(false),
            isPremium: false,
            onPaywall: {}
        )
        PremiumGatedToggle(
            isOn: .constant(true),
            isPremium: true,
            onPaywall: {}
        )
    }
    .padding(24)
    .background(OnboardingPalette.paper)
}
#endif
