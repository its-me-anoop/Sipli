import SwiftUI

@main
struct WaterQuestApp: App {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var deepLinkAddIntake = false

    @StateObject private var store = HydrationStore()
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var notifier = NotificationScheduler()
    @StateObject private var locationManager: LocationManager
    @StateObject private var weatherClient: WeatherClient
    @StateObject private var subscriptionManager = SubscriptionManager()

    private var isSetupComplete: Bool {
        hasOnboarded || FileManager.default.ubiquityIdentityToken != nil
    }

    init() {
        let location = LocationManager()
        _locationManager = StateObject(wrappedValue: location)
        _weatherClient = StateObject(wrappedValue: WeatherClient(locationManager: location))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
            .tint(Theme.lagoon)
            .environmentObject(store)
            .environmentObject(healthKit)
            .environmentObject(notifier)
            .environmentObject(locationManager)
            .environmentObject(weatherClient)
            .environmentObject(subscriptionManager)
            .preferredColorScheme(appTheme.colorScheme)
            .task {
                store.notificationScheduler = notifier
                await subscriptionManager.initialise()
                store.updatePremiumAccess(subscriptionManager.hasPremiumAccess)
                _ = subscriptionManager.startTransactionListener()
                guard isSetupComplete else { return }
                await notifier.refreshAuthorizationStatus()
                await healthKit.refreshAuthorizationStatus()
                notifier.scheduleReminders(profile: store.effectiveProfile, entries: store.entries, goalML: store.dailyGoal.totalML)
            }
            .task(id: store.effectiveProfile.prefersHealthKit) {
                guard isSetupComplete else { return }
                if store.effectiveProfile.prefersHealthKit {
                    await startHealthKitAutoSync()
                } else {
                    healthKit.stopWaterIntakeObserver()
                }
            }
            .onChange(of: subscriptionManager.isSubscribed) { _, _ in
                store.updatePremiumAccess(subscriptionManager.hasPremiumAccess)
                guard isSetupComplete else { return }
                notifier.scheduleReminders(profile: store.effectiveProfile, entries: store.entries, goalML: store.dailyGoal.totalML)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await subscriptionManager.refreshStatus()
                        store.updatePremiumAccess(subscriptionManager.hasPremiumAccess)
                        await refreshHealthKitWaterEntries()
                        await notifier.refreshAuthorizationStatus()
                        notifier.scheduleReminders(profile: store.effectiveProfile, entries: store.entries, goalML: store.dailyGoal.totalML)
                    }
                }
            }
            .onOpenURL { url in
                if url.scheme == "sipli" && url.host == "add-intake" {
                    deepLinkAddIntake = true
                }
            }
            .environment(\.deepLinkAddIntake, deepLinkAddIntake)
            .onChange(of: deepLinkAddIntake) {
                if deepLinkAddIntake {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        deepLinkAddIntake = false
                    }
                }
            }
        }
    }

    @MainActor
    private func startHealthKitAutoSync() async {
        await healthKit.startWaterIntakeObserver(days: 7) { entries in
            store.syncHealthKitEntriesRange(entries, days: 7)
        }
    }

    @MainActor
    private func refreshHealthKitWaterEntries() async {
        guard store.effectiveProfile.prefersHealthKit else { return }
        if let entries = await healthKit.fetchRecentWaterEntries(days: 7) {
            store.syncHealthKitEntriesRange(entries, days: 7)
        }
    }
}

// MARK: - Deep Link Environment Key
private struct DeepLinkAddIntakeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var deepLinkAddIntake: Bool {
        get { self[DeepLinkAddIntakeKey.self] }
        set { self[DeepLinkAddIntakeKey.self] = newValue }
    }
}
