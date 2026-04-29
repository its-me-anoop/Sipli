import SwiftUI
import UserNotifications

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
    @StateObject private var deepLinkForwarder = NotificationDeepLinkForwarder()

    private var isSetupComplete: Bool {
        hasOnboarded || FileManager.default.ubiquityIdentityToken != nil
    }

    init() {
        NotificationCategories.registerAll()
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
        let location = LocationManager()
        _locationManager = StateObject(wrappedValue: location)
        _weatherClient = StateObject(wrappedValue: WeatherClient(locationManager: location))
        Self.applyAppearance()
    }

    /// Brand the navigation bar to use SF Serif so every `navigationTitle`
    /// inherits the editorial onboarding aesthetic. Called once at launch;
    /// per-screen overrides still work via the `.toolbar { ToolbarItem... }`
    /// principal slot.
    private static func applyAppearance() {
        let large = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
            .withDesign(.serif)
        let inline = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
            .withDesign(.serif)
        let largeFont = large.map { UIFont(descriptor: $0, size: 0) } ?? UIFont.preferredFont(forTextStyle: .largeTitle)
        let inlineFont = inline.map { UIFont(descriptor: $0, size: 0) } ?? UIFont.preferredFont(forTextStyle: .headline)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.font: inlineFont, .foregroundColor: UIColor(Theme.ink)]
        appearance.largeTitleTextAttributes = [.font: largeFont, .foregroundColor: UIColor(Theme.ink)]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
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
                NotificationHandler.shared.store = store
                NotificationHandler.shared.deepLinkForwarder = deepLinkForwarder
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
                default:
                    break
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
            .onChange(of: deepLinkForwarder.shouldOpenAddIntake) { _, shouldOpen in
                if shouldOpen {
                    deepLinkAddIntake = true
                    deepLinkForwarder.shouldOpenAddIntake = false
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

// MARK: - Notification Deep Link Forwarder

@MainActor
final class NotificationDeepLinkForwarder: ObservableObject, NotificationDeepLinkForwarding {
    @Published var shouldOpenAddIntake: Bool = false

    nonisolated func openAddIntake() {
        Task { @MainActor in
            self.shouldOpenAddIntake = true
        }
    }
}

// MARK: - Deep Link Environment Keys
private struct DeepLinkAddIntakeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var deepLinkAddIntake: Bool {
        get { self[DeepLinkAddIntakeKey.self] }
        set { self[DeepLinkAddIntakeKey.self] = newValue }
    }
}
