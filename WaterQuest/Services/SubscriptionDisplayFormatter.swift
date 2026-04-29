import Foundation

/// Period over which a subscription's price applies.
enum SubscriptionPeriodUnit: Equatable {
    case month
    case year
}

/// A neutral, test-friendly snapshot of the StoreKit `Product` properties we
/// care about for paywall display. The formatter consumes this rather than
/// `StoreKit.Product` directly so tests can build fixtures without a live
/// store connection.
struct SubscriptionPlanInfo: Equatable {
    let id: String
    /// Localised, currency-formatted price (e.g. "£23.88").
    let displayPrice: String
    /// Total price as a Decimal, in the storefront currency. Used to compute
    /// the per-month rate for the commitment tier and savings vs the monthly
    /// product.
    let price: Decimal
    /// Period covered by `price`. For monthly products this is one month;
    /// for annual + annual-billed-monthly this is one year (the price is the
    /// total covering the 12-month commitment).
    let periodUnit: SubscriptionPeriodUnit
    /// `true` for the new "annual subscription, billed monthly with 12-month
    /// commitment" tier introduced by Apple in iOS 26.5 (May 2026, ex-US/SG).
    /// Distinguished from the upfront annual by App Store Connect config —
    /// surfaced here as a boolean so the formatter can render commitment
    /// language without inspecting product IDs.
    let isMonthlyCommitment: Bool
    /// Currency code for formatting derived monthly prices (e.g. "GBP", "USD").
    let currencyCode: String?
}

/// What the paywall renders for a single plan card.
struct SubscriptionDisplay: Equatable {
    /// Primary line — the price shown big.
    let headline: String
    /// Optional clarifying line directly under the headline. For commitment
    /// tiers this carries the legally-required disclosure (e.g. "Billed
    /// monthly for 12 months").
    let commitment: String?
    /// Optional savings tag relative to the flexible monthly plan.
    /// `nil` when there's nothing to compare or the savings are zero/negative.
    let savings: String?
}

/// Pure display logic for subscription products — no view or StoreKit
/// dependency, fully testable.
protocol SubscriptionFormatting {
    /// - Parameters:
    ///   - plan: the plan being formatted.
    ///   - flexibleMonthly: the flexible-monthly plan, if available, used to
    ///     compute savings for committed tiers.
    func display(for plan: SubscriptionPlanInfo, flexibleMonthly: SubscriptionPlanInfo?) -> SubscriptionDisplay
}

struct SubscriptionFormatter: SubscriptionFormatting {
    func display(for plan: SubscriptionPlanInfo, flexibleMonthly: SubscriptionPlanInfo?) -> SubscriptionDisplay {
        switch (plan.periodUnit, plan.isMonthlyCommitment) {
        case (.month, _):
            return SubscriptionDisplay(
                headline: "\(plan.displayPrice)/month",
                commitment: nil,
                savings: nil
            )
        case (.year, true):
            // Annual subscription billed monthly with a 12-month commitment.
            // Headline shows the per-month rate; the commitment line carries
            // the App Store-mandated 12-month disclosure + total.
            let perMonth = plan.price / 12
            let monthlyDisplay = formatCurrency(perMonth, currencyCode: plan.currencyCode)
                ?? plan.displayPrice
            return SubscriptionDisplay(
                headline: "\(monthlyDisplay)/month",
                commitment: "Billed monthly for 12 months · \(plan.displayPrice) total",
                savings: savingsTag(yearlyTotal: plan.price, flexibleMonthly: flexibleMonthly)
            )
        case (.year, false):
            // Upfront annual.
            return SubscriptionDisplay(
                headline: "\(plan.displayPrice)/year",
                commitment: nil,
                savings: savingsTag(yearlyTotal: plan.price, flexibleMonthly: flexibleMonthly)
            )
        }
    }

    private func savingsTag(yearlyTotal: Decimal, flexibleMonthly: SubscriptionPlanInfo?) -> String? {
        guard let monthly = flexibleMonthly, monthly.periodUnit == .month else { return nil }
        let monthlyYearly = monthly.price * 12
        let savings = monthlyYearly - yearlyTotal
        guard savings > 0 else { return nil }
        let formatted = formatCurrency(savings, currencyCode: monthly.currencyCode) ?? "\(savings)"
        return "Save \(formatted) vs monthly"
    }

    private func formatCurrency(_ value: Decimal, currencyCode: String?) -> String? {
        guard let currencyCode else { return nil }
        return value.formatted(.currency(code: currencyCode))
    }
}
