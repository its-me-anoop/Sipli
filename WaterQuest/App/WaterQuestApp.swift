import SwiftUI

@main
struct WaterQuestApp: App {
    @StateObject private var store = HydrationStore()
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var notifier = NotificationScheduler()
    @StateObject private var locationManager: LocationManager
    @StateObject private var weatherClient: WeatherClient

    init() {
        let location = LocationManager()
        _locationManager = StateObject(wrappedValue: location)
        _weatherClient = StateObject(wrappedValue: WeatherClient(locationManager: location))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Theme.background.ignoresSafeArea()
                RootView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .environmentObject(store)
            .environmentObject(healthKit)
            .environmentObject(notifier)
            .environmentObject(locationManager)
            .environmentObject(weatherClient)
            .preferredColorScheme(.dark)
            .task {
                store.notificationScheduler = notifier
                await notifier.refreshAuthorizationStatus()
                locationManager.requestPermission()
                locationManager.requestLocation()
                notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
            }
        }
    }
}
