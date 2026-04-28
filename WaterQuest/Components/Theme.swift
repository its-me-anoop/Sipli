import SwiftUI

enum Legal {
    // swiftlint:disable force_unwrapping
    static let privacyURL = URL(string: "https://its-me-anoop.github.io/Sipli/privacy")!
    static let termsURL = URL(string: "https://its-me-anoop.github.io/Sipli/terms")!
    static let weatherAttributionURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
    static let hydrationBaseCitationURL = URL(string: "https://nap.nationalacademies.org/catalog/10925/dietary-reference-intakes-for-water-potassium-sodium-chloride-and-sulfate")!
    static let hydrationHeatCitationURL = URL(string: "https://www.cdc.gov/healthy-weight-growth/water-healthy-drinks/index.html")!
    static let hydrationExerciseCitationURL = URL(string: "https://acsm.org/9-facts-about-hydration-electrolytes/")!
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/sipli/id6758851574")!
    /// Deep-links straight to Sipli's "Write a Review" sheet inside the App
    /// Store app. Used by the Settings "Rate Sipli" row for users who want to
    /// leave a review outside of the Apple-throttled `.requestReview` prompt.
    static let appStoreReviewURL = URL(string: "https://apps.apple.com/app/id6758851574?action=write-review")!
    // swiftlint:enable force_unwrapping
}

enum Theme {
    // MARK: Palette
    // Warm "paper" identity inherited from the onboarding redesign.
#if os(watchOS)
    static let night = Color(red: 0.910, green: 0.886, blue: 0.824)
    static let deepSea = Color(red: 0.929, green: 0.906, blue: 0.855)
#else
    static let night = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.10, blue: 0.16, alpha: 1)
                : UIColor(red: 0.910, green: 0.886, blue: 0.824, alpha: 1) // #E8E2D2
        }
    )
    static let deepSea = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.10, green: 0.14, blue: 0.20, alpha: 1)
                : UIColor(red: 0.929, green: 0.906, blue: 0.855, alpha: 1) // #EDE7DA
        }
    )
#endif
    /// Primary accent — matches `OnboardingPalette.water`.
    static let lagoon = Color(red: 0.169, green: 0.420, blue: 1.0)         // #2B6BFF
    static let coral = Color(red: 1.0, green: 0.478, blue: 0.400)          // #FF7A66
    static let mint = Color(red: 0.435, green: 0.890, blue: 0.824)         // #6FE3D2 (aqua)
    static let sun = Color(red: 1.0, green: 0.698, blue: 0.243)            // #FFB23E
    static let lavender = Color(red: 0.722, green: 0.651, blue: 1.0)       // #B8A6FF
    static let peach = Color(red: 0.96, green: 0.51, blue: 0.35)
    /// "Ink" — deep navy text/headline color from the onboarding palette.
    static let ink = Color(red: 0.039, green: 0.102, blue: 0.184)          // #0A1A2F
    /// Warm off-white paper background — the dominant onboarding surface.
#if os(watchOS)
    static let paper = Color(red: 0.957, green: 0.945, blue: 0.918)
#else
    static let paper = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 1)
                : UIColor(red: 0.957, green: 0.945, blue: 0.918, alpha: 1) // #F4F1EA
        }
    )
#endif

    // MARK: Semantic Colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.7)
#if os(watchOS)
    static let mintText = Color.green
    static let sunText = Color.orange
#else
    static let mintText = Color(uiColor: .systemGreen)
    static let sunText = Color(uiColor: .systemOrange)
#endif

    // MARK: Surfaces
#if os(watchOS)
    static let cardSurface = Color(white: 0.18)
    static let cardElevated = Color(white: 0.22)
    static let glassBorder = Color.white.opacity(0.12)
    static let glassAccent = Color.white.opacity(0.08)
    static let shadowColor = Color.black.opacity(0.22)
#else
    static let cardSurface = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .secondarySystemBackground : .systemBackground
        }
    )
    static let cardElevated = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .tertiarySystemBackground : .secondarySystemBackground
        }
    )
    static let glassBorder = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor.black.withAlphaComponent(0.14)
        }
    )
    static let glassAccent = Color(uiColor: .tertiarySystemFill)
    static let shadowColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.22)
                : UIColor.black.withAlphaComponent(0.16)
        }
    )
#endif
    static let glassLight = cardSurface
    static let glassHighlight = Color.white.opacity(0.7)
    static let tabBarOverlay = Color.clear

    // MARK: Gradients
