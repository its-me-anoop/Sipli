import SwiftUI

struct AddIntakeView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double = 250
    @State private var note = ""
    @State private var selectedPreset: Int?
    @State private var selectedFluidType: FluidType = .water
    @State private var showSavedBanner = false

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: isRegular ? 14 : 10) {
                    Text("Log Intake")
                        .font(isRegular ? .title.weight(.semibold) : .title2.weight(.semibold))
                    Text("Fast, accurate intake tracking with Health integration.")
                        .font(isRegular ? .body : .subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, isRegular ? 10 : 6)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(amount))")
                        .font(.system(size: isRegular ? 56 : 44, weight: .bold, design: .default))
                    Text(store.profile.unitSystem.volumeUnit)
                        .font(isRegular ? .title2 : .title3)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Slider(value: $amount, in: amountRange, step: amountStep)
                    .tint(selectedFluidType.color)
                    .onChange(of: amount) {
                        selectedPreset = nil
                    }
            }

            Section("Beverage") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: isRegular ? 12 : 8) {
                        ForEach(FluidType.allCases) { type in
                            Button {
                                Haptics.selection()
                                withAnimation(Theme.quickSpring) {
                                    selectedFluidType = type
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: type.iconName)
                                        .font(isRegular ? .title2 : .title3)
                                        .foregroundStyle(selectedFluidType == type ? .white : type.color)
                                        .frame(width: isRegular ? 48 : 40, height: isRegular ? 48 : 40)
                                        .background(
                                            Circle()
                                                .fill(selectedFluidType == type ? type.color : type.color.opacity(0.12))
                                        )
                                    Text(type.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(selectedFluidType == type ? .primary : .secondary)
                                        .lineLimit(1)
                                        .frame(width: isRegular ? 72 : 60)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if selectedFluidType != .water {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("\(selectedFluidType.displayName) counts as \(selectedFluidType.hydrationLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        let effectiveAmount = amount * selectedFluidType.hydrationFactor
                        Text("Effective: \(Int(effectiveAmount)) \(store.profile.unitSystem.volumeUnit)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedFluidType.color)
                    }
                }
            }

            Section("Quick Picks") {
                HStack(spacing: isRegular ? 14 : 8) {
                    ForEach(Array(presetAmounts.enumerated()), id: \.offset) { index, preset in
                        Button {
                            Haptics.selection()
                            selectedPreset = index
                            amount = Double(preset)
                        } label: {
                            VStack(spacing: isRegular ? 4 : 2) {
                                Text("\(preset)")
                                    .font(isRegular ? .title3.weight(.semibold) : .headline)
                                Text(store.profile.unitSystem.volumeUnit)
                                    .font(isRegular ? .subheadline : .caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, isRegular ? 6 : 0)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedPreset == index ? selectedFluidType.color : nil)
                    }
                }
            }

            Section("Note") {
                TextField("Optional context", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Button {
                    addIntake()
                } label: {
                    HStack {
                        Image(systemName: selectedFluidType.iconName)
                        Text("Save Intake")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedFluidType.color)
            }
        }
        .navigationTitle("Log Intake")
        .scrollContentBackground(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
        .overlay(alignment: .top) {
            if showSavedBanner {
                SavedBanner(amount: Int(amount), unit: store.profile.unitSystem.volumeUnit, fluidType: selectedFluidType)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSavedBanner)
        .onAppear {
            if amount < amountRange.lowerBound || amount > amountRange.upperBound {
                amount = min(max(amount, amountRange.lowerBound), amountRange.upperBound)
            }
        }
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
        Haptics.splash()

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = store.addIntake(amount: amount, source: .manual, fluidType: selectedFluidType, note: trimmed.isEmpty ? nil : trimmed)

        Task {
            await healthKit.saveWaterIntake(ml: entry.volumeML, date: entry.date, entryID: entry.id)
        }

        withAnimation {
            showSavedBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismiss()
        }

        note = ""
        selectedPreset = nil
        selectedFluidType = .water
    }
}

private struct SavedBanner: View {
    let amount: Int
    let unit: String
    let fluidType: FluidType

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: fluidType.iconName)
                .foregroundStyle(fluidType.color)
            Text("Logged \(amount) \(unit) \(fluidType.displayName)")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
        .shadow(color: Theme.shadowColor, radius: 8, x: 0, y: 4)
    }
}

#Preview("Add Intake") {
    PreviewEnvironment {
        AddIntakeView()
    }
}
