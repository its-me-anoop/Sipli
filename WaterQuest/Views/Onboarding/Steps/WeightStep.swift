import SwiftUI

struct WeightStep: View {
    @Binding var state: OnboardingState
    let answers: [OnboardingAnswerChip]
    let onContinue: () -> Void

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
            // Header strip: thin progress meter. The compact vessel
            // (coordinator-owned) floats at the trailing edge of this strip.
            HStack {
                Capsule()
                    .fill(OnboardingPalette.ink.opacity(0.12))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(OnboardingPalette.water)
                                .frame(width: geo.size.width * OnboardingStep.weight.fillFraction)
                        }
                    }
                Spacer().frame(width: 96) // clearance for the compact vessel
            }
            .frame(height: 44)
            .padding(.horizontal, 24)
            .padding(.top, 50)
            .padding(.bottom, 4)

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
                        .padding(.bottom, 22)

                    HStack(alignment: .center, spacing: 18) {
                        readout
                        verticalRuler
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)

                    unitToggle
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
    }

    private var headline: some View {
        (Text("You weigh\n").foregroundStyle(OnboardingPalette.ink)
            + Text("about how much?").italic().foregroundStyle(OnboardingPalette.water))
            .font(.editorialSerif(40, relativeTo: .largeTitle))
            .lineSpacing(-2)
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Int(state.weight))")
                    .font(.editorialSerif(96, weight: .regular, relativeTo: .largeTitle))
                    .foregroundStyle(OnboardingPalette.ink)
                    .id(weightDisplayKey)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                Text(unit.uppercased())
                    .font(.sipliMono(16, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(OnboardingPalette.ink3)
                    .padding(.bottom, 12)
            }
            (Text("That's about ").foregroundStyle(OnboardingPalette.ink3)
                + Text(dailyEstimateLabel).foregroundStyle(OnboardingPalette.water).fontWeight(.semibold)
                + Text("\na day").foregroundStyle(OnboardingPalette.ink3))
                .font(.system(size: 14))
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            let converted = unit.amountFromKG(oldKg)
            let r = state.weightSliderRange()
            let snapped = converted.rounded()
            state.weight = min(max(snapped, r.lowerBound), r.upperBound)
        }
        Haptics.selection()
    }

    private var verticalRuler: some View {
        let pct = (state.weight - range.lowerBound) / (range.upperBound - range.lowerBound)
        // 51 ticks across the 0–500 kg / 0–1100 lb range: 10 kg per tick
        // (major every 50 kg) for metric; ~22 lb per tick (major every 110 lb)
        // for imperial. Drag is continuous, so the underlying value is finer
        // than the ticks suggest.
        let tickCount = 51
        return HStack(spacing: 14) {
            // Ticks column — drag up to increase, like a wall-mounted measuring tape.
            GeometryReader { proxy in
                let h = proxy.size.height
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(0..<tickCount, id: \.self) { i in
                            // i=0 at the top maps to the highest weight.
                            let topToBottom = Double(i) / Double(tickCount - 1)
                            let valuePct = 1.0 - topToBottom
                            let isMajor = i % 5 == 0
                            let dist = abs(valuePct - pct)
                            let close = dist < 0.08
                            HStack(spacing: 0) {
                                Capsule()
                                    .fill(OnboardingPalette.ink.opacity(close ? 1 : 0.35))
                                    .frame(width: tickWidth(isMajor: isMajor, close: close), height: 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .animation(.easeOut(duration: 0.18), value: pct)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 56, alignment: .leading)

                    // Cursor: a horizontal water-coloured line + arrowhead pointing at the ticks.
                    HStack(spacing: 4) {
                        Triangle()
                            .fill(OnboardingPalette.water)
                            .frame(width: 8, height: 12)
                            .rotationEffect(.degrees(90))
                        Capsule()
                            .fill(OnboardingPalette.water)
                            .frame(width: 56, height: 3)
                    }
                    .offset(x: -4, y: (1.0 - pct) * h - 1.5)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateFrom(y: value.location.y, in: h)
                        }
                        .onEnded { _ in Haptics.selection() }
                )
            }
            .frame(width: 80, height: 240)

            // Numeric scale on the trailing side: max top, min bottom.
            VStack(alignment: .trailing) {
                Text("\(Int(range.upperBound))")
                Spacer()
                Text("\(Int((range.lowerBound + range.upperBound) / 2))")
                Spacer()
                Text("\(Int(range.lowerBound))")
            }
            .font(.sipliMono(11, weight: .medium, relativeTo: .caption))
            .foregroundStyle(OnboardingPalette.ink3)
            .frame(height: 240)
        }
    }

    private func tickWidth(isMajor: Bool, close: Bool) -> CGFloat {
        if isMajor { return close ? 56 : 42 }
        return close ? 30 : 18
    }

    private func updateFrom(y: CGFloat, in height: CGFloat) {
        guard height > 0 else { return }
        let pct = max(0, min(1, 1.0 - (y / height)))
        let value = Double(range.lowerBound) + pct * (range.upperBound - range.lowerBound)
        let rounded = value.rounded()
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
