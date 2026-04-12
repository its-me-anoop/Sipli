import SwiftUI
import WatchKit
import UserNotifications

final class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    var store: WatchHydrationStore?

    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
        WatchNotificationHandler.registerCategories()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let store {
            await MainActor.run {
                WatchNotificationHandler.handleAction(identifier: response.actionIdentifier, store: store)
            }
        }
    }
}

@main
struct SipliWatchApp: App {
    @WKApplicationDelegateAdaptor private var appDelegate: WatchAppDelegate
    @StateObject private var store = WatchHydrationStore()
    @StateObject private var healthKit = WatchHealthKitManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environmentObject(store)
                .task {
                    appDelegate.store = store
                    store.healthKitManager = healthKit
                    await healthKit.requestAuthorization()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.loadState()
            }
        }
    }
}