#if os(watchOS)
    static let background = LinearGradient(
        colors: [Color(white: 0.10), Color(white: 0.15)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let card = LinearGradient(
        colors: [Color(white: 0.18), Color(white: 0.14)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let coachCard = LinearGradient(
        colors: [Color(white: 0.16), Color(white: 0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let summaryCard = LinearGradient(
        colors: [Color(white: 0.14), Color(white: 0.18)],
        startPoint: .top,
        endPoint: .bottom
    )
#else
    static let background = LinearGradient(
        colors: [
            paper,
            Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(red: 0.10, green: 0.14, blue: 0.20, alpha: 1)
                        : UIColor(red: 0.929, green: 0.906, blue: 0.855, alpha: 1) // #EDE7DA
                }
            )
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Clean, opaque card surface matching onboarding's `cardSurface` —
    /// solid white in light mode, deep slate in dark mode. Both stops of the
    /// gradient share the same colour so existing `LinearGradient` consumers
    /// keep their type but the result reads as a flat fill.
    static let card = LinearGradient(
        colors: [
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.14, green: 0.17, blue: 0.24, alpha: 1)
                    : .white
            }),
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.14, green: 0.17, blue: 0.24, alpha: 1)
                    : .white
            })
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let coachCard = LinearGradient(
        colors: [
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.14, green: 0.16, blue: 0.34, alpha: 1)
                    : UIColor(red: 0.88, green: 0.90, blue: 1.0, alpha: 1)
            }),
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.20, green: 0.14, blue: 0.32, alpha: 1)
                    : UIColor(red: 0.94, green: 0.88, blue: 1.0, alpha: 1)
            })
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Hero/summary card — opaque sky → cream gradient that echoes the
    /// onboarding's target stage card. The bottle illustration carries the
    /// colour, so this stays light and solid (no translucency).
    static let summaryCard = LinearGradient(
        colors: [
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.08, green: 0.14, blue: 0.22, alpha: 1)
                    : UIColor(red: 0.890, green: 0.945, blue: 0.984, alpha: 1) // sky
            }),
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.10, green: 0.18, blue: 0.26, alpha: 1)
                    : UIColor(red: 1.0, green: 0.945, blue: 0.855, alpha: 1)   // cream
            })
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
#endif

    static let glowGradient = LinearGradient(
        colors: [lagoon.opacity(0.9), mint.opacity(0.8), lavender.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = LinearGradient(
        colors: [coral, peach, sun],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let liquidGlassGradient = LinearGradient(
        colors: [
            cardSurface,
            cardElevated
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let progressGlow = RadialGradient(
        colors: [lagoon.opacity(0.22), mint.opacity(0.1), .clear],
        center: .center,
        startRadius: 2,
        endRadius: 130
    )

    // MARK: Motion
    static let quickSpring = Animation.spring(response: 0.26, dampingFraction: 0.84)
    static let fluidSpring = Animation.spring(response: 0.5, dampingFraction: 0.86)
    static let gentleSpring = Animation.easeInOut(duration: 0.35)

    // MARK: Typography (Dynamic Type)
    /// Editorial serif (SF Serif italic-friendly) — used for headlines and
    /// numerical readouts in the onboarding aesthetic. Falls back gracefully
    /// to `.system(... design: .serif)` on every platform.
    static func editorialSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Mono face for steppers, eyebrows, numerical labels.
    static func sipliMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func displayFont(_ style: Font.TextStyle = .title) -> Font {
        .system(style, design: .default).weight(.bold)
    }

    static func titleFont(_ style: Font.TextStyle = .headline) -> Font {
        .system(style, design: .default).weight(.semibold)
    }

    static func bodyFont(_ style: Font.TextStyle = .subheadline) -> Font {
        .system(style, design: .default)
    }

    static func captionFont(_ style: Font.TextStyle = .caption) -> Font {
        .system(style, design: .default)
    }

    static func glassCard(cornerRadius: CGFloat = 20) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(card)
            .shadow(color: shadowColor, radius: 10, x: 0, y: 4)
    }
}

enum AppTheme: Int, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -220

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.35), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(16))
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2.1).repeatForever(autoreverses: false)) {
                    phase = 260
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

struct FloatingBubble: View {
    let size: CGFloat
    let color: Color
    let delay: Double

    @State private var yOffset: CGFloat = 0
    @State private var opacity = 0.0

    var body: some View {
        Circle()
            .fill(color.opacity(0.15))
            .frame(width: size, height: size)
            .blur(radius: size * 0.4)
            .offset(y: yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: Double.random(in: 6...9)).repeatForever(autoreverses: true).delay(delay)) {
                    yOffset = CGFloat.random(in: -24...26)
                }
                withAnimation(.easeOut(duration: 0.9).delay(delay)) {
                    opacity = 1
                }
            }
    }
}

