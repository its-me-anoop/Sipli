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
            .filter { id in
                // Hide the commitment-monthly tier when the feature flag is
                // off so the paywall doesn't render an empty "Unavailable"
                // row for builds we don't ship the new tier on.
                if id == .annualMonthly && !SubscriptionManager.commitmentMonthlyTierEnabled {
                    return false
                }
                return true
            }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { ($0, subscriptionManager.product(for: $0)) }
    }

    private let displayFormatter: SubscriptionFormatting = SubscriptionFormatter()

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

    /// Builds the formatter input for a `PlanOptionCard`. Returns `nil` when
    /// the product hasn't loaded yet (network, sandbox warm-up, etc.) so the
    /// card can show its "Unavailable" treatment.
    private func display(for product: Product?) -> SubscriptionDisplay? {
        guard let product else { return nil }
        let plan = SubscriptionManager.planInfo(from: product)
        return displayFormatter.display(
            for: plan,
            flexibleMonthly: subscriptionManager.flexibleMonthlyPlanInfo
        )
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

    /// Splits the paywall title at the first space and italicises the
    /// trailing words in water-blue — same "mean it." accent as onboarding.
    @ViewBuilder
    private var editorialPaywallTitle: some View {
        let parts = context.title.split(separator: " ", maxSplits: 1).map(String.init)
        let baseFont = Theme.editorialSerif(34)
        if parts.count == 2 {
            (Text(parts[0] + " ").foregroundStyle(Theme.ink)
                + Text(parts[1] + ".").italic().foregroundStyle(Theme.lagoon))
                .font(baseFont)
        } else {
            Text(context.title)
                .font(baseFont)
                .foregroundStyle(Theme.ink)
        }
    }

    private var disclosureText: String {
        let fallbackPrice = "the listed price"
        let price = selectedProduct?.displayPrice ?? fallbackPrice
        let trialPrefix = introOfferText.map { "\($0). " } ?? ""

        switch selectedProductID {
        case .monthly:
            return "\(trialPrefix)Your monthly subscription starts at \(price)/mo and automatically renews unless canceled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel anytime in Settings > Apple ID > Subscriptions."
        case .annualMonthly:
            // Per Apple's "annual subscription, monthly billing" terms: the
            // user is agreeing to 12 monthly payments. Cancelling stops the
            // *next year's* renewal — the current 12-month commitment runs
            // its course.
            let perMonth = annualMonthlyPerMonthDisplay() ?? "the listed monthly amount"
            return "\(trialPrefix)You're committing to 12 monthly payments of \(perMonth) (\(price) total). Cancelling stops next year's renewal — the current 12-month period continues until it ends. Payment is charged to your Apple ID. Manage or cancel anytime in Settings > Apple ID > Subscriptions."
        case .annual:
            return "\(trialPrefix)Your annual subscription renews at \(price)/yr unless canceled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel anytime in Settings > Apple ID > Subscriptions."
        }
    }

    /// Returns the per-month rate for the annual-monthly plan, formatted in
    /// the storefront currency (e.g. "£1.99"). Used by the disclosure copy.
    private func annualMonthlyPerMonthDisplay() -> String? {
        guard let product = subscriptionManager.annualMonthlyProduct else { return nil }
        let perMonth = product.price / 12
        return perMonth.formatted(product.priceFormatStyle)
    }

    private var purchaseButtonText: String {
        guard let product = selectedProduct else { return selectedProductID.callToAction }

        if let offer = product.subscription?.introductoryOffer,
           offer.paymentMode == .freeTrial {
            let trialDuration = trialDurationLabel(for: offer.period)
            return "Try free for \(trialDuration), then \(product.displayPrice)\(selectedProductID.billingSuffix)"
        }
        // For annual-monthly, the CTA reads in per-month terms even though
        // the product price is the yearly total.
        if selectedProductID == .annualMonthly,
           let perMonth = annualMonthlyPerMonthDisplay() {
            return "\(selectedProductID.callToAction) — \(perMonth)/mo"
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

                    Image("sipliIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 132)
                        .accessibilityHidden(true)
                        .padding(.top, 4)

                    VStack(spacing: 12) {
                        editorialPaywallTitle
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        Text(context.message)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
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
                                    display: display(for: option.product),
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
                            HStack(spacing: 10) {
                                if isPurchasing {
                                    ProgressView().tint(.white)
                                    Text("Processing…")
                                } else {
                                    Text(purchaseButtonText)
                                        .multilineTextAlignment(.center)
                                }
                                if !isPurchasing {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Theme.lagoon)
                                    }
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Capsule(style: .continuous).fill(Theme.lagoon))
                        }
                        .buttonStyle(.plain)
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
        // When the commitment-monthly tier is enabled and loaded, default
        // selection to it (low entry, "Recommended" badge). Otherwise fall
        // back to the existing annual-upfront-or-monthly priority.
        if SubscriptionManager.commitmentMonthlyTierEnabled,
           subscriptionManager.annualMonthlyProduct != nil {
            selectedProductID = .annualMonthly
        } else if subscriptionManager.annualProduct != nil {
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
    let display: SubscriptionDisplay?
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

                    Text(productID.shortDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let commitment = display?.commitment {
                        // Mandatory 12-month commitment disclosure for the
                        // "annual subscription, paid monthly" tier — Apple
                        // rejects paywalls that don't make this unmistakable.
                        Text(commitment)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(.top, 2)
                    }

                    if let savings = display?.savings {
                        Text(savings)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.mint)
                    }
                }

                Spacer()

                if let display {
                    Text(display.headline)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.lagoon)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Unavailable")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Theme.lagoon : Theme.glassBorder.opacity(0.6), lineWidth: isSelected ? 2 : 1)
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
