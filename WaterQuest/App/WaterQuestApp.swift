import SwiftUI

@main
struct WaterQuestApp: App {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var deepLinkAddIntake = false
    @State private var deepLinkEarthWeek = false

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
        NotificationCategories.registerAll()
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
                notifier.scheduleReminders(context: store.buildNotificationContext())
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
                notifier.scheduleReminders(context: store.buildNotificationContext())
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await subscriptionManager.refreshStatus()
                        store.updatePremiumAccess(subscriptionManager.hasPremiumAccess)
                        await refreshHealthKitWaterEntries()
                        await notifier.refreshAuthorizationStatus()
                        notifier.scheduleReminders(context: store.buildNotificationContext())
                    }
                }
            }
            .onOpenURL { url in
                guard url.scheme == "sipli" else { return }
                switch url.host {
                case "add-intake":
                    deepLinkAddIntake = true
                case "earth-week", "pledge":
                    deepLinkEarthWeek = true
                default:
                    break
                }
            }
            .environment(\.deepLinkAddIntake, deepLinkAddIntake)
            .environment(\.deepLinkEarthWeek, deepLinkEarthWeek)
            .onChange(of: deepLinkAddIntake) {
                if deepLinkAddIntake {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        deepLinkAddIntake = false
                    }
                }
            }
            .onChange(of: deepLinkEarthWeek) {
                if deepLinkEarthWeek {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        deepLinkEarthWeek = false
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

// MARK: - Deep Link Environment Keys
private struct DeepLinkAddIntakeKey: EnvironmentKey {
    static let defaultValue = false
}

private struct DeepLinkEarthWeekKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var deepLinkAddIntake: Bool {
        get { self[DeepLinkAddIntakeKey.self] }
        set { self[DeepLinkAddIntakeKey.self] = newValue }
    }

    var deepLinkEarthWeek: Bool {
        get { self[DeepLinkEarthWeekKey.self] }
        set { self[DeepLinkEarthWeekKey.self] = newValue }
    }
}