struct AnimatedMeshBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppWaterBackground().ignoresSafeArea()

                FloatingBubble(size: min(220, geo.size.width * 0.5), color: Theme.lagoon, delay: 0.0)
                    .position(x: geo.size.width * 0.2, y: geo.size.height * 0.2)

                FloatingBubble(size: min(180, geo.size.width * 0.4), color: Theme.mint, delay: 0.5)
                    .position(x: geo.size.width * 0.75, y: geo.size.height * 0.45)

                FloatingBubble(size: min(150, geo.size.width * 0.35), color: Theme.lavender, delay: 0.8)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.75)
            }
        }
    }
}

struct AppWaterBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            GeometryReader { geo in
                shaderBackground(size: geo.size, time: 0)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .ignoresSafeArea()
        } else {
            TimelineView(.animation) { timeline in
                GeometryReader { geo in
                    shaderBackground(
                        size: geo.size,
                        time: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .ignoresSafeArea()
        }
    }

    private func shaderBackground(size: CGSize, time: TimeInterval) -> some View {
        let palette = WaterPalette(isLight: colorScheme == .light)

        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [palette.topColor, palette.bottomColor],
                    startPoint: UnitPoint(
                        x: 0.18 + 0.12 * sin(time * 0.14),
                        y: 0.02 + 0.06 * cos(time * 0.12)
                    ),
                    endPoint: UnitPoint(
                        x: 0.82 + 0.1 * cos(time * 0.1),
                        y: 0.98 + 0.04 * sin(time * 0.16)
                    )
                )
            )
            .overlay(
                Circle()
                    .fill(palette.blobA)
                    .frame(width: max(320, size.width * 0.72), height: max(280, size.width * 0.62))
                    .blur(radius: 70)
                    .offset(
                        x: -120 + cos(time * 0.22) * 48,
                        y: -140 + sin(time * 0.18) * 38
                    )
            )
            .overlay(
                Circle()
                    .fill(palette.blobB)
                    .frame(width: max(300, size.width * 0.68), height: max(240, size.width * 0.58))
                    .blur(radius: 64)
                    .offset(
                        x: 120 + sin(time * 0.2) * 56,
                        y: 42 + cos(time * 0.16) * 36
                    )
            )
            .overlay(
                Circle()
                    .fill(palette.blobC)
                    .frame(width: max(360, size.width * 0.82), height: max(250, size.width * 0.62))
                    .blur(radius: 72)
                    .offset(
                        x: 0 + sin(time * 0.15) * 44,
                        y: 340 + cos(time * 0.14) * 30
                    )
            )
            .overlay(
                LinearGradient(
                    colors: [palette.sheenTop, .clear, palette.sheenBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }

    private struct WaterPalette {
        let topColor: Color
        let bottomColor: Color
        let blobA: Color
        let blobB: Color
        let blobC: Color
        let sheenTop: Color
        let sheenBottom: Color

        init(isLight: Bool) {
            if isLight {
                // Warm-paper backdrop with very soft tinted blobs — same
                // family as the onboarding hero background, gentler so it
                // doesn't fight foreground content.
                topColor = Color(red: 0.957, green: 0.945, blue: 0.918)    // #F4F1EA
                bottomColor = Color(red: 0.929, green: 0.906, blue: 0.855) // #EDE7DA
                blobA = Theme.lagoon.opacity(0.06)
                blobB = Theme.sun.opacity(0.06)
                blobC = Theme.coral.opacity(0.04)
                sheenTop = Color.white.opacity(0.35)
                sheenBottom = Theme.ink.opacity(0.03)
            } else {
                topColor = Color(red: 0.06, green: 0.10, blue: 0.16)
                bottomColor = Color(red: 0.02, green: 0.05, blue: 0.10)
                blobA = Theme.lagoon.opacity(0.22)
                blobB = Theme.sun.opacity(0.10)
                blobC = Theme.coral.opacity(0.08)
                sheenTop = Color.white.opacity(0.06)
                sheenBottom = Theme.lagoon.opacity(0.10)
            }
        }
    }
}
