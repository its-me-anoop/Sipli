import SwiftUI

struct WatchFluidPickerView: View {
    @EnvironmentObject private var store: WatchHydrationStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFluidType: FluidType

    var body: some View {
        List(store.topFluidTypes, id: \.self) { fluidType in
            Button {
                selectedFluidType = fluidType
                WatchHaptics.click()
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: fluidType.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(fluidType.color)
                    Text(fluidType.displayName)
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    if fluidType == selectedFluidType {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.lagoon)
                    }
                }
            }
        }
        .navigationTitle("Beverage")
    }
}
