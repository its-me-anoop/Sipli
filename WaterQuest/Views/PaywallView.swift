import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var isDismissible: Bool = true

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var restoreSuccess = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let privacyURL = URL(string: "https://example.com/privacy")!
    private let termsURL = URL(string: "https://example.com/terms")!

    var body: some View {
        NavigationStack {
            ZStack {
                AppWaterBackground().ignoresSafeArea()

                List {
                    Section {
                        header
                    }

                    Section("What you unlock") {
                        featureRow(icon: "chart.line.uptrend.xyaxis", text: "Detailed hydration trends")
                        featureRow(icon: "clock.fill", text: "Extended intake history")
                        featureRow(icon: "trophy.fill", text: "Full quests and milestones")
                        featureRow(icon: "sparkles", text: "Personalized hydration coaching")
                        featureRow(icon: "sun.max.fill", text: "Weather + workout goal tuning")
                    }

                    Section("Choose a plan") {
                        plansContent
                    }

                    if let product = resolvedProduct {
                        Section {
                            Button {
                                doPurchase(product)
                            } label: {
                                if isPurchasing {
                                    HStack {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Processing…")
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Text("Start Pro - \(product.displayPrice)")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isPurchasing)
                        }
                    }

                    if let purchaseError {
                        Section {
                            Text(purchaseError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        Button(restoreSuccess ? "Restored" : "Restore Purchase") {
                            doRestore()
                        }
                        .disabled(isPurchasing)
                    }

                    Section {
                        Text("Payment is charged to your Apple ID at confirmation. Subscription renews automatically unless canceled at least 24 hours before renewal.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack {
                            Link("Privacy Policy", destination: privacyURL)
                            Spacer()
                            Link("Terms of Use", destination: termsURL)
                        }
                        .font(.footnote)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Thirsty.ai Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isDismissible {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                if selectedProduct == nil {
                    selectedProduct = subscriptionManager.annualProduct ?? subscriptionManager.monthlyProduct
                }
            }
        }
    }

    private var isRegular: Bool { sizeClass == .regular }

    private var header: some View {
        VStack(spacing: isRegular ? 14 : 10) {
            Image(systemName: "drop.fill")
                .font(.system(size: isRegular ? 54 : 44, weight: .semibold))
                .foregroundStyle(Theme.lagoon)
                .frame(width: isRegular ? 112 : 96, height: isRegular ? 112 : 96)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )

            Text("Upgrade for deeper hydration guidance")
                .font(isRegular ? .title2.weight(.semibold) : .title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("Choose monthly or yearly access. Cancel anytime in App Store settings.")
                .font(isRegular ? .body : .subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isRegular ? 12 : 8)
    }

    @ViewBuilder
    private var plansContent: some View {
        if subscriptionManager.products.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else {
            if let annual = subscriptionManager.annualProduct {
                PlanRow(
                    title: "Yearly",
                    subtitle: perMonthText(for: annual).map { "\($0)/month" } ?? "Best value",
                    price: annual.displayPrice,
                    isSelected: selectedProduct?.id == annual.id,
                    isBestValue: true
                ) {
                    selectedProduct = annual
                }
            }

            if let monthly = subscriptionManager.monthlyProduct {
                PlanRow(
                    title: "Monthly",
                    subtitle: "Flexible monthly billing",
                    price: monthly.displayPrice,
                    isSelected: selectedProduct?.id == monthly.id,
                    isBestValue: false
                ) {
                    selectedProduct = monthly
                }
            }
        }
    }

    private var resolvedProduct: Product? {
        selectedProduct ?? subscriptionManager.annualProduct ?? subscriptionManager.monthlyProduct
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.lagoon)
                .frame(width: 22)
            Text(text)
            Spacer()
        }
    }

    private func perMonthText(for annual: Product) -> String? {
        let monthly = annual.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: monthly))
    }

    private func doPurchase(_ product: Product) {
        isPurchasing = true
        purchaseError = nil

        Task {
            let success = await subscriptionManager.purchase(product)
            await MainActor.run {
                isPurchasing = false
                if success {
                    Haptics.success()
                    dismiss()
                } else {
                    Haptics.error()
                    purchaseError = "Purchase did not complete. Please try again."
                }
            }
        }
    }

    private func doRestore() {
        isPurchasing = true
        purchaseError = nil

        Task {
            let success = await subscriptionManager.restore()
            await MainActor.run {
                isPurchasing = false
                if success {
                    restoreSuccess = true
                    Haptics.success()
                    dismiss()
                } else {
                    Haptics.warning()
                    purchaseError = "No previous purchase found."
                }
            }
        }
    }
}

private struct PlanRow: View {
    let title: String
    let subtitle: String
    let price: String
    let isSelected: Bool
    let isBestValue: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            onSelect()
        }) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        if isBestValue {
                            Text("Best Value")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.sun.opacity(0.2)))
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(price)
                    .font(.headline)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.lagoon : .secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Theme.lagoon : Theme.glassBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Paywall") {
    PreviewEnvironment {
        PaywallView(isDismissible: true)
    }
    .environmentObject(SubscriptionManager())
}
#endif
