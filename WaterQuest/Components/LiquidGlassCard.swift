import SwiftUI

// MARK: - Liquid Glass Card
/// A card component with Liquid Glass effects and fluid animations
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 24
    var tintColor: Color? = nil
    var isInteractive: Bool = true

    init(
        cornerRadius: CGFloat = 24,
        tintColor: Color? = nil,
        isInteractive: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.isInteractive = isInteractive
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(
                shape
                    .fill(Theme.card)
                    .overlay(shape.fill((tintColor ?? Theme.glassAccent).opacity(0.10)))
            )
            .opacity(isInteractive ? 1 : 0.98)
        .clipShape(shape)
        .shadow(color: Theme.shadowColor.opacity(0.65), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Liquid Glass Button
/// A button with Liquid Glass styling and haptic feedback
struct LiquidGlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var style: ButtonStyle = .primary
    var size: ButtonSize = .medium

    @State private var isPressed = false

    enum ButtonStyle {
        case primary, secondary, accent

        var tintColor: Color {
            switch self {
            case .primary: return Theme.lagoon
            case .secondary: return Theme.glassLight
            case .accent: return Theme.mint
            }
        }

        var textColor: Color {
            switch self {
            case .primary, .accent: return Color.white.opacity(0.95)
            case .secondary: return Theme.textPrimary
            }
        }

        var borderColor: Color {
            switch self {
            case .primary: return Theme.lagoon.opacity(0.45)
            case .secondary: return Color.clear
            case .accent: return Theme.mint.opacity(0.45)
            }
        }

        var shadowColor: Color {
            switch self {
            case .primary: return Theme.lagoon.opacity(0.30)
            case .secondary: return Theme.shadowColor.opacity(0.65)
            case .accent: return Theme.mint.opacity(0.26)
            }
        }
    }

    enum ButtonSize {
        case small, medium, large

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            case .medium: return EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            case .large: return EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 28)
            }
        }

        var textStyle: Font.TextStyle {
            switch self {
            case .small: return .footnote
            case .medium: return .subheadline
            case .large: return .body
            }
        }
    }

    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: {
            Haptics.impact(.medium)
            action()
        }) {
            HStack(spacing: 8) {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.system(size.textStyle, design: .default).weight(.semibold))
                }
                Text(title)
                    .font(Theme.bodyFont(size.textStyle))
                    .fontWeight(.medium)
            }
            .foregroundStyle(style.textColor)
            .padding(size.padding)
            .background(
                Capsule()
                    .fill(style.tintColor)
                    .overlay(
                        Capsule()
                            .strokeBorder(style.borderColor, lineWidth: 1)
                    )
            )
            .shadow(color: style.shadowColor, radius: 10, x: 0, y: 5)
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(Theme.quickSpring) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(Theme.quickSpring) { isPressed = false }
                }
        )
    }
}

// MARK: - Fluid Stat Card
/// A stat display card with fluid animations
struct FluidStatCard: View {
    let label: String
    let value: String
    let icon: String
    var accentColor: Color = Theme.lagoon

    @State private var animatedValue: String = ""
    @State private var iconRotation: Double = 0
    @State private var glowPulse: CGFloat = 0

    var body: some View {
        LiquidGlassCard(cornerRadius: 20, tintColor: accentColor.opacity(0.5), isInteractive: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(accentColor)
                            .rotationEffect(.degrees(iconRotation))

                        Text(label)
                            .font(Theme.captionFont(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer()

                    Circle()
                        .fill(accentColor.opacity(0.28 + glowPulse * 0.15))
                        .frame(width: 9, height: 9)
                        .overlay(
                            Circle()
                                .strokeBorder(accentColor.opacity(0.45), lineWidth: 0.6)
                        )
                }

                Text(animatedValue)
                    .font(Theme.titleFont(.title3))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
            }
            .padding(16)
        }
        .onAppear {
            animatedValue = value
            withAnimation(.easeInOut(duration: 2.3).repeatForever(autoreverses: true)) {
                glowPulse = 1
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(Theme.fluidSpring) {
                animatedValue = newValue
            }
            withAnimation(Theme.quickSpring) {
                iconRotation += 15
            }
        }
    }
}

// MARK: - Quick Add Pill
/// An interactive pill button for quick water intake
struct QuickAddPill: View {
    let amount: Int
    let unit: String
    let action: () -> Void

    @State private var isPressed = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: CGFloat = 0

    var body: some View {
        Button(action: {
            triggerRipple()
            Haptics.impact(.medium)
            action()
        }) {
            ZStack {
                // Ripple effect
                Circle()
                    .fill(Theme.lagoon.opacity(rippleOpacity))
                    .scaleEffect(rippleScale)

                // Content
                Text("+\(amount) \(unit)")
                    .font(Theme.bodyFont(.footnote))
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .fill(Theme.card)
                            .overlay(
                                Capsule()
                                    .fill(Theme.lagoon.opacity(0.26))
                            )
                    )
                    .shadow(color: Theme.shadowColor.opacity(0.60), radius: 8, x: 0, y: 4)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(Theme.quickSpring, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private func triggerRipple() {
        rippleScale = 0.5
        rippleOpacity = 0.4
        withAnimation(.easeOut(duration: 0.5)) {
            rippleScale = 2.5
            rippleOpacity = 0
        }
    }
}

// MARK: - Animated Wave Divider
struct WaveDivider: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        // Uses WaveShape from WaveView.swift
        WaveShape(phase: phase, strength: 3)
            .fill(
                LinearGradient(
                    colors: [Theme.lagoon.opacity(0.3), Theme.mint.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 20)
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Liquid Glass Components") {
    PreviewEnvironment {
        ScrollView {
            VStack(spacing: 24) {
                LiquidGlassCard {
                    VStack(spacing: 12) {
                        Text("Liquid Glass Card")
                            .font(Theme.titleFont(.title3))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Beautiful fluid effects")
                            .font(Theme.bodyFont(.footnote))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(24)
                }

                HStack(spacing: 12) {
                    FluidStatCard(label: "Streak", value: "7 days", icon: "flame.fill", accentColor: Theme.coral)
                    FluidStatCard(label: "Coins", value: "250", icon: "bitcoinsign.circle.fill", accentColor: Theme.sun)
                }

                HStack(spacing: 10) {
                    QuickAddPill(amount: 200, unit: "ml") {}
                    QuickAddPill(amount: 350, unit: "ml") {}
                    QuickAddPill(amount: 500, unit: "ml") {}
                }

                LiquidGlassButton("Add Water", icon: "plus.circle.fill", style: .primary) {}
                LiquidGlassButton("View History", style: .secondary) {}

                WaveDivider()
            }
            .padding(20)
        }
    }
}
#endif
