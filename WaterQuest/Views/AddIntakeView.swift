import SwiftUI

struct AddIntakeView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double = 250
    @State private var selectedPreset: Int?
    @State private var selectedFluidType: FluidType = .water
    @State private var showSavedBanner = false
    @State private var rippleTrigger = 0

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: isRegular ? 14 : 10) {
                    Text("Log Intake")
                        .font(isRegular ? .title.weight(.semibold) : .title2.weight(.semibold))
                    Text("Basic water logging is free. Premium adds beverage types and HealthKit sync.")
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
                if subscriptionManager.hasAccess(to: .fluidTypes) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: isRegular ? 12 : 8) {
                            ForEach(store.rankedFluidTypes) { type in
                                Button {
                                    Haptics.selection()
                                    withAnimation(Theme.quickSpring) {
                                        selectedFluidType = type
                                        amount = store.profile.unitSystem.amount(fromML: type.defaultServingML)
                                        selectedPreset = nil
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
                                .accessibilityLabel(type.displayName)
                                .accessibilityHint("\(type.hydrationLabel). Double tap to select")
                                .accessibilityAddTraits(selectedFluidType == type ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: FluidType.water.iconName)
                                .foregroundStyle(Theme.lagoon)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Theme.lagoon.opacity(0.12))
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Water")
                                    .font(.subheadline.weight(.semibold))
                                Text("Premium unlocks coffee, tea, juice, smoothies, sports drinks, and more.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Unlock") {
                                Haptics.selection()
                                subscriptionManager.presentPaywall(for: .fluidTypes)
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
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
                    .padding(.vertical, 10)
                    .font(isRegular ? .title3 : .body)
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedFluidType.color)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Log Intake")
        .scrollContentBackground(.hidden)
        .background {
            AppWaterBackground()
                .ignoresSafeArea()
                .modifier(RippleEffect(
                    at: CGPoint(x: UIScreen.main.bounds.width / 2, y: 200),
                    trigger: rippleTrigger
                ))
        }
        .overlay(alignment: .top) {
            if showSavedBanner {
                SavedBanner(amount: Int(amount), unit: store.profile.unitSystem.volumeUnit, fluidType: selectedFluidType)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSavedBanner)
        .onAppear {
            if !subscriptionManager.hasAccess(to: .fluidTypes) {
                selectedFluidType = .water
            }
            amount = store.profile.unitSystem.amount(fromML: selectedFluidType.defaultServingML)
            amount = min(max(amount, amountRange.lowerBound), amountRange.upperBound)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                rippleTrigger += 1
            }
        }
    }

    private var amountRange: ClosedRange<Double> {
        store.profile.unitSystem == .metric ? 10...1200 : 1...40
    }

    private var amountStep: Double {
        store.profile.unitSystem == .metric ? 10 : 1
    }

    private func addIntake() {
        Haptics.splash()

        let entry = store.addIntake(amount: amount, source: .manual, fluidType: selectedFluidType, note: nil)

        Task {
            guard subscriptionManager.hasAccess(to: .healthKitSync), store.effectiveProfile.prefersHealthKit else { return }
            await healthKit.saveWaterIntake(ml: entry.volumeML, date: entry.date, entryID: entry.id)
        }

        withAnimation {
            showSavedBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }

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
                .fill(Theme.card)
        )
        .shadow(color: Theme.shadowColor, radius: 8, x: 0, y: 4)
    }
}

#if DEBUG
#Preview("Add Intake") {
    PreviewEnvironment {
        AddIntakeView()
    }
}
#endif
