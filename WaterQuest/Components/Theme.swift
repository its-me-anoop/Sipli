import SwiftUI

enum Theme {
    // MARK: Palette
    static let night = Color(uiColor: .systemGroupedBackground)
    static let deepSea = Color(uiColor: .secondarySystemGroupedBackground)
    static let lagoon = Color(red: 0.11, green: 0.47, blue: 0.96)
    static let coral = Color(red: 0.94, green: 0.33, blue: 0.28)
    static let mint = Color(red: 0.19, green: 0.76, blue: 0.64)
    static let sun = Color(red: 0.98, green: 0.67, blue: 0.17)
    static let lavender = Color(red: 0.49, green: 0.44, blue: 0.95)
    static let peach = Color(red: 0.96, green: 0.51, blue: 0.35)

    // MARK: Semantic Colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.7)
    static let mintText = Color(uiColor: .systemGreen)
    static let sunText = Color(uiColor: .systemOrange)

    // MARK: Surfaces
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
    static let glassLight = cardSurface
    static let glassBorder = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor.black.withAlphaComponent(0.14)
        }
    )
    static let glassHighlight = Color.white.opacity(0.7)
    static let glassAccent = Color(uiColor: .tertiarySystemFill)
    static let shadowColor = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.22)
                : UIColor.black.withAlphaComponent(0.16)
        }
    )
    static let tabBarOverlay = Color.clear

    // MARK: Gradients
    static let background = LinearGradient(
        colors: [
            Color(uiColor: .systemGroupedBackground),
            Color(uiColor: .secondarySystemGroupedBackground)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let card = LinearGradient(
        colors: [
            cardSurface,
            cardElevated
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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

    // MARK: Typography
    static func displayFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func titleFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func bodyFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func captionFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func glassCard(cornerRadius: CGFloat = 20) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(glassBorder, lineWidth: 1)
            )
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

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                shaderBackground(
                    size: geo.size,
                    time: timeline.date.timeIntervalSinceReferenceDate
                )
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
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
                topColor = Color(red: 1.0, green: 1.0, blue: 1.0)
                bottomColor = Color(red: 0.90, green: 0.95, blue: 1.0)
                blobA = Theme.lagoon.opacity(0.12)
                blobB = Theme.mint.opacity(0.08)
                blobC = Theme.lavender.opacity(0.06)
                sheenTop = Color.white.opacity(0.3)
                sheenBottom = Theme.lagoon.opacity(0.02)
            } else {
                topColor = Color(red: 0.05, green: 0.14, blue: 0.24)
                bottomColor = Color(red: 0.01, green: 0.06, blue: 0.13)
                blobA = Theme.lagoon.opacity(0.34)
                blobB = Theme.mint.opacity(0.24)
                blobC = Theme.lavender.opacity(0.18)
                sheenTop = Color.white.opacity(0.06)
                sheenBottom = Theme.lagoon.opacity(0.12)
            }
        }
    }
}

#if DEBUG
struct PreviewEnvironment<Content: View>: View {
    @StateObject private var store = HydrationStore()
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var notifier = NotificationScheduler()
    @StateObject private var locationManager: LocationManager
    @StateObject private var weatherClient: WeatherClient
    @StateObject private var subscriptionManager = SubscriptionManager()

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        let location = LocationManager()
        _locationManager = StateObject(wrappedValue: location)
        _weatherClient = StateObject(wrappedValue: WeatherClient(locationManager: location))
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppWaterBackground().ignoresSafeArea()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environmentObject(store)
        .environmentObject(healthKit)
        .environmentObject(notifier)
        .environmentObject(locationManager)
        .environmentObject(weatherClient)
        .environmentObject(subscriptionManager)
    }
}
#endif
