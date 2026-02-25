import SwiftUI
import StoreKit

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var showSplash = true

    var body: some View {
        ZStack {
            if hasOnboarded {
                if subscriptionManager.isSubscribed {
                    MainTabView()
                } else if subscriptionManager.isInitialized {
                    SubscriptionRequiredView()
                } else {
                    // Still loading subscription status — show nothing behind splash
                    Color.clear
                }
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
    }

    private func bootstrapAppFlow() async {
        guard showSplash else { return }

        try? await Task.sleep(for: .seconds(1.0))

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                showSplash = false
            }
        }
    }
}

// MARK: - Subscription Required View
/// Shown when a returning user's subscription has lapsed.
/// The user must subscribe to access the app — there is no dismiss button.
struct SubscriptionRequiredView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var isPurchasing = false
    @State private var purchaseError: String?

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            AppWaterBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    Image("Mascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .accessibilityHidden(true)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.8), .white.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: Theme.lagoon.opacity(0.15), radius: 24, x: 0, y: 12)
                        )

                    VStack(spacing: 12) {
                        Text("Subscription Required")
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text("Start your 1-week free trial to continue using Sipli with personalized goals, smart reminders, and detailed insights.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SubscriptionFeatureRow(icon: "target", text: "Personalized daily hydration goal")
                        SubscriptionFeatureRow(icon: "sun.max.fill", text: "Weather-based goal adjustment")
                        SubscriptionFeatureRow(icon: "figure.run", text: "Workout-based goal adjustment")
                        SubscriptionFeatureRow(icon: "drop.fill", text: "Quick water logging & progress tracking")
                        SubscriptionFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Insights and streak tracking")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )

                    // Monthly plan display
                    if subscriptionManager.products.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 60)
                    } else if let monthly = subscriptionManager.monthlyProduct {
                        HStack(alignment: .center, spacing: 10) {
                            Text("Monthly")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text(monthly.displayPrice)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Theme.lagoon)
                                Text("/mo")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.lagoon, lineWidth: 1.5)
                        )
                    }

                    // Auto-renewal disclosure (must appear BEFORE purchase button per App Store Review Guidelines 3.1.1)
                    Text("Enjoy a 1-week free trial. After the trial, your subscription automatically renews at the price shown above unless canceled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel anytime in Settings \u{203A} Apple ID \u{203A} Subscriptions.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Subscribe button
                    if let monthly = subscriptionManager.monthlyProduct {
                        Button {
                            doPurchase(monthly)
                        } label: {
                            Group {
                                if isPurchasing {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(.white)
                                        Text("Processing...")
                                    }
                                } else {
                                    Text("Try Free for 1 Week — then \(monthly.displayPrice)/mo")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.lagoon)
                            .clipShape(Capsule())
                            .shadow(color: Theme.lagoon.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(isPurchasing)
                    }

                    if let error = purchaseError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button("Restore Purchase") {
                        doRestore()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.lagoon)
                    .disabled(isPurchasing)

                    HStack {
                        Link("Privacy Policy", destination: Legal.privacyURL)
                        Spacer()
                        Link("Terms of Use", destination: Legal.termsURL)
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.lagoon)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: isRegular ? 600 : .infinity)
            }
        }
    }

    private func doPurchase(_ product: Product) {
        isPurchasing = true
        purchaseError = nil
        Task {
            let result = await subscriptionManager.purchase(product)
            isPurchasing = false
            switch result {
            case .success:
                Haptics.success()
            case .cancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval. It will complete shortly."
            case .failed(let message):
                Haptics.error()
                purchaseError = message
            }
        }
    }

    private func doRestore() {
        isPurchasing = true
        purchaseError = nil
        Task {
            let success = await subscriptionManager.restore()
            isPurchasing = false
            if success {
                Haptics.success()
            } else {
                Haptics.warning()
                purchaseError = "No previous purchase found."
            }
        }
    }
}

private struct SubscriptionFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.lagoon)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
