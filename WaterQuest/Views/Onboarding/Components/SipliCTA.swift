import SwiftUI

/// Pill-shaped primary CTA with a circular paper-coloured arrow on the trailing edge.
/// Mirrors the `.cta` element from the design's `styles.css`.
struct SipliCTA: View {
    let title: String
    var variant: Variant = .ink
    var disabled: Bool = false
    let action: () -> Void

    enum Variant { case ink, water }

    @State private var pressed = false

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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(titleColor)

                ZStack {
                    Circle()
                        .fill(arrowBg)
                        .frame(width: 28, height: 28)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(arrowFg)
                }
                .offset(x: pressed ? 4 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
            .opacity(disabled ? 0.5 : 1)
            .scaleEffect(pressed && !disabled ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed { withAnimation(.easeOut(duration: 0.12)) { pressed = true } }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.18)) { pressed = false }
                }
        )
    }
}

/// Compact circular back button.
struct SipliBackButton: View {
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            Image(systemName: "arrow.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OnboardingPalette.ink)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(OnboardingPalette.ink.opacity(pressed ? 0.10 : 0.06))
                )
                .scaleEffect(pressed ? 0.92 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed { withAnimation(.easeOut(duration: 0.12)) { pressed = true } }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.18)) { pressed = false }
                }
        )
        .accessibilityLabel("Back")
    }
}

/// Top bar — back button on the left, mono "01 / 07" stepper centered.
struct SipliTopBar: View {
    let stepIndex: Int
    let total: Int
    let canGoBack: Bool
    let onBack: () -> Void

    var body: some View {
        HStack {
            if canGoBack {
                SipliBackButton(action: onBack)
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
            Spacer()
            HStack(spacing: 4) {
                Text(String(format: "%02d", stepIndex + 1))
                    .font(.sipliMono(12, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                Text("/")
                    .font(.sipliMono(12, weight: .medium))
                    .foregroundStyle(OnboardingPalette.ink2.opacity(0.5))
                Text(String(format: "%02d", total))
                    .font(.sipliMono(12, weight: .medium))
                    .foregroundStyle(OnboardingPalette.ink2.opacity(0.55))
            }
            .tracking(1)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(height: 60)
    }
}

/// Custom toggle styled like the design's `.switch` — water-coloured when on.
struct SipliToggle: View {
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
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: isOn)
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
#Preview("CTA + Back + Toggle") {
    VStack(spacing: 18) {
        SipliCTA(title: "Get started", action: {})
        SipliCTA(title: "Continue", variant: .ink, disabled: true, action: {})
        SipliCTA(title: "Start hydrating, friend", variant: .water, action: {})
        HStack { SipliBackButton(action: {}); Spacer(); SipliToggle(isOn: .constant(true)) }
    }
    .padding(24)
    .background(OnboardingPalette.paper)
}
#endif
