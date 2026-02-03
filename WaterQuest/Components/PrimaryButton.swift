import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.lagoon
    var fullWidth: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration, tint: tint, fullWidth: fullWidth)
    }

    private struct PrimaryButton: View {
        let configuration: Configuration
        let tint: Color
        let fullWidth: Bool

        var body: some View {
            configuration.label
                .font(Theme.titleFont(size: 16))
                .padding(.vertical, 14)
                .padding(.horizontal, fullWidth ? 0 : 24)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [tint, Theme.mint], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(.black.opacity(0.85))
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .shadow(color: tint.opacity(0.3), radius: configuration.isPressed ? 6 : 12, x: 0, y: 6)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
                .onChange(of: configuration.isPressed) { _, pressed in
                    if pressed {
                        Haptics.impact(.medium)
                    }
                }
        }
    }
}

// MARK: - Glass Primary Button Style
struct GlassPrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.lagoon
    
    func makeBody(configuration: Configuration) -> some View {
        GlassPrimaryButton(configuration: configuration, tint: tint)
    }
    
    private struct GlassPrimaryButton: View {
        let configuration: Configuration
        let tint: Color
        
        var body: some View {
            if #available(iOS 26.0, *) {
                configuration.label
                    .font(Theme.titleFont(size: 16))
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 28)
                    .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                    .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
                    .onChange(of: configuration.isPressed) { _, pressed in
                        if pressed {
                            Haptics.impact(.medium)
                        }
                    }
            } else {
                configuration.label
                    .font(Theme.titleFont(size: 16))
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 28)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.3))
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: tint.opacity(0.2), radius: 8, x: 0, y: 4)
                    .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
                    .onChange(of: configuration.isPressed) { _, pressed in
                        if pressed {
                            Haptics.impact(.medium)
                        }
                    }
            }
        }
    }
}

// MARK: - Glass Secondary Button Style
struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GlassSecondaryButton(configuration: configuration)
    }
    
    private struct GlassSecondaryButton: View {
        let configuration: Configuration
        
        var body: some View {
            if #available(iOS 26.0, *) {
                configuration.label
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
                    .onChange(of: configuration.isPressed) { _, pressed in
                        if pressed {
                            Haptics.impact(.light)
                        }
                    }
            } else {
                configuration.label
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
                    .onChange(of: configuration.isPressed) { _, pressed in
                        if pressed {
                            Haptics.impact(.light)
                        }
                    }
            }
        }
    }
}
