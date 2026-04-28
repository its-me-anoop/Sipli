import SwiftUI

struct TargetStep: View {
    @Binding var state: OnboardingState
    let answers: [OnboardingAnswerChip]
    let onContinue: () -> Void
    let onBack: () -> Void

    private var displayedML: Double { state.displayedTargetML }

    private var displayedFillFraction: Double {
        let v = displayedML
        return max(0.05, min(0.95, v / 4000.0))
    }

    private var displayedTopLine: String {
        switch state.unitSystem {
        case .metric: return String(format: "%.1f", displayedML / 1000.0)
        case .imperial: return String(format: "%.0f", state.unitSystem.amount(fromML: displayedML))
        }
    }
    private var displayedUnit: String {
        state.unitSystem == .metric ? "L" : "oz"
    }

    var body: some View {
        VStack(spacing: 0) {
            SipliTopBar(stepIndex: 4, total: OnboardingStep.displayedTotal, canGoBack: true, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AnswerChipStack(chips: answers)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    headline
                        .padding(.horizontal, 24)
                        .padding(.bottom, 14)

                    targetStage
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    if state.customGoalEnabled {
                        targetSlider
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    customGoalToggle
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                    weatherToggle
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .padding(.bottom, 16)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: state.customGoalEnabled)

            VStack {
                SipliCTA(title: "Continue", action: onContinue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .padding(.top, 12)
        }
        .background(OnboardingPalette.paper)
    }

    private var headline: some View {
        (Text("Pour the perfect\n").foregroundStyle(OnboardingPalette.ink)
            + Text("daily amount.").italic().foregroundStyle(OnboardingPalette.water))
            .font(.editorialSerif(40))
            .lineSpacing(-2)
    }

    private var targetStage: some View {
        HStack(alignment: .center, spacing: 12) {
            SipliBottle(fill: displayedFillFraction, size: 110)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(displayedTopLine)
                        .font(.editorialSerif(64, weight: .regular))
                        .foregroundStyle(OnboardingPalette.ink)
                        .contentTransition(.numericText())
                    Text(displayedUnit)
                        .font(.sipliMono(18, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.ink3)
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.55), value: displayedML)

                Text(state.customGoalEnabled ? "Custom goal" : "Suggested for you")
                    .font(.system(size: 13))
                    .foregroundStyle(OnboardingPalette.ink3)

                if !state.customGoalEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text("AI calibrated")
                    }
                    .font(.sipliMono(11, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.sun)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(OnboardingPalette.ink))
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.910, green: 0.957, blue: 0.984), Color(red: 1.0, green: 0.956, blue: 0.878)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var targetSlider: some View {
        let r = state.customGoalRange()
        let pct = (state.customGoalValue - r.lowerBound) / (r.upperBound - r.lowerBound)
        let labels: (String, String) = state.unitSystem == .metric ? ("1.0L", "4.0L") : ("33 oz", "135 oz")
        return VStack(spacing: 6) {
            GeometryReader { proxy in
                let w = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(OnboardingPalette.ink.opacity(0.08))
                        .frame(height: 14)

                    Capsule()
                        .fill(OnboardingPalette.water)
                        .frame(width: max(0, pct * w), height: 14)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(OnboardingPalette.water, lineWidth: 3))
                        .shadow(color: OnboardingPalette.water.opacity(0.3), radius: 4, x: 0, y: 4)
                        .offset(x: max(0, pct * w - 14))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in updateFrom(x: value.location.x, in: w, range: r) }
                        .onEnded { _ in Haptics.selection() }
                )
            }
            .frame(height: 28)

            HStack {
                Text(labels.0)
                Spacer()
                Text(labels.1)
            }
            .font(.sipliMono(11, weight: .medium))
            .foregroundStyle(OnboardingPalette.ink3)
            .padding(.top, 4)
        }
        .padding(.top, 6)
    }

    private func updateFrom(x: CGFloat, in width: CGFloat, range: ClosedRange<Double>) {
        guard width > 0 else { return }
        let pct = max(0, min(1, x / width))
        let value = Double(range.lowerBound) + pct * (range.upperBound - range.lowerBound)
        // Snap by 50ml in metric, 2oz in imperial
        let step = state.unitSystem == .metric ? 50.0 : 2.0
        let snapped = (value / step).rounded() * step
        let clamped = min(max(snapped, range.lowerBound), range.upperBound)
        if abs(clamped - state.customGoalValue) >= step / 2 {
            state.customGoalValue = clamped
        }
    }

    private var customGoalToggle: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Set my own goal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                Text("Override the suggestion")
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.ink3)
            }
            Spacer()
            SipliToggle(isOn: $state.customGoalEnabled, tint: OnboardingPalette.water)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingPalette.ink.opacity(0.06), lineWidth: 1)
        )
    }

    private var weatherToggle: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.886, blue: 0.714))
                    .frame(width: 36, height: 36)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 1.0, green: 0.541, blue: 0.122))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Adjust for weather")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                Text("Drink more on hot days")
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.ink3)
            }
            Spacer()
            SipliToggle(isOn: $state.prefersWeatherGoal, tint: OnboardingPalette.water)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingPalette.ink.opacity(0.06), lineWidth: 1)
        )
    }
}
