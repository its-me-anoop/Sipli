#if DEBUG
import SwiftUI

struct PreviewEnvironment<Content: View>: View {
    @StateObject private var store: HydrationStore
    @StateObject private var healthKit: HealthKitManager
    @StateObject private var notifier: NotificationScheduler
    @StateObject private var locationManager: LocationManager
    @StateObject private var weatherClient: WeatherClient
    @StateObject private var subscriptionManager: SubscriptionManager

    private let content: Content

    init(
        setup: ((HydrationStore, SubscriptionManager) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        let store = HydrationStore()
        let healthKit = HealthKitManager()
        let notifier = NotificationScheduler()
        let location = LocationManager()
        let subscriptionManager = SubscriptionManager()

        setup?(store, subscriptionManager)

        _store = StateObject(wrappedValue: store)
        _healthKit = StateObject(wrappedValue: healthKit)
        _notifier = StateObject(wrappedValue: notifier)
        _locationManager = StateObject(wrappedValue: location)
        _weatherClient = StateObject(wrappedValue: WeatherClient(locationManager: location))
        _subscriptionManager = StateObject(wrappedValue: subscriptionManager)
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
