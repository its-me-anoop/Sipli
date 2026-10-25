import SwiftUI

struct AddIntakeView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var compactContentHeight: CGFloat?
    @State private var footerHeight: CGFloat = 72

    @State private var amount: Double = 250
    @State private var selectedPreset: Int?
    @State private var selectedFluidType: FluidType = .water
    @State private var showSavedBanner = false
    @State private var savedIntake: HydrationEntry?
    @State private var rippleTrigger = 0
    @State private var amountLabelScale: Double = 1.0
    @State private var lastHapticThreshold: Int = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isRegular: Bool { sizeClass == .regular }

    /// One-tap presets learned from the user's recent logging habits.
    private var quickLogPresets: [QuickLogPresets.Preset] {
        QuickLogPresets.presets(
            from: store.entries,
            allowAllFluids: subscriptionManager.hasAccess(to: .fluidTypes)
        )
    }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 420 && dynamicTypeSize <= .large {
                compactColumns
            } else {
                Form {
                    Section("Amount") {
                        amountReadout(compact: false)
                        amountSlider
                        ViewThatFits(in: .horizontal) {
                            quickLogButtons(horizontal: true)
                            quickLogButtons(horizontal: false)
                        }
                        Text("Quick amounts log immediately.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("Beverage") {
                        beverageControls(compact: false)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveButton
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.bar)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: IntakeFooterHeightKey.self, value: geometry.size.height)
                    }
                }
        }
        .onPreferenceChange(IntakeContentHeightKey.self) { compactContentHeight = $0 }
        .onPreferenceChange(IntakeFooterHeightKey.self) { footerHeight = $0 }
        // Measure the natural content, never the sheet viewport. A single fitted
        // detent cannot be expanded into empty space. Native presentation caps
        // this height on short displays; the content remains scrollable.
        .presentationDetents(compactContentHeight.map {
            [.height(ceil($0 + footerHeight + 96))]
        } ?? [.medium, .large])
        .navigationTitle("Log Intake")
        .scrollContentBackground(.hidden)
        .background {
            GeometryReader { geometry in
                AppWaterBackground()
                    .modifier(RippleEffect(
                        at: CGPoint(x: geometry.size.width / 2, y: 200),
                        trigger: rippleTrigger
                    ))
            }
            .ignoresSafeArea()
        }
        .disabled(showSavedBanner)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let savedIntake {
                SavedBanner(
                    amount: Int(store.profile.unitSystem.amount(fromML: savedIntake.volumeML)),
                    unit: store.profile.unitSystem.volumeUnit,
                    fluidType: savedIntake.fluidType
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.15) : Theme.quickSpring, value: showSavedBanner)
        .task(id: savedIntake?.id) {
            guard savedIntake != nil else { return }
            do { try await Task.sleep(for: .seconds(0.9)) } catch { return }
            dismiss()
        }
        .onAppear {
            if !subscriptionManager.hasAccess(to: .fluidTypes) {
                selectedFluidType = .water
            }
            amount = store.profile.unitSystem.amount(fromML: selectedFluidType.defaultServingML)
            amount = min(max(amount, amountRange.lowerBound), amountRange.upperBound)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !reduceMotion { rippleTrigger += 1 }
            }
        }
    }

    private var compactColumns: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Amount")
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 8)
                            amountReadout(compact: true)
                        }
                        amountSlider
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Beverage")
                            .font(.subheadline.weight(.semibold))
                        beverageControls(compact: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
                }
                HStack(spacing: 12) {
                    Text("Quick log")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    quickLogButtons(horizontal: true, compact: true)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: IntakeContentHeightKey.self, value: geometry.size.height)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func amountReadout(compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(Int(amount))")
                .contentTransition(.numericText())
                .font(.system(size: compact ? 32 : 44, weight: .bold))
                .scaleEffect(amountLabelScale)
                .animation(reduceMotion ? .none : Theme.quickSpring, value: amountLabelScale)
            Text(store.profile.unitSystem.volumeUnit)
                .font(compact ? .caption : .title3)
                .foregroundStyle(.secondary)
        }
    }

    private var amountSlider: some View {
        Slider(value: $amount, in: amountRange, step: amountStep)
            .accessibilityLabel("Intake amount")
            .tint(selectedFluidType.color)
            .onChange(of: amount) { _, newValue in
                selectedPreset = nil
                // Scale up the label while dragging.
                if !reduceMotion {
                    amountLabelScale = 1.06
                    withAnimation(Theme.quickSpring) {
                        amountLabelScale = 1.0
                    }
                }
                // Haptic at each 100 ml threshold — rate-limited so
                // we only fire once per crossing, not on every tick.
                let threshold = Int(newValue / 100)
                if threshold != lastHapticThreshold {
                    lastHapticThreshold = threshold
                    Haptics.selection()
                }
            }
    }

    @ViewBuilder
    private func beverageControls(compact: Bool) -> some View {
        if subscriptionManager.hasAccess(to: .fluidTypes) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: compact ? 8 : (isRegular ? 12 : 8)) {
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
                                    .font(compact ? .title3 : (isRegular ? .title2 : .title3))
                                    .foregroundStyle(selectedFluidType == type ? .white : type.color)
                                    .frame(width: compact ? 36 : (isRegular ? 48 : 40), height: compact ? 36 : (isRegular ? 48 : 40))
                                    .background(
                                        Circle()
                                            .fill(selectedFluidType == type ? type.color : type.color.opacity(0.12))
                                    )
                                Text(type.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(selectedFluidType == type ? .primary : .secondary)
                                    .lineLimit(1)
                                    .frame(width: compact ? 56 : (isRegular ? 72 : 60))
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
                HStack(spacing: compact ? 8 : 12) {
                    Image(systemName: FluidType.water.iconName)
                        .foregroundStyle(Theme.lagoon)
                        .frame(width: compact ? 32 : 40, height: compact ? 32 : 40)
                        .background(
                            Circle()
                                .fill(Theme.lagoon.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Water")
                            .font(.subheadline.weight(.semibold))
                        if !compact {
                            Text("Premium unlocks coffee, tea, juice, smoothies, sports drinks, and more.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button("Unlock") {
                        Haptics.selection()
                        subscriptionManager.presentPaywall(for: .fluidTypes)
                    }
                    .font(.caption.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
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

    private func quickLogButtons(horizontal: Bool, compact: Bool = false) -> some View {
        let layout = horizontal ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        return layout {
            ForEach(quickLogPresets) { preset in
                Button {
                    logPreset(preset)
                } label: {
                    HStack(spacing: compact ? 4 : 6) {
                        Image(systemName: preset.fluidType.iconName)
                            .font(compact ? .caption2 : .caption)
                        Text("\(Int(store.profile.unitSystem.amount(fromML: preset.amountML))) \(store.profile.unitSystem.volumeUnit)")
                            .font((compact ? Font.caption2 : .subheadline).weight(.semibold))
                    }
                    .padding(.horizontal, compact ? 9 : 14)
                    .frame(minHeight: 44)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        Capsule(style: .continuous)
                            .fill(preset.fluidType.color.opacity(0.14))
                    )
                    .foregroundStyle(preset.fluidType.color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quick log \(Int(preset.amountML)) millilitres of \(preset.fluidType.displayName)")
                .accessibilityHint("Logs immediately")
            }
        }
    }

    private var saveButton: some View {
        Button {
            addIntake()
        } label: {
            Label("Save Intake", systemImage: selectedFluidType.iconName)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .font(isRegular ? .title3 : .body)
        }
        .buttonStyle(.borderedProminent)
        .tint(selectedFluidType.color)
    }

    private var amountRange: ClosedRange<Double> {
        store.profile.unitSystem == .metric ? 10...1200 : 1...40
    }

    private var amountStep: Double {
        store.profile.unitSystem == .metric ? 10 : 1
    }

    /// One-tap logging for a learned preset: bypasses the slider entirely.
    private func logPreset(_ preset: QuickLogPresets.Preset) {
        guard !showSavedBanner else { return }
        Haptics.splash()

        // Reflect the preset in the visible controls so the banner and any
        // follow-up slider adjustments start from what was just logged.
        selectedFluidType = preset.fluidType
        amount = min(
            max(store.profile.unitSystem.amount(fromML: preset.amountML), amountRange.lowerBound),
            amountRange.upperBound
        )

        let entry = store.addIntake(
            amount: preset.amountML,
            unitSystem: .metric,
            source: .manual,
            fluidType: preset.fluidType,
            note: nil
        )

        Task {
            guard subscriptionManager.hasAccess(to: .healthKitSync), store.effectiveProfile.prefersHealthKit else { return }
            await healthKit.saveWaterIntake(ml: entry.volumeML, date: entry.date, entryID: entry.id)
        }

        savedIntake = entry
        showSavedBanner = true
    }

    private func addIntake() {
        guard !showSavedBanner else { return }
        Haptics.splash()

        let entry = store.addIntake(amount: amount, source: .manual, fluidType: selectedFluidType, note: nil)

        Task {
            guard subscriptionManager.hasAccess(to: .healthKitSync), store.effectiveProfile.prefersHealthKit else { return }
            await healthKit.saveWaterIntake(ml: entry.volumeML, date: entry.date, entryID: entry.id)
        }

        savedIntake = entry
        showSavedBanner = true
    }
}

private struct IntakeContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat? { nil }
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

private struct IntakeFooterHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 72 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
