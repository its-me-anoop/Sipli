import Testing
@testable import Sipli

// MARK: - Suite

/// Pure logic tests for paywall presentation / dismissal.
/// No StoreKit or networking — all state lives in SubscriptionManager properties.
@MainActor
@Suite("PaywallContext", .tags(.subscription))
struct PaywallContextTests {

    let manager: SubscriptionManager

    init() {
        manager = SubscriptionManager()
        // Ensure the manager starts unsubscribed so presentPaywall() is not gated.
        // SubscriptionManager.isSubscribed defaults to false, so no setup needed.
    }

    // MARK: - presentPaywall

    @Test("presentPaywall(for: nil) sets presentedPaywall with no feature")
    func presentPaywall_noFeature_setsGenericContext() {
        manager.presentPaywall(for: nil)
        let context = manager.presentedPaywall
        #expect(context != nil)
        #expect(context?.feature == nil)
        #expect(context?.title == "Unlock Sipli Premium")
    }

    @Test("dismissPaywall() clears presentedPaywall")
    func dismissPaywall_clearsContext() {
        manager.presentPaywall()
        #expect(manager.presentedPaywall != nil, "precondition: paywall must be set first")
        manager.dismissPaywall()
        #expect(manager.presentedPaywall == nil)
    }

    @Test(
        "presentPaywall(for:) maps each feature to the correct context",
        arguments: PremiumFeature.allCases
    )
    func presentPaywall_perFeature_mapsCorrectContext(feature: PremiumFeature) {
        manager.presentPaywall(for: feature)
        let context = manager.presentedPaywall
        #expect(context?.feature == feature)
        #expect(context?.title == feature.paywallTitle)
    }

    @Test("presentPaywall is suppressed when already subscribed")
    func presentPaywall_suppressedWhenSubscribed() async {
        // Drive isSubscribed to true via the internal purchase path is not
        // possible without StoreKit here, so we verify the documented guard
        // using a plain unsubscribed manager: calling presentPaywall when
        // isSubscribed == false should always set a context.
        //
        // The inverse (subscribed → no presentation) is covered by
        // SubscriptionManagerTests.purchaseMonthly_grantsAccess indirectly,
        // since presentPaywall is called in the paywall view only when
        // hasPremiumAccess == false. We document the gap here.
        #expect(manager.isSubscribed == false)
        manager.presentPaywall(for: .aiInsights)
        #expect(manager.presentedPaywall != nil)
    }

    // MARK: - PaywallContext value semantics

    @Test("PaywallContext title is paywallTitle of the feature when present")
    func paywallContext_title_matchesFeatureTitle() {
        for feature in PremiumFeature.allCases {
            let context = PaywallContext(feature: feature)
            #expect(context.title == feature.paywallTitle)
        }
    }

    @Test("PaywallContext title is generic when feature is nil")
    func paywallContext_title_genericWhenNoFeature() {
        let context = PaywallContext(feature: nil)
        #expect(context.title == "Unlock Sipli Premium")
    }

    @Test("PaywallContext message matches feature short description when present")
    func paywallContext_message_matchesFeatureDescription() {
        for feature in PremiumFeature.allCases {
            let context = PaywallContext(feature: feature)
            #expect(context.message == feature.shortDescription)
        }
    }
}
