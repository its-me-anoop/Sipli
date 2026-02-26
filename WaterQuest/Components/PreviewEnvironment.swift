#if DEBUG
import SwiftUI

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
