import SwiftUI

struct WatchQuickAddView: View {
    @EnvironmentObject private var store: WatchHydrationStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAmountDouble: Double = 2.0
    @State private var selectedFluidType: FluidType = .water
    @State private var showFluidPicker = false
    @State private var logged = false

    private let amounts: [Double] = [150, 200, 250, 330, 500, 750]

    private var selectedAmountIndex: Int {
        min(max(Int(selectedAmountDouble.rounded()), 0), amounts.count - 1)
    }

    private var displayAmount: String {
        Formatters.shortVolume(ml: amounts[selectedAmountIndex], unit: store.profile.unitSystem)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Add \(selectedFluidType.displayName)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text(displayAmount)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .focusable()
                .digitalCrownRotation(
                    $selectedAmountDouble,
                    from: 0,
                    through: Double(amounts.count - 1),
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

            Button {
                store.addIntake(volumeML: amounts[selectedAmountIndex], fluidType: selectedFluidType)
                WatchHaptics.success()
                logged = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            } label: {
                Label("Log \(selectedFluidType == .water ? "Water" : selectedFluidType.displayName)", systemImage: "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.11, green: 0.47, blue: 0.96))
            .disabled(logged)

            Button {
                showFluidPicker = true
            } label: {
                Text("More beverages")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.11, green: 0.47, blue: 0.96))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showFluidPicker) {
            WatchFluidPickerView(selectedFluidType: $selectedFluidType)
        }
    }
}
