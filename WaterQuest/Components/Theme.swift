import SwiftUI

enum Theme {
    // MARK: - Core Colors
    static let night = Color(red: 0.07, green: 0.10, blue: 0.20)
    static let deepSea = Color(red: 0.08, green: 0.18, blue: 0.35)
    static let lagoon = Color(red: 0.20, green: 0.63, blue: 0.82)
    static let coral = Color(red: 0.98, green: 0.58, blue: 0.48)
    static let mint = Color(red: 0.58, green: 0.90, blue: 0.78)
    static let sun = Color(red: 0.98, green: 0.86, blue: 0.46)

    // MARK: - Liquid Glass Colors
    static let glassLight = Color.white.opacity(0.18)
    static let glassDark = Color.white.opacity(0.06)
    static let glassHighlight = Color.white.opacity(0.35)
    static let glassBorder = Color.white.opacity(0.25)
    static let glassAccent = Color(red: 0.4, green: 0.8, blue: 1.0)

    // MARK: - Gradients
    static let background = LinearGradient(
        colors: [deepSea, night],
        startPoint: .top,
        endPoint: .bottom
    )

    static let card = LinearGradient(
        colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let liquidGlassGradient = LinearGradient(
        colors: [glassLight, glassDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let waterGradient = LinearGradient(
        colors: [lagoon.opacity(0.8), mint.opacity(0.6), deepSea.opacity(0.9)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let progressGlow = RadialGradient(
        colors: [lagoon.opacity(0.6), lagoon.opacity(0.0)],
        center: .center,
        startRadius: 60,
        endRadius: 120
    )

    // MARK: - Fonts
    static func titleFont(size: CGFloat) -> Font {
        .custom("AvenirNextRounded-DemiBold", size: size)
    }

    static func bodyFont(size: CGFloat) -> Font {
        .custom("AvenirNext-Regular", size: size)
    }

    // MARK: - Animation Timings
    static let fluidSpring = Animation.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.2)
    static let gentleSpring = Animation.spring(response: 0.8, dampingFraction: 0.85, blendDuration: 0.3)
    static let quickSpring = Animation.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0.1)
    static let rippleAnimation = Animation.easeInOut(duration: 0.4)
}

#if DEBUG
struct PreviewEnvironment<Content: View>: View {
    @StateObject private var store = HydrationStore()
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var notifier = NotificationScheduler()
    @StateObject private var locationManager: LocationManager
    @StateObject private var weatherClient: WeatherClient

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        let location = LocationManager()
        let client = WeatherClient(locationManager: location)
        client.currentWeather = .mild
        _locationManager = StateObject(wrappedValue: location)
        _weatherClient = StateObject(wrappedValue: client)
        self.content = content()
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environmentObject(store)
        .environmentObject(healthKit)
        .environmentObject(notifier)
        .environmentObject(locationManager)
        .environmentObject(weatherClient)
        .preferredColorScheme(.dark)
    }
}
#endif
