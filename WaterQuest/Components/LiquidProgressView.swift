import SwiftUI

// MARK: - Main View
struct LiquidProgressView: View {
    let progress: Double
    let compositions: [FluidComposition]
    let isRegular: Bool
    let bottleWidth: CGFloat?
    let bottleHeight: CGFloat?

    @StateObject private var motionManager = MotionManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animate a constant wave
    @State private var phase: CGFloat = 0
    private let waveTimer = Timer.publish(every: 1 / 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let width = bottleWidth ?? (isRegular ? 280 : 220)
        let height = bottleHeight ?? (isRegular ? 380 : 300)
        let clampedProgress = max(0, progress)
        let visibleProgress = min(clampedProgress, 1.0) // Cap visual fill at 100%
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
            GeometryReader { geo in
                let h = geo.size.height
                let bodyTop = h * 0.32
                let bodyBottom = h * 0.88
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

                    BubbleParticles(
                        phase: phase,
                        fillHeight: fillHeight,
                        liquidTop: liquidTop,
                        reduceMotion: reduceMotion
                    )
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: clampedProgress)
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: layers)
            }
            .mask(
                Image("bottle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
            )

            Image("bottle")
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)

            VStack(spacing: 0) {
                Text(Formatters.percentString(clampedProgress))
                    .font(.system(isRegular ? .largeTitle : .title, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .contentTransition(.numericText())

                if clampedProgress >= 1.0 {
                    Image(systemName: "star.fill")
                        .font(isRegular ? .title3 : .subheadline)
                        .foregroundStyle(Theme.sun)
                        .padding(.top, 4)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .transition(.scale)
                }
            }
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hydration progress")
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

// MARK: - Structural Shapes
struct BottleFullShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addPath(BottleBodyShape().path(in: rect))
        path.addPath(CapBodyShape().path(in: rect))
        path.addPath(CapStemShape().path(in: rect))
        path.addPath(CapTopShape().path(in: rect))
        path.addPath(CapLoopShape().path(in: rect))
        return path
    }
}

struct BottleBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width * 0.45 // Bottle width
        let centerX = rect.midX
        let bodyLeft = centerX - w/2
        let bodyRight = centerX + w/2
        
        let neckW = w * 0.45
        let neckLeft = centerX - neckW/2
        let neckRight = centerX + neckW/2

        let topY = rect.height * 0.32 // Neck start
        let neckH = rect.height * 0.06
        let shoulderY = topY + neckH
        let bottomY = rect.height * 0.88 // Bottle bottom

        let outerRadius: CGFloat = w * 0.18
        let innerRadius: CGFloat = w * 0.05

        // Core anchor points
        let ptNeckTopLeft = CGPoint(x: neckLeft, y: topY)
        let ptNeckTopRight = CGPoint(x: neckRight, y: topY)
        let ptNeckBottomRight = CGPoint(x: neckRight, y: shoulderY)
        let ptShoulderRight = CGPoint(x: bodyRight, y: shoulderY)
        let ptBodyBottomRight = CGPoint(x: bodyRight, y: bottomY)
        let ptBodyBottomLeft = CGPoint(x: bodyLeft, y: bottomY)
        let ptShoulderLeft = CGPoint(x: bodyLeft, y: shoulderY)
        let ptNeckBottomLeft = CGPoint(x: neckLeft, y: shoulderY)

        path.move(to: ptNeckTopLeft)
        path.addLine(to: ptNeckTopRight)

        // Inner corner at neck/shoulder right
        path.addArc(tangent1End: ptNeckBottomRight, tangent2End: ptShoulderRight, radius: innerRadius)
        // Outer corner at shoulder right
        path.addArc(tangent1End: ptShoulderRight, tangent2End: ptBodyBottomRight, radius: outerRadius)
        // Outer corner at bottom right
        path.addArc(tangent1End: ptBodyBottomRight, tangent2End: ptBodyBottomLeft, radius: outerRadius)
        // Outer corner at bottom left
        path.addArc(tangent1End: ptBodyBottomLeft, tangent2End: ptShoulderLeft, radius: outerRadius)
        // Outer corner at shoulder left
        path.addArc(tangent1End: ptShoulderLeft, tangent2End: ptNeckBottomLeft, radius: outerRadius)
        // Inner corner at neck/shoulder left
        path.addArc(tangent1End: ptNeckBottomLeft, tangent2End: ptNeckTopLeft, radius: innerRadius)

        path.closeSubpath()
        return path
    }
}

struct CapBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width * 0.45
        let neckW = w * 0.45
        let capW = neckW * 1.35
        let capH = rect.height * 0.08
        let topY = rect.height * 0.32
        let capY = topY - capH

        return Path(roundedRect: CGRect(x: rect.midX - capW/2, y: capY, width: capW, height: capH),
                    cornerSize: CGSize(width: capH * 0.2, height: capH * 0.2))
    }
}

