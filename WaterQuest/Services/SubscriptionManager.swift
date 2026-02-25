import Foundation
import StoreKit

// MARK: - Product IDs
enum ProductID: String, CaseIterable {
    case monthly = "com.sipli.monthly"
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
        do {
            let ids = Set(ProductID.allCases.map { $0.rawValue })
            products = try await Product.products(for: ids)
        } catch {
            #if DEBUG
            print("SubscriptionManager: failed to fetch products – \(error)")
            #endif
        }
    }

    /// Returns the monthly product, if loaded.
    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthly.rawValue }
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
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            return isSubscribed
        } catch {
            #if DEBUG
            print("SubscriptionManager: restore failed – \(error)")
            #endif
            return false
        }
    }

    // MARK: - Status
    /// Checks `Transaction.currentEntitlements` for an active subscription
    /// and updates `isSubscribed` accordingly.
    private func refreshSubscriptionStatus() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if ProductID(rawValue: transaction.productID) != nil {
                    hasActive = true
                    break
                }
            }
        }
        isSubscribed = hasActive
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
                    }
                }
            }
        }
    }
}
