import SwiftUI

@main
struct SipliWatchApp: App {
    @StateObject private var store = WatchHydrationStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.loadState()
            }
        }
    }
}
