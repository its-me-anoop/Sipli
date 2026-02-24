import SwiftUI

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var showSplash = true
    @State private var showTrialExpiredPaywall = false
    @State private var pendingPaywallCheck = false

    var body: some View {
        ZStack {
            if hasOnboarded {
                MainTabView()
            } else {
                OnboardingView {
                    hasOnboarded = true
                }
            }

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .task {
            await bootstrapAppFlow()
        }
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            if isPro {
                showTrialExpiredPaywall = false
            }
        }
        .onChange(of: subscriptionManager.isInitialized) { _, initialized in
            guard initialized, pendingPaywallCheck, hasOnboarded else { return }
            pendingPaywallCheck = false
            showTrialExpiredPaywall = !subscriptionManager.isPro
        }
        .sheet(isPresented: $showTrialExpiredPaywall) {
            PaywallView(isDismissible: true)
        }
    }

    private func bootstrapAppFlow() async {
        guard showSplash else { return }

        try? await Task.sleep(for: .seconds(1.0))

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                showSplash = false
            }
        }

        guard hasOnboarded else { return }

        if subscriptionManager.isInitialized {
            if !subscriptionManager.isPro {
                showTrialExpiredPaywall = true
            }
        } else {
            pendingPaywallCheck = true
        }
    }
}
