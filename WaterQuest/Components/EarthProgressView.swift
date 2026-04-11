import SwiftUI

/// Earth Week variant of `LiquidProgressView`. Renders the same animated
/// fluid waves but clipped to a circle (the earth's shape) and overlays the
/// transparent earth image on top. The bottle silhouette is intentionally
/// hidden.
struct EarthProgressView: View {
    let progress: Double
    let compositions: [FluidComposition]
    let isRegular: Bool
    let bottleWidth: CGFloat?
    let bottleHeight: CGFloat?

    @StateObject private var motionManager = MotionManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: CGFloat = 0
    private let waveTimer = Timer.publish(every: 1 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let width = bottleWidth ?? (isRegular ? 280 : 220)
        let height = bottleHeight ?? (isRegular ? 380 : 300)
        // Earth is square; fit a circle inside the smaller of the two dims so
        // the waves stay nicely centred behind the globe.
        let diameter = min(width, height) * 0.95
        let clampedProgress = max(0, progress)
        let visibleProgress = min(clampedProgress, 1.0)
        let sloshTilt = reduceMotion ? 0 : max(-0.35, min(0.35, motionManager.roll))

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

        let waveStrengthBack: CGFloat = reduceMotion ? 2 : 8
        let waveStrengthFront: CGFloat = reduceMotion ? 3 : 12

        ZStack {
            // Water waves clipped to the earth's circle
            GeometryReader { geo in
                let h = geo.size.height
                let bodyTop: CGFloat = 0
                let bodyBottom = h
                let reservoirHeight = bodyBottom - bodyTop
                let fillHeight = reservoirHeight * CGFloat(visibleProgress)
                let liquidTop = bodyBottom - fillHeight

                ZStack {
                    ZStack {
                        ForEach(layers) { layer in
                            let layerFillHeight = fillHeight * CGFloat(layer.proportionTop)
                            let yOffset = bodyBottom - layerFillHeight

                            Wave(phase: phase, strength: waveStrengthBack, frequency: 1.5, tilt: sloshTilt)
                                .fill(layer.type.color)
                                .saturation(1.75)
                                .brightness(-0.10)
                                .offset(y: yOffset)
                        }
                    }
                    .compositingGroup()
                    .opacity(0.72)

                    ZStack {
                        ForEach(layers) { layer in
                            let layerFillHeight = fillHeight * CGFloat(layer.proportionTop)
                            let yOffset = bodyBottom - layerFillHeight

                            Wave(phase: phase + .pi, strength: waveStrengthFront, frequency: 1.1, tilt: sloshTilt * 1.2)
                                .fill(layer.type.color)
                                .saturation(1.95)
                                .brightness(-0.06)
                                .offset(y: yOffset)

                            Wave(phase: phase + .pi, strength: waveStrengthFront, frequency: 1.1, tilt: sloshTilt * 1.2)
                                .stroke(Color.white.opacity(0.55), lineWidth: 3.5)
                                .offset(y: yOffset)
                        }
                    }
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: clampedProgress)
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: layers)
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())

            // The transparent earth on top
            Image("earth")
                .resizable()
                .scaledToFit()
                .frame(width: diameter, height: diameter)
                .shadow(color: Color.green.opacity(0.35), radius: 24, x: 0, y: 8)

            // Percentage label, mirrors LiquidProgressView's badge
            VStack(spacing: 0) {
                Text(Formatters.percentString(clampedProgress))
                    .font(.system(isRegular ? .largeTitle : .title, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                    .contentTransition(.numericText())

                if clampedProgress >= 1.0 {
                    Image(systemName: "star.fill")
                        .font(isRegular ? .title3 : .subheadline)
                        .foregroundStyle(Theme.sun)
                        .padding(.top, 4)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                        .transition(.scale)
                }
            }
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hydration progress for Earth Week")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent of daily goal")
        .onReceive(waveTimer) { _ in
            guard !reduceMotion else { return }
            phase += 0.05
            if phase > (.pi * 200) {
                phase = 0
            }
        }
    }
}
