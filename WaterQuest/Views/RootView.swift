import SwiftUI
import StoreKit

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var showSplash = true

    private var shouldSkipOnboardingForICloud: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var paywallBinding: Binding<PaywallContext?> {
        Binding(
            get: { subscriptionManager.presentedPaywall },
            set: { subscriptionManager.presentedPaywall = $0 }
        )
    }

    var body: some View {
        ZStack {
            if hasOnboarded || shouldSkipOnboardingForICloud {
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
        .fullScreenCover(item: paywallBinding) { context in
            PremiumPaywallView(context: context)
        }
    }

    private func bootstrapAppFlow() async {
        guard showSplash else { return }

        if !hasOnboarded && shouldSkipOnboardingForICloud {
            hasOnboarded = true
        }

        try? await Task.sleep(for: .seconds(1.0))

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                showSplash = false
            }
        }
    }
}

struct PremiumPaywallView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedProductID: ProductID = .annual
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    private var isRegular: Bool { sizeClass == .regular }

    private var selectedProduct: Product? {
        subscriptionManager.product(for: selectedProductID) ?? subscriptionManager.featuredProduct
    }

    private var freeTierFeatures: [(icon: String, text: String)] {
        [
            ("drop.fill", "Manual water logging"),
            ("target", "Custom daily goal"),
            ("book.fill", "Diary and history"),
            ("bell.fill", "Standard reminders")
        ]
    }

    private var premiumTierFeatures: [PremiumFeature] {
        [
            .fluidTypes,
            .aiInsights,
            .healthKitSync,
            .weatherGoals,
            .activityGoals,
            .smartReminders
        ]
    }

    private var disclosureText: String {
        let fallbackPrice = "the listed price"
        let price = selectedProduct?.displayPrice ?? fallbackPrice

        switch selectedProductID {
        case .monthly:
            return "Start a 1-week free trial. After the trial, your monthly subscription automatically renews at \(price)/mo unless canceled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel anytime in Settings > Apple ID > Subscriptions."
        case .annual:
            return "Start a 30-day free trial. After the trial, your annual subscription automatically renews at \(price)/yr unless canceled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel anytime in Settings > Apple ID > Subscriptions."
        }
    }

    var body: some View {
        ZStack {
            AppWaterBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Spacer()
                        Button {
                            closePaywall()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close premium plans")
                    }

                    Image("Mascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 104)
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
                        Text(context.title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)

                        Text(context.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    tierComparison

                    if subscriptionManager.availableProducts.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                                if let productID = ProductID(rawValue: product.id) {
                                    PlanOptionCard(
                                        productID: productID,
                                        price: product.displayPrice,
                                        isSelected: selectedProductID == productID
                                    ) {
                                        Haptics.selection()
                                        selectedProductID = productID
                                    }
                                }
                            }
                        }
                    }

                    Text(disclosureText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    if let product = selectedProduct {
                        Button {
                            doPurchase(product)
                        } label: {
                            Group {
                                if isPurchasing {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(.white)
                                        Text("Processing...")
                                    }
                                } else {
                                    Text("\(selectedProductID.trialCallToAction) — then \(product.displayPrice)\(selectedProductID.billingSuffix)")
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
                            .multilineTextAlignment(.center)
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
                .padding(.top, 16)
                .frame(maxWidth: isRegular ? 680 : .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            syncSelectedPlan()
        }
        .onChange(of: subscriptionManager.products.count) { _, _ in
            syncSelectedPlan()
        }
    }

    private var tierComparison: some View {
        Group {
            if isRegular {
                HStack(alignment: .top, spacing: 16) {
                    TierSummaryCard(
                        title: "Sipli Free",
                        icon: "drop.fill",
                        tint: Theme.lagoon,
                        rows: freeTierFeatures.map { ($0.icon, $0.text) }
                    )

                    TierSummaryCard(
                        title: "Sipli Premium",
                        icon: "sparkles",
                        tint: Theme.sun,
                        rows: premiumTierFeatures.map { ($0.icon, $0.title) }
                    )
                }
            } else {
                VStack(spacing: 14) {
                    TierSummaryCard(
                        title: "Sipli Free",
                        icon: "drop.fill",
                        tint: Theme.lagoon,
                        rows: freeTierFeatures.map { ($0.icon, $0.text) }
                    )

                    TierSummaryCard(
                        title: "Sipli Premium",
                        icon: "sparkles",
                        tint: Theme.sun,
                        rows: premiumTierFeatures.map { ($0.icon, $0.title) }
                    )
                }
            }
        }
    }

    private func syncSelectedPlan() {
        if subscriptionManager.product(for: selectedProductID) != nil {
            return
        }

        if subscriptionManager.annualProduct != nil {
            selectedProductID = .annual
        } else {
            selectedProductID = .monthly
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
                closePaywall()
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
                closePaywall()
            } else {
                Haptics.warning()
                purchaseError = "No previous premium purchase found."
            }
        }
    }

    private func closePaywall() {
        subscriptionManager.dismissPaywall()
        dismiss()
    }
}

private struct TierSummaryCard: View {
    let title: String
    let icon: String
    let tint: Color
    let rows: [(icon: String, text: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { item in
                SubscriptionFeatureRow(icon: item.element.icon, text: item.element.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.card)
        )
    }
}

private struct PlanOptionCard: View {
    let productID: ProductID
    let price: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(productID.displayName)
                            .font(.headline)

                        if let badge = productID.badgeText {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.sun)
                                .clipShape(Capsule())
                        }
                    }

                    Text(productID.shortDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.lagoon)
                    Text(productID.billingSuffix)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Theme.lagoon : Theme.glassBorder.opacity(0.4), lineWidth: isSelected ? 1.8 : 1)
            )
        }
        .buttonStyle(.plain)
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
