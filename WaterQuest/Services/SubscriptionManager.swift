import Foundation
import StoreKit

enum ProductID: String, CaseIterable, Identifiable {
    case monthly = "com.sipli.monthly"
    case annual = "com.sipli.annual"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly:
            return "Monthly"
        case .annual:
            return "Annual"
        }
    }

    var shortDescription: String {
        switch self {
        case .monthly:
            return "Monthly billing"
        case .annual:
            return "Annual billing"
        }
    }

    var billingSuffix: String {
        switch self {
        case .monthly:
            return "/mo"
        case .annual:
            return "/yr"
        }
    }

    var badgeText: String? {
        switch self {
        case .monthly:
            return nil
        case .annual:
            return "Best Value"
        }
    }

    var sortOrder: Int {
        switch self {
        case .annual:
            return 0
        case .monthly:
            return 1
        }
    }

    var callToAction: String {
        switch self {
        case .monthly:
            return "Start Monthly Plan"
        case .annual:
            return "Start Annual Plan"
        }
    }
}

enum PremiumFeature: String, CaseIterable, Identifiable {
    case fluidTypes
    case aiInsights
    case healthKitSync
    case weatherGoals
    case activityGoals
    case smartReminders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fluidTypes:
            return "Beverage Types"
        case .aiInsights:
            return "AI Insights"
        case .healthKitSync:
            return "HealthKit Sync"
        case .weatherGoals:
            return "Weather Goals"
        case .activityGoals:
            return "Activity Goals"
        case .smartReminders:
            return "Smart Reminders"
        }
    }

    var icon: String {
        switch self {
        case .fluidTypes:
            return "cup.and.saucer.fill"
        case .aiInsights:
            return "brain.head.profile.fill"
        case .healthKitSync:
            return "heart.fill"
        case .weatherGoals:
            return "cloud.sun.fill"
        case .activityGoals:
            return "figure.run"
        case .smartReminders:
            return "bell.badge.fill"
        }
    }

    var shortDescription: String {
        switch self {
        case .fluidTypes:
            return "Track coffee, tea, juice, smoothies, sports drinks, and more with hydration factors."
        case .aiInsights:
            return "Unlock AI hydration coaching tips and personalized insight summaries."
        case .healthKitSync:
            return "Sync water intake and workouts with Apple Health."
        case .weatherGoals:
            return "Adjust your daily goal for local temperature and humidity."
        case .activityGoals:
            return "Raise your goal automatically after workouts and active days."
        case .smartReminders:
            return "Get adaptive reminders that respond to your schedule and progress."
        }
    }

    var paywallTitle: String {
        switch self {
        case .fluidTypes:
            return "Unlock Beverage Tracking"
        case .aiInsights:
            return "Unlock AI Guidance"
        case .healthKitSync:
            return "Unlock HealthKit Sync"
        case .weatherGoals:
            return "Unlock Weather Goals"
        case .activityGoals:
            return "Unlock Activity Goals"
        case .smartReminders:
            return "Unlock Smart Reminders"
        }
    }
}

struct PaywallContext: Identifiable, Equatable {
    let id = UUID()
    let feature: PremiumFeature?

    init(feature: PremiumFeature? = nil) {
        self.feature = feature
    }

    var title: String {
        feature?.paywallTitle ?? "Unlock Sipli Premium"
    }

    var message: String {
        if let feature {
            return feature.shortDescription
        }
        return "Premium adds beverage types, AI insights, HealthKit sync, adaptive goals, and smart reminders."
    }
}

// MARK: - SubscriptionManager
/// Manages StoreKit 2 auto-renewable subscription state.
@MainActor
final class SubscriptionManager: ObservableObject {
    /// `true` when the user has an active subscription.
    @Published private(set) var isSubscribed: Bool = false
    /// `true` once initial products and status have been loaded.
    @Published private(set) var isInitialized: Bool = false

    /// The fetched StoreKit products.
    @Published private(set) var products: [Product] = []
    /// The currently active premium product, if any.
    @Published private(set) var activeProductID: ProductID?
    /// The currently presented paywall.
    @Published var presentedPaywall: PaywallContext?

    var hasPremiumAccess: Bool {
        isSubscribed
    }

