import SwiftUI

struct AddIntakeView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager

    @State private var amount: Double = 250
    @State private var note: String = ""

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Log a Drink")
                    .font(Theme.titleFont(size: 26))
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    Text("Amount (\(store.profile.unitSystem.volumeUnit))")
                        .font(Theme.bodyFont(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Slider(value: $amount, in: amountRange, step: amountStep)
                    Text(String(format: "%.0f", amount))
                        .font(Theme.titleFont(size: 30))
                        .foregroundColor(.white)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.card)
                )

                HStack(spacing: 12) {
                    ForEach(presetAmounts, id: \.self) { preset in
                        Button("\(preset)") {
                            amount = Double(preset)
                        }
                        .font(Theme.bodyFont(size: 14))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Capsule().fill(Theme.lagoon.opacity(0.25)))
                        .foregroundColor(.white)
                    }
                }

                TextField("Note (optional)", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.bodyFont(size: 14))
                    .padding(.horizontal, 24)

                Button("Add to Quest Log") {
                    addIntake()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var amountRange: ClosedRange<Double> {
        store.profile.unitSystem == .metric ? 100...1200 : 4...40
    }

    private var amountStep: Double {
        store.profile.unitSystem == .metric ? 25 : 1
    }

    private var presetAmounts: [Int] {
        store.profile.unitSystem == .metric ? [200, 350, 500, 750] : [8, 12, 16, 24]
    }

    private func addIntake() {
        store.addIntake(amount: amount, source: .manual)
        Task {
            await healthKit.saveWaterIntake(ml: store.profile.unitSystem.ml(from: amount))
        }
        note = ""
    }
}

#Preview("Add Intake") {
    PreviewEnvironment {
        AddIntakeView()
    }
}
