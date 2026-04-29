import XCTest
@testable import Sipli

final class SubscriptionDisplayFormatterTests: XCTestCase {

    private let formatter = SubscriptionFormatter()

    // MARK: - Fixtures

    /// Flexible monthly — the existing £2.99/mo plan.
    private let monthly = SubscriptionPlanInfo(
        id: "com.sipli.monthly",
        displayPrice: "£2.99",
        price: Decimal(string: "2.99")!,
        periodUnit: .month,
        isMonthlyCommitment: false,
        currencyCode: "GBP"
    )

    /// New tier — annual subscription billed monthly with 12-month
    /// commitment, total £23.88 (≈ £1.99/mo).
    private let annualMonthly = SubscriptionPlanInfo(
        id: "com.sipli.annual.monthly",
        displayPrice: "£23.88",
        price: Decimal(string: "23.88")!,
        periodUnit: .year,
        isMonthlyCommitment: true,
        currencyCode: "GBP"
    )

    /// Upfront annual — the existing £19.99/yr plan.
    private let annual = SubscriptionPlanInfo(
        id: "com.sipli.annual",
        displayPrice: "£19.99",
        price: Decimal(string: "19.99")!,
        periodUnit: .year,
        isMonthlyCommitment: false,
        currencyCode: "GBP"
    )

    // MARK: - Monthly

    func test_display_flexibleMonthly_headline_isPerMonthPrice() {
        let result = formatter.display(for: monthly, flexibleMonthly: monthly)
        XCTAssertEqual(result.headline, "£2.99/month")
    }

    func test_display_flexibleMonthly_hasNoCommitmentLine() {
        let result = formatter.display(for: monthly, flexibleMonthly: monthly)
        XCTAssertNil(result.commitment)
    }

    func test_display_flexibleMonthly_hasNoSavingsTag() {
        let result = formatter.display(for: monthly, flexibleMonthly: monthly)
        XCTAssertNil(result.savings)
    }

    // MARK: - Annual upfront

    func test_display_annualUpfront_headline_isPerYearPrice() {
        let result = formatter.display(for: annual, flexibleMonthly: monthly)
        XCTAssertEqual(result.headline, "£19.99/year")
    }

    func test_display_annualUpfront_hasNoCommitmentLine() {
        let result = formatter.display(for: annual, flexibleMonthly: monthly)
        XCTAssertNil(result.commitment)
    }

    func test_display_annualUpfront_savingsAreYearlyDifference() {
        // 12 × £2.99 = £35.88; £35.88 − £19.99 = £15.89 saved.
        let result = formatter.display(for: annual, flexibleMonthly: monthly)
        XCTAssertEqual(result.savings, "Save £15.89 vs monthly")
    }

    // MARK: - Annual subscription, billed monthly (the new tier)

    func test_display_annualMonthly_headline_isPerMonthRate() {
        // £23.88 ÷ 12 = £1.99
        let result = formatter.display(for: annualMonthly, flexibleMonthly: monthly)
        XCTAssertEqual(result.headline, "£1.99/month")
    }

    func test_display_annualMonthly_carries12MonthDisclosure() {
        let result = formatter.display(for: annualMonthly, flexibleMonthly: monthly)
        XCTAssertEqual(result.commitment, "Billed monthly for 12 months · £23.88 total")
    }

    func test_display_annualMonthly_savingsCalculatedAgainstMonthly() {
        // 12 × £2.99 = £35.88; £35.88 − £23.88 = £12.00 saved.
        let result = formatter.display(for: annualMonthly, flexibleMonthly: monthly)
        XCTAssertEqual(result.savings, "Save £12.00 vs monthly")
    }

    func test_display_annualMonthly_savingsAreNilWhenMonthlyMissing() {
        let result = formatter.display(for: annualMonthly, flexibleMonthly: nil)
        XCTAssertNil(result.savings)
    }

    // MARK: - Edge cases

    func test_display_savingsAreNilWhenAnnualIsMoreExpensiveThanTwelveMonths() {
        // Hypothetical: annual is more expensive than 12× monthly. Don't
        // surface a misleading "Save" tag.
        let inflatedAnnual = SubscriptionPlanInfo(
            id: "com.sipli.annual",
            displayPrice: "£40.00",
            price: Decimal(string: "40")!,
            periodUnit: .year,
            isMonthlyCommitment: false,
            currencyCode: "GBP"
        )
        let result = formatter.display(for: inflatedAnnual, flexibleMonthly: monthly)
        XCTAssertNil(result.savings)
    }

    func test_display_perMonthRate_handlesUSDCurrencyCode() {
        let usdMonthly = SubscriptionPlanInfo(
            id: "com.sipli.annual.monthly",
            displayPrice: "$23.88",
            price: Decimal(string: "23.88")!,
            periodUnit: .year,
            isMonthlyCommitment: true,
            currencyCode: "USD"
        )
        let result = formatter.display(for: usdMonthly, flexibleMonthly: nil)
        XCTAssertTrue(result.headline.contains("/month"),
                      "headline should still carry the /month suffix; got \(result.headline)")
    }
}
