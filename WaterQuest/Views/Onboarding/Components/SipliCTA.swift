import SwiftUI

/// Pill-shaped primary CTA with a circular paper-coloured arrow on the trailing edge.
/// Mirrors the `.cta` element from the design's `styles.css`.
struct SipliCTA: View {
    let title: String
    var variant: Variant = .ink
    var disabled: Bool = false
    let action: () -> Void

    enum Variant { case ink, water }


    private var background: Color {
        switch variant {
        case .ink: return OnboardingPalette.ink
        case .water: return OnboardingPalette.water
        }
    }
    private var titleColor: Color {
        switch variant {
        case .ink: return OnboardingPalette.paper
        case .water: return Color.white
        }
    }
    private var arrowBg: Color {
        switch variant {
        case .ink: return OnboardingPalette.paper
        case .water: return Color.white
        }
    }
    private var arrowFg: Color {
        switch variant {
        case .ink: return OnboardingPalette.ink
        case .water: return OnboardingPalette.water
        }
    }

    var body: some View {
        Button(action: {
            guard !disabled else { return }
            Haptics.impact(.medium)
            action()
        }) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(titleColor)

                ZStack {
                    Circle()
                        .fill(arrowBg)
                        .frame(width: 28, height: 28)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(arrowFg)
                }
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(SipliPressStyle())
        .disabled(disabled)
    }
}

/// Custom toggle styled like the design's `.switch` — water-coloured when on.
struct SipliToggle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isOn: Bool
    var tint: Color = OnboardingPalette.water
    var onToggle: ((Bool) -> Void)? = nil

    var body: some View {
        Capsule()
            .fill(isOn ? tint : OnboardingPalette.ink.opacity(0.18))
            .frame(width: 44, height: 26)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .padding(.horizontal, 3)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }
            .animation(reduceMotion ? nil : Theme.quickSpring, value: isOn)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                isOn.toggle()
                Haptics.selection()
                onToggle?(isOn)
            }
            .accessibilityRepresentation { Toggle("", isOn: $isOn) }
    }
}

#if DEBUG
#Preview("CTA + Toggle") {
    VStack(spacing: 18) {
        SipliCTA(title: "Get started", action: {})
        SipliCTA(title: "Continue", variant: .ink, disabled: true, action: {})
        SipliCTA(title: "Start hydrating, friend", variant: .water, action: {})
        HStack { Spacer(); SipliToggle(isOn: .constant(true)) }
    }
    .padding(24)
    .background(OnboardingPalette.paper)
}
#endif
