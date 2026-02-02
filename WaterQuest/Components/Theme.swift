import SwiftUI

enum Theme {
    static let night = Color(red: 0.07, green: 0.10, blue: 0.20)
    static let deepSea = Color(red: 0.08, green: 0.18, blue: 0.35)
    static let lagoon = Color(red: 0.20, green: 0.63, blue: 0.82)
    static let coral = Color(red: 0.98, green: 0.58, blue: 0.48)
    static let mint = Color(red: 0.58, green: 0.90, blue: 0.78)
    static let sun = Color(red: 0.98, green: 0.86, blue: 0.46)

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

    static func titleFont(size: CGFloat) -> Font {
        .custom("AvenirNextRounded-DemiBold", size: size)
    }

    static func bodyFont(size: CGFloat) -> Font {
        .custom("AvenirNext-Regular", size: size)
    }
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
        _locationManager = StateObject(wrappedValue: location)
        _weatherClient = StateObject(wrappedValue: WeatherClient(locationManager: location))
        self.content = content()
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
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