struct CapStemShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width * 0.45
        let neckW = w * 0.45
        let capW = neckW * 1.35
        let capH = rect.height * 0.08
        let topY = rect.height * 0.32
        let capY = topY - capH

        let stemW = capW * 0.35
        let stemH = rect.height * 0.035
        let stemY = capY - stemH

        return Path(roundedRect: CGRect(x: rect.midX - stemW/2, y: stemY, width: stemW, height: stemH),
                    cornerSize: CGSize(width: stemW * 0.15, height: stemW * 0.15))
    }
}

struct CapTopShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width * 0.45
        let neckW = w * 0.45
        let capW = neckW * 1.35
        let capH = rect.height * 0.08
        let topY = rect.height * 0.32
        let capY = topY - capH
        let stemW = capW * 0.35
        let stemH = rect.height * 0.035
        let stemY = capY - stemH

        let topW = stemW * 0.45
        let topH = rect.height * 0.012
        let topShapeY = stemY - topH

        return Path(roundedRect: CGRect(x: rect.midX - topW/2, y: topShapeY, width: topW, height: topH),
                    cornerSize: CGSize(width: topW * 0.2, height: topW * 0.2))
    }
}

struct CapLoopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width * 0.45
        let neckW = w * 0.45
        let capW = neckW * 1.35
        let capH = rect.height * 0.08
        let topY = rect.height * 0.32
        let capY = topY - capH
        let centerX = rect.midX

        let loopW = capW * 0.42
        let loopH = capH * 0.65
        let loopX = centerX + capW/2 - loopW * 0.25 // Tuck inside the cap
        let loopY = capY + (capH - loopH)/2

        let outerRect = CGRect(x: loopX, y: loopY, width: loopW, height: loopH)
        let thickness = loopH * 0.38
        let innerRect = outerRect.insetBy(dx: thickness, dy: thickness)

        // Draw outer loop bounds
        path.addRoundedRect(in: outerRect, cornerSize: CGSize(width: loopH * 0.5, height: loopH * 0.5))
        // Draw inner loop bounds (reverse winding creates the hole for eoFill)
        path.addRoundedRect(in: innerRect, cornerSize: CGSize(width: innerRect.height * 0.5, height: innerRect.height * 0.5))

        return path
    }
}

// MARK: - Fluid Dynamics
struct Wave: Shape {
    var phase: CGFloat
    var strength: CGFloat
    var frequency: CGFloat
    var tilt: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(phase, AnimatablePair(strength, tilt)) }
        set {
            phase = newValue.first
            strength = newValue.second.first
            tilt = newValue.second.second
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
            let tiltOffset = (relativeX - 0.5) * tilt * (height * 0.35)
            let y = sin(relativeX * .pi * 2 * frequency + phase) * strength + tiltOffset
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

private struct BubbleParticles: View {
    let phase: CGFloat
    let fillHeight: CGFloat
    let liquidTop: CGFloat
    let reduceMotion: Bool

    private let particleCount = 12

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ForEach(0..<particleCount, id: \.self) { index in
                let seed = particleSeed(index)
                let x = width * (0.2 + 0.6 * seed)
                let size = 2.0 + seed * 4.0
                let activeFill = max(fillHeight - 10, 0)
                let riseProgress = reduceMotion ? seed : wrapped((Double(phase) * (0.08 + seed * 0.1)) + seed)
                let y = (height - CGFloat(riseProgress) * activeFill) - 6
                let alpha = reduceMotion ? 0.1 : (0.15 + seed * 0.2) * max(0.1, (y - liquidTop) / max(1, fillHeight))

                Circle()
                    .fill(.white.opacity(alpha))
                    .frame(width: size, height: size)
                    .position(x: x, y: y)
            }
        }
        .allowsHitTesting(false)
    }

    private func particleSeed(_ index: Int) -> CGFloat {
        let raw = sin(Double(index) * 12.9898) * 43758.5453
        return CGFloat(raw - floor(raw))
    }

    private func wrapped(_ value: Double) -> Double {
        value - floor(value)
    }
}

struct FluidLayer: Identifiable, Equatable {
    var id: String { type.rawValue }
    let type: FluidType
    let proportionTop: Double
}

// MARK: - Preview
struct LiquidProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(white: 0.95).ignoresSafeArea()
            
            LiquidProgressView(
                progress: 0.9,
                compositions: [
                    FluidComposition(type: .water, proportion: 0.35),
                    FluidComposition(type: .sportsDrink, proportion: 0.20),
                    FluidComposition(type: .energyDrink, proportion: 0.20),
                    FluidComposition(type: .smoothie, proportion: 0.25)
                ],
                isRegular: true,
                bottleWidth: nil as CGFloat?,
                bottleHeight: nil as CGFloat?
            )
        }
    }
}
