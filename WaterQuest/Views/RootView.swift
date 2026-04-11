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
                    if !subscriptionManager.isSubscribed {
                        subscriptionManager.presentPaywall()
                    }
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

    @State private var selectedProductID: ProductID = .annual
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    private var selectedProduct: Product? {
        subscriptionManager.product(for: selectedProductID)
    }

    private var productOptions: [(id: ProductID, product: Product?)] {
        ProductID.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { ($0, subscriptionManager.product(for: $0)) }
    }

    private var isLoadingProducts: Bool {
        subscriptionManager.availableProducts.isEmpty && !subscriptionManager.isInitialized
    }

    private var productsFailedToLoad: Bool {
        subscriptionManager.isInitialized && subscriptionManager.availableProducts.isEmpty
    }

    private var annualPlanUnavailable: Bool {
        subscriptionManager.isInitialized && subscriptionManager.annualProduct == nil
    }

    private var premiumFeatures: [PremiumFeature] {
        [
            .fluidTypes,
            .aiInsights,
            .healthKitSync,
            .weatherGoals,
            .activityGoals,
            .smartReminders
        ]
    }

    private var annualSavingsText: String? {
        guard
            let annualProduct = subscriptionManager.annualProduct,
            let monthlyProduct = subscriptionManager.monthlyProduct
        else {
            return nil
        }

        let monthlyYearlyCost = NSDecimalNumber(decimal: monthlyProduct.price)
            .multiplying(by: 12)
        let annualCost = NSDecimalNumber(decimal: annualProduct.price)
        let savings = monthlyYearlyCost.subtracting(annualCost)

        guard savings.compare(NSDecimalNumber.zero) == .orderedDescending else {
            return nil
        }

        let formattedSavings = savings.decimalValue.formatted(annualProduct.priceFormatStyle)
        return "Save \(formattedSavings) per year"
    }

    private func productDescription(for productID: ProductID) -> String {
        switch productID {
        case .monthly:
            return productID.shortDescription
        case .annual:
            return annualSavingsText ?? productID.shortDescription
        }
    }

    private var introOfferText: String? {
        guard let product = selectedProduct,
              let offer = product.subscription?.introductoryOffer else { return nil }

        let unitLabel = trialDurationLabel(for: offer.period)

        switch offer.paymentMode {
        case .freeTrial:
            return "Includes a free \(unitLabel) trial"
        case .payUpFront:
            return "Introductory price for \(unitLabel)"
        case .payAsYouGo:
            return "Special introductory pricing for \(unitLabel)"
        default:
            return nil
        }
    }

    private var disclosureText: String {
        let fallbackPrice = "the listed price"
        let price = selectedProduct?.displayPrice ?? fallbackPrice
        let trialPrefix = introOfferText.map { "\($0). " } ?? ""

        switch selectedProductID {
        case .monthly:
            return "\(trialPrefix)Your monthly subscription starts at \(price)/mo and automatically renews unless canceled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel anytime in Settings > Apple ID > Subscriptions."
        case .annual:
            return "\(trialPrefix)Your annual subscription renews at \(price)/yr unless canceled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel anytime in Settings > Apple ID > Subscriptions."
        }
    }

    private var purchaseButtonText: String {
        guard let product = selectedProduct else { return selectedProductID.callToAction }

        if let offer = product.subscription?.introductoryOffer,
           offer.paymentMode == .freeTrial {
            let trialDuration = trialDurationLabel(for: offer.period)
            return "Try free for \(trialDuration), then \(product.displayPrice)\(selectedProductID.billingSuffix)"
        }
        return "\(selectedProductID.callToAction) — \(product.displayPrice)\(selectedProductID.billingSuffix)"
    }

    private func trialDurationLabel(for period: Product.SubscriptionPeriod) -> String {
        let periodValue = period.value

        switch period.unit {
        case .day:
            return periodValue == 1 ? "1 day" : "\(periodValue) days"
        case .week:
            return periodValue == 1 ? "1 week" : "\(periodValue) weeks"
        case .month:
            return periodValue == 1 ? "1 month" : "\(periodValue) months"
        case .year:
            return periodValue == 1 ? "1 year" : "\(periodValue) years"
        @unknown default:
            return "\(periodValue) period(s)"
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

                    PremiumFeaturesCard(features: premiumFeatures)

                    if isLoadingProducts {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if productsFailedToLoad {
                        VStack(spacing: 12) {
                            Text("Unable to load plans. Please check your connection and try again.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await subscriptionManager.initialise() }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.lagoon)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(productOptions, id: \.id) { option in
                                PlanOptionCard(
                                    productID: option.id,
                                    price: option.product?.displayPrice,
                                    description: productDescription(for: option.id),
                                    isSelected: selectedProductID == option.id,
                                    isAvailable: option.product != nil
                                ) {
                                    Haptics.selection()
                                    selectedProductID = option.id
                                }
                            }
                        }
                    }

                    if annualPlanUnavailable {
                        Text("Annual plan is temporarily unavailable. Please try again later.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
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
                                    Text(purchaseButtonText)
                                        .multilineTextAlignment(.center)
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

    private func syncSelectedPlan() {
        if subscriptionManager.annualProduct != nil {
            selectedProductID = .annual
        } else if subscriptionManager.monthlyProduct != nil {
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
            let result = await subscriptionManager.restore()
            isPurchasing = false

            switch result {
            case .success:
                Haptics.success()
                closePaywall()
            case .noPurchaseFound:
                Haptics.warning()
                purchaseError = "No previous premium purchase found."
            case .failed(let message):
                Haptics.error()
                purchaseError = "Restore failed: \(message)"
            }
        }
    }

    private func closePaywall() {
        subscriptionManager.dismissPaywall()
        dismiss()
    }
}

private struct PremiumFeaturesCard: View {
    let features: [PremiumFeature]

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .leading),
        GridItem(.flexible(), spacing: 12, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sipli Premium", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(features) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: feature.icon)
                            .foregroundStyle(Theme.lagoon)
                            .frame(width: 18)

                        Text(feature.title)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.glassBorder.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct PlanOptionCard: View {
    let productID: ProductID
    let price: String?
    let description: String
    let isSelected: Bool
    let isAvailable: Bool
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

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if let price {
                        Text(price)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.lagoon)
                        Text(productID.billingSuffix)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Unavailable")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
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
            .opacity(isAvailable ? 1 : 0.7)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Premium Paywall") {
    PreviewEnvironment {
        PremiumPaywallView(context: PaywallContext(feature: .aiInsights))
    }
}
#endif
