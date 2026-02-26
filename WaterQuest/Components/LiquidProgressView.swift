import SwiftUI

struct LiquidProgressView: View {
    let progress: Double
    let compositions: [FluidComposition]
    let isRegular: Bool

    @StateObject private var motionManager = MotionManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animate a constant wave
    @State private var phase: CGFloat = 0

    var body: some View {
        let size: CGFloat = isRegular ? 240 : 180
        let clampedProgress = max(0, progress) // Allow over 100% naturally

        let layers: [FluidLayer] = {
            if compositions.isEmpty {
                return [FluidLayer(type: .water, proportionTop: 1.0)]
            }
            var result: [FluidLayer] = []
            var currentTop: Double = 0
            for comp in compositions {
                currentTop += comp.proportion
                result.append(FluidLayer(type: comp.type, proportionTop: currentTop))
            }
            return result.reversed()
        }()

        let waveStrengthBack: CGFloat = reduceMotion ? 0 : 8
        let waveStrengthFront: CGFloat = reduceMotion ? 0 : 12

        // A physical container shape
        ZStack {
            // Background empty state
            ContainerShape()
                .fill(Theme.card)
                .shadow(color: Theme.shadowColor, radius: 8, x: 0, y: 4)


            // The Liquid Fill
            GeometryReader { geo in
                let height = geo.size.height

                let fillHeight = height * CGFloat(clampedProgress)

                ZStack {
                    // BACK LIQUID COLUMN
                    ZStack {
                        ForEach(layers) { layer in
                            let layerFillHeight = fillHeight * CGFloat(layer.proportionTop)

                            Wave(phase: phase, strength: waveStrengthBack, frequency: 1.5)
                                .fill(layer.type.color)
                                .offset(y: CGFloat(height - layerFillHeight))
                        }
                    }
                    .compositingGroup()
                    .opacity(0.6)

                    // FRONT LIQUID COLUMN
                    ZStack {
                        ForEach(layers) { layer in
                            let layerFillHeight = fillHeight * CGFloat(layer.proportionTop)

                            Wave(phase: phase + .pi, strength: waveStrengthFront, frequency: 1.2)
                                .fill(layer.type.color)
                                .offset(y: CGFloat(height - layerFillHeight))
                        }
                    }
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: clampedProgress)
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: layers)
                // Apply rotation based on device motion (sloshing) — skip when reduce motion
                .rotationEffect(reduceMotion ? .zero : .radians(-motionManager.roll), anchor: .center)
            }
            .mask(ContainerShape())
            // Progress Text Overlay
            VStack(spacing: 0) {
                Text(Formatters.percentString(clampedProgress))
                    .font(.system(isRegular ? .largeTitle : .title, design: .rounded).weight(.heavy))
                    .foregroundStyle(clampedProgress > 0.5 ? .white : Theme.textPrimary)
                    .contentTransition(.numericText())

                if clampedProgress >= 1.0 {
                    Image(systemName: "star.fill")
                        .font(isRegular ? .title3 : .subheadline)
                        .foregroundStyle(Theme.sun)
                        .padding(.top, 4)
                        .transition(.scale)
                }
            }
            .shadow(color: clampedProgress > 0.5 ? .black.opacity(0.3) : .clear, radius: 2)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hydration progress")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent of daily goal")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

private struct FluidLayer: Identifiable, Equatable {
    var id: String { type.rawValue }
    let type: FluidType
    let proportionTop: Double
}

// A slightly bubbly shape for the container instead of a perfect circle
struct ContainerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.4)
        return Path(path.cgPath)
    }
}

struct Wave: Shape {
    var phase: CGFloat
    var strength: CGFloat
    var frequency: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, strength) }
        set {
            phase = newValue.first
            strength = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height))

        let step = 5.0
        for x in stride(from: 0, through: width, by: step) {
            let relativeX = x / width
            // Sine wave calculation
            let y = sin(relativeX * .pi * 2 * frequency + phase) * strength
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}