    var availableProducts: [Product] {
        products.sorted { lhs, rhs in
            let lhsOrder = ProductID(rawValue: lhs.id)?.sortOrder ?? .max
            let rhsOrder = ProductID(rawValue: rhs.id)?.sortOrder ?? .max
            if lhsOrder == rhsOrder {
                return lhs.id < rhs.id
            }
            return lhsOrder < rhsOrder
        }
    }

    // MARK: - Lifecycle
    /// Call once early in the app lifecycle (e.g. in a `.task` on the root view).
    /// Fetches products and checks for an active subscription.
    func initialise() async {
        await fetchProducts()
        await refreshSubscriptionStatus()
        isInitialized = true
    }

    // MARK: - Products
    private func fetchProducts() async {
        let ids = Set(ProductID.allCases.map { $0.rawValue })
        let maxAttempts = 3

        for attempt in 1...maxAttempts {
            do {
                let fetched = try await Product.products(for: ids)
                products = fetched.sorted {
                    let lhsOrder = ProductID(rawValue: $0.id)?.sortOrder ?? .max
                    let rhsOrder = ProductID(rawValue: $1.id)?.sortOrder ?? .max
                    if lhsOrder == rhsOrder {
                        return $0.id < $1.id
                    }
                    return lhsOrder < rhsOrder
                }

                // All expected products loaded — done.
                if products.count == ids.count { return }

                #if DEBUG
                let missing = ids.subtracting(fetched.map(\.id))
                print("SubscriptionManager: attempt \(attempt) – missing products: \(missing)")
                #endif
            } catch {
                #if DEBUG
                print("SubscriptionManager: attempt \(attempt) failed – \(error)")
                #endif
            }

            // Wait before retrying (StoreKit env may not be ready yet).
            if attempt < maxAttempts {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Returns the monthly product, if loaded.
    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthly.rawValue }
    }

    /// Returns the annual product, if loaded.
    var annualProduct: Product? {
        products.first { $0.id == ProductID.annual.rawValue }
    }

    var featuredProduct: Product? {
        annualProduct ?? monthlyProduct
    }

    var currentPlanName: String {
        activeProductID?.displayName ?? "Premium"
    }

    func product(for id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    func hasAccess(to feature: PremiumFeature) -> Bool {
        switch feature {
        case .fluidTypes, .aiInsights, .healthKitSync, .weatherGoals, .activityGoals, .smartReminders:
            return hasPremiumAccess
        }
    }

    func presentPaywall(for feature: PremiumFeature? = nil) {
        guard !isSubscribed else { return }
        presentedPaywall = PaywallContext(feature: feature)
    }

    func dismissPaywall() {
        presentedPaywall = nil
    }

    // MARK: - Purchase
    enum PurchaseResult {
        case success
        case cancelled
        case pending
        case failed(String)
    }

    /// Initiates a purchase for the given product.
    func purchase(_ product: Product) async -> PurchaseResult {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                    return .success
                case .unverified(_, let error):
                    return .failed("Verification failed: \(error.localizedDescription)")
                }
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed("Unexpected result")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore
    /// Restores previous purchases.  Returns `true` if an active entitlement was found.
    enum RestoreResult {
        case success
        case noPurchaseFound
        case failed(String)
    }

    func restore() async -> RestoreResult {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            return isSubscribed ? .success : .noPurchaseFound
        } catch {
            #if DEBUG
            print("SubscriptionManager: restore failed – \(error)")
            #endif
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Status
    /// Checks `Transaction.currentEntitlements` for an active subscription
    /// and updates `isSubscribed` accordingly.
    private func refreshSubscriptionStatus() async {
        var matchedProductID: ProductID?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if let productID = ProductID(rawValue: transaction.productID) {
                matchedProductID = productID
                break
            }
        }
        activeProductID = matchedProductID
        isSubscribed = matchedProductID != nil
    }

    /// Public wrapper to re-check the current entitlement state.
    func refreshStatus() async {
        await refreshSubscriptionStatus()
    }

    // MARK: - Transaction listener
    /// Starts a background task that listens for new transactions (e.g. renewals
    /// or purchases made outside the app).  Call once and keep the returned task alive.
    func startTransactionListener() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    if ProductID(rawValue: transaction.productID) != nil {
                        await refreshSubscriptionStatus()
                        await transaction.finish()
                    }
                }
            }
        }
    }
}
