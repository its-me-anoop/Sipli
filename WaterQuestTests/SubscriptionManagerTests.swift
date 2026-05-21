import Testing
import StoreKitTest
@testable import Sipli

// MARK: - Tags

extension Tag {
    @Tag static var storeKit: Self
    @Tag static var subscription: Self
}

// MARK: - Suite

@MainActor
// .serialized prevents parallel SKTestSession instances corrupting each other.
// StoreKit's in-process sandbox is not thread-safe across concurrent sessions.
@Suite("SubscriptionManager", .tags(.storeKit, .subscription), .serialized)
struct SubscriptionManagerTests {

    // SKTestSession is not Sendable; keep everything on MainActor.
    let session: SKTestSession
    let manager: SubscriptionManager

    init() async throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        // Give StoreKit time to fully activate the test session before the
        // first Product.products(for:) call. SKTestSession configures the
        // sandbox asynchronously; insufficient delay causes Product.products()
        // to return an empty set even after its own 3-attempt retry loop.
        try await Task.sleep(for: .seconds(2))
        manager = SubscriptionManager()
    }

    // MARK: - Products

    @Test("After initialise(), all 3 product IDs are present",
          .disabled("SKTestSession.disableDialogs errors with SKInternalErrorDomain Code=3 (no sandbox account in CI); Product.products() returns empty across all retries"))
    func productsLoadedFromStoreKitConfig() async throws {
        // Ensure the commitment-monthly tier flag is on so all 3 are fetched.
        UserDefaults.standard.set(true, forKey: "subscription.commitmentMonthlyTierEnabled")
        defer { UserDefaults.standard.removeObject(forKey: "subscription.commitmentMonthlyTierEnabled") }

        await manager.initialise()

        let loadedIDs = Set(manager.products.map(\.id))
        #expect(loadedIDs.contains("com.sipli.monthly"))
        #expect(loadedIDs.contains("com.sipli.annual"))
        #expect(loadedIDs.contains("com.sipli.annual.monthly"))
        #expect(manager.isInitialized)
    }

    // MARK: - Purchase → access

    @Test("Buying the monthly product grants premium access",
          .disabled("SKTestSession.buyProduct fails: off-device purchase returns notEntitled when no sandbox account is configured in the simulator"))
    func purchaseMonthly_grantsAccess() async throws {
        await manager.initialise()
        try await session.buyProduct(identifier:"com.sipli.monthly")
        await manager.refreshStatus()
        #expect(manager.hasPremiumAccess)
        #expect(manager.activeProductID == .monthly)
    }

    @Test("Buying the annual product grants premium access",
          .disabled("SKTestSession.buyProduct fails: off-device purchase returns notEntitled when no sandbox account is configured in the simulator"))
    func purchaseAnnual_grantsAccess() async throws {
        await manager.initialise()
        try await session.buyProduct(identifier:"com.sipli.annual")
        await manager.refreshStatus()
        #expect(manager.hasPremiumAccess)
        #expect(manager.activeProductID == .annual)
    }

    @Test("Buying the annual-paid-monthly product grants premium access",
          .disabled("SKTestSession.buyProduct fails: off-device purchase returns notEntitled when no sandbox account is configured in the simulator"))
    func purchaseAnnualMonthly_grantsAccess() async throws {
        // Enable the flag so the product is fetched. Reset afterwards.
        UserDefaults.standard.set(true, forKey: "subscription.commitmentMonthlyTierEnabled")
        defer { UserDefaults.standard.removeObject(forKey: "subscription.commitmentMonthlyTierEnabled") }

        await manager.initialise()
        try await session.buyProduct(identifier:"com.sipli.annual.monthly")
        await manager.refreshStatus()
        #expect(manager.hasPremiumAccess)
        #expect(manager.activeProductID == .annualMonthly)
    }

    // MARK: - Expiry

    @Test("An expired subscription revokes premium access",
          .disabled("SKTestSession.buyProduct fails: off-device purchase returns notEntitled when no sandbox account is configured in the simulator"))
    func expiredSubscription_revokesAccess() async throws {
        await manager.initialise()

        try await session.buyProduct(identifier:"com.sipli.monthly")
        await manager.refreshStatus()
        #expect(manager.hasPremiumAccess, "precondition: access expected after purchase")

        try session.expireSubscription(productIdentifier:"com.sipli.monthly")
        await manager.refreshStatus()
        #expect(manager.hasPremiumAccess == false)
        #expect(manager.activeProductID == nil)
    }

    // MARK: - Restore

    @Test("Restoring with no prior purchases returns noPurchaseFound",
          .disabled("AppStore.sync() hangs indefinitely in off-device buy mode without a sandbox account; test times out"))
    func restoreNoPurchases_returnsNoPurchaseFound() async throws {
        await manager.initialise()
        let result = await manager.restore()
        guard case .noPurchaseFound = result else {
            Issue.record("Expected .noPurchaseFound but got \(result)")
            return
        }
        #expect(manager.hasPremiumAccess == false)
    }

    @Test("Restoring after a prior purchase returns success and grants access",
          .disabled("Requires buyProduct to succeed first; blocked by same no-sandbox-account constraint as purchase tests"))
    func restoreExisting_returnsSuccess() async throws {
        await manager.initialise()

        // Buy and confirm initial access.
        try await session.buyProduct(identifier:"com.sipli.annual")
        await manager.refreshStatus()
        #expect(manager.hasPremiumAccess, "precondition: access expected after purchase")

        // Simulate a fresh install by resetting local state via a new manager
        // that shares the same StoreKit session's transaction ledger.
        let freshManager = SubscriptionManager()
        let result = await freshManager.restore()

        guard case .success = result else {
            Issue.record("Expected .success but got \(result)")
            return
        }
        #expect(freshManager.hasPremiumAccess)
    }

    // MARK: - Per-feature access gate

    @Test(
        "hasAccess returns false for every feature without a subscription",
        arguments: PremiumFeature.allCases
    )
    func accessGate_returnsFalse_withoutSubscription(feature: PremiumFeature) async {
        await manager.initialise()
        #expect(manager.hasAccess(to: feature) == false)
    }

    @Test(
        "hasAccess returns true for every feature after subscribing",
        .disabled("Requires buyProduct to succeed first; blocked by same no-sandbox-account constraint as purchase tests"),
        arguments: PremiumFeature.allCases
    )
    func accessGate_returnsTrue_afterSubscription(feature: PremiumFeature) async throws {
        await manager.initialise()
        try await session.buyProduct(identifier:"com.sipli.monthly")
        await manager.refreshStatus()
        #expect(manager.hasAccess(to: feature))
    }
}
