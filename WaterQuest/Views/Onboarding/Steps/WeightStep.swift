import SwiftUI

struct WeightStep: View {
    @Binding var state: OnboardingState
    let answers: [OnboardingAnswerChip]
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var weightDisplayKey = UUID()

    private var range: ClosedRange<Double> { state.weightSliderRange() }
    private var unit: String { state.unitSystem.bodyWeightUnit }

    private var dailyEstimateLabel: String {
        switch state.unitSystem {
        case .metric:
            let ml = state.weight * 33
            return String(format: "%.1f L", ml / 1000)
        case .imperial:
            let oz = state.weight * 0.5
            let cups = oz / 8.0
            return String(format: "%.1f cups", cups)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SipliTopBar(stepIndex: 2, total: OnboardingStep.displayedTotal, canGoBack: true, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AnswerChipStack(chips: answers)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    headline
                        .padding(.horizontal, 24)
                        .padding(.bottom, 6)

                    Text("We use this to set your daily baseline. Drag the dial.")
                        .font(.system(size: 15))
                        .foregroundStyle(OnboardingPalette.ink3)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    readout
                        .padding(.bottom, 20)

                    unitToggle
                        .padding(.bottom, 18)

                    rulerSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }

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
        (Text("You weigh\n").foregroundStyle(OnboardingPalette.ink)
            + Text("about how much?").italic().foregroundStyle(OnboardingPalette.water))
            .font(.editorialSerif(40))
            .lineSpacing(-2)
    }

    private var readout: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(Int(state.weight))")
                    .font(.editorialSerif(110, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
                    .id(weightDisplayKey)
                    .contentTransition(.numericText())
                Text(unit.uppercased())
                    .font(.sipliMono(18, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink3)
                    .padding(.bottom, 14)
            }
            (Text("That's about ").foregroundStyle(OnboardingPalette.ink3)
                + Text(dailyEstimateLabel).foregroundStyle(OnboardingPalette.water).fontWeight(.semibold)
                + Text(" a day").foregroundStyle(OnboardingPalette.ink3))
                .font(.system(size: 14))
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: state.weight)
    }

    private var unitToggle: some View {
        HStack(spacing: 0) {
            ForEach([UnitSystem.metric, UnitSystem.imperial], id: \.self) { unit in
                Button(action: { switchUnit(to: unit) }) {
                    Text(unit == .metric ? "kg" : "lb")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(state.unitSystem == unit ? OnboardingPalette.ink : OnboardingPalette.ink3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            ZStack {
                Capsule(style: .continuous)
                    .fill(OnboardingPalette.ink.opacity(0.07))
                GeometryReader { proxy in
                    Capsule(style: .continuous)
                        .fill(Color.white)
                        .frame(width: proxy.size.width / 2, height: proxy.size.height)
                        .offset(x: state.unitSystem == .metric ? 0 : proxy.size.width / 2)
                        .shadow(color: OnboardingPalette.ink.opacity(0.10), radius: 4, x: 0, y: 2)
                        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: state.unitSystem)
                }
            }
        )
        .frame(width: 140, height: 38)
        .frame(maxWidth: .infinity)
    }

    private func switchUnit(to unit: UnitSystem) {
        guard unit != state.unitSystem else { return }
        let oldKg = state.unitSystem.kg(from: state.weight)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            state.unitSystem = unit
            // Convert weight to new unit's natural value, snapped to default if out of range.
            let converted = unit.amountFromKG(oldKg)
            let r = unit == .metric ? 35.0...150.0 : 77.0...330.0
            let snapStep = unit == .metric ? 1.0 : 1.0
            let snapped = (converted / snapStep).rounded() * snapStep
            state.weight = min(max(snapped, r.lowerBound), r.upperBound)
        }
        Haptics.selection()
    }

    private var rulerSection: some View {
        let pct = (state.weight - range.lowerBound) / (range.upperBound - range.lowerBound)
        let tickCount = 41
        return VStack(spacing: 6) {
            GeometryReader { proxy in
                let w = proxy.size.width
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(0..<tickCount, id: \.self) { i in
                            let tickPct = Double(i) / Double(tickCount - 1)
                            let isMajor = i % 5 == 0
                            let dist = abs(tickPct - pct)
                            let close = dist < 0.08
                            Capsule()
                                .fill(OnboardingPalette.ink.opacity(close ? 1 : 0.4))
                                .frame(width: 2, height: tickHeight(isMajor: isMajor, close: close))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .animation(.easeOut(duration: 0.18), value: pct)
                        }
                    }
                    .frame(height: 56, alignment: .bottom)

                    cursorView
                        .offset(x: pct * w - 1, y: 0)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateFrom(x: value.location.x, in: w)
                        }
                        .onEnded { _ in Haptics.selection() }
                )
            }
            .frame(height: 56)

            HStack {
                Text("\(Int(range.lowerBound))")
                Spacer()
                Text("\(Int((range.lowerBound + range.upperBound) / 2))")
                Spacer()
                Text("\(Int(range.upperBound))")
            }
            .font(.sipliMono(11, weight: .medium))
            .foregroundStyle(OnboardingPalette.ink3)
        }
    }

    private var cursorView: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(OnboardingPalette.water)
                .frame(width: 12, height: 8)
                .offset(y: -4)
            Capsule()
                .fill(OnboardingPalette.water)
                .frame(width: 3, height: 56)
        }
    }

    private func tickHeight(isMajor: Bool, close: Bool) -> CGFloat {
        if isMajor { return close ? 38 : 28 }
        return close ? 22 : 14
    }

    private func updateFrom(x: CGFloat, in width: CGFloat) {
        guard width > 0 else { return }
        let pct = max(0, min(1, x / width))
        let value = Double(range.lowerBound) + pct * (range.upperBound - range.lowerBound)
        let rounded = (value).rounded()
        if Int(rounded) != Int(state.weight) {
            state.weight = rounded
            weightDisplayKey = UUID()
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
