import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.titleFont(.body))
            .padding(.vertical, 14)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 32)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.lagoon)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.lagoon.opacity(0.65), lineWidth: 1)
                    )
            )
            .foregroundStyle(Color.white.opacity(0.95))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: Theme.lagoon.opacity(configuration.isPressed ? 0.16 : 0.30), radius: configuration.isPressed ? 5 : 12, x: 0, y: configuration.isPressed ? 3 : 6)
            .animation(Theme.quickSpring, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyFont(.subheadline))
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(
                Capsule()
                    .fill(Theme.card)
            )
            .foregroundStyle(Theme.textPrimary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Theme.quickSpring, value: configuration.isPressed)
    }
}

struct GlowingIconButton: View {
    let icon: String
    let label: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isActive ? 0.28 : 0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isActive ? color : Theme.textSecondary)
                }

                Text(label)
                    .font(Theme.bodyFont(.subheadline))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(color.opacity(0.32), lineWidth: 1)
                    }
                }
            )
            .shadow(color: Theme.shadowColor.opacity(0.60), radius: 8, x: 0, y: 4)
            .animation(Theme.quickSpring, value: isActive)
        }
        .buttonStyle(.plain)
    }
}
