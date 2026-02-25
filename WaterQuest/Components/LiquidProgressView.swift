import SwiftUI

struct LiquidProgressView: View {
    let progress: Double
    let compositions: [FluidComposition]
    let isRegular: Bool
    
    @StateObject private var motionManager = MotionManager()
    
    // Animate a constant wave
    @State private var phase: CGFloat = 0
    
    var body: some View {
        let height: CGFloat = isRegular ? 240 : 200
        let width: CGFloat = height * 0.52
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

        // A physical container shape
        ZStack {
            // Background empty state
            WaterBottleShape()
                .fill(Theme.glassLight)
                .overlay(
                    WaterBottleShape()
                        .stroke(Theme.glassBorder, lineWidth: 2)
                )
                .shadow(color: Theme.shadowColor, radius: 8, x: 0, y: 4)


            // The Liquid Fill
            GeometryReader { geo in
                let h = geo.size.height

                let fillHeight = h * CGFloat(clampedProgress)

                ZStack {
                    // BACK LIQUID COLUMN
                    ZStack {
                        ForEach(layers) { layer in
                            let layerFillHeight = fillHeight * CGFloat(layer.proportionTop)

                            Wave(phase: phase, strength: 6, frequency: 1.8)
                                .fill(layer.type.color)
                                .offset(y: CGFloat(h - layerFillHeight))
                        }
                    }
                    .compositingGroup()
                    .opacity(0.6)

                    // FRONT LIQUID COLUMN
                    ZStack {
                        ForEach(layers) { layer in
                            let layerFillHeight = fillHeight * CGFloat(layer.proportionTop)

                            Wave(phase: phase + .pi, strength: 10, frequency: 1.5)
                                .fill(layer.type.color)
                                .offset(y: CGFloat(h - layerFillHeight))
                        }
                    }

                    // BUBBLE PARTICLES within the liquid
                    BubbleParticlesView(progress: clampedProgress)
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: clampedProgress)
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: layers)
                // Apply rotation based on device motion (sloshing)
                .rotationEffect(.radians(-motionManager.roll), anchor: .center)
            }
            .mask(WaterBottleShape())
            // Progress Text Overlay — offset into the body area
            VStack(spacing: 0) {
                Text(Formatters.percentString(clampedProgress))
                    .font(.system(isRegular ? .largeTitle : .title2, design: .rounded).weight(.heavy))
                    .foregroundColor(clampedProgress > 0.5 ? .white : Theme.textPrimary)
                    .contentTransition(.numericText())

                if clampedProgress >= 1.0 {
                    Image(systemName: "star.fill")
                        .font(isRegular ? .title3 : .subheadline)
                        .foregroundColor(Theme.sun)
                        .padding(.top, 4)
                        .transition(.scale)
                }
            }
            .offset(y: height * 0.12)
            .shadow(color: clampedProgress > 0.5 ? .black.opacity(0.3) : .clear, radius: 2)
        }
        .frame(width: width, height: height)
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Bubble Particle System

private struct BubbleParticle {
    let xNormalized: Double
    let diameter: CGFloat
    let speed: Double
    let phaseOffset: Double
    let wobbleAmplitude: CGFloat
    let wobbleFrequency: Double
    let opacity: Double
}

private struct BubbleParticlesView: View {
    let progress: Double
    
    private let particles: [BubbleParticle]
    
    init(progress: Double) {
        self.progress = progress
        
        var result: [BubbleParticle] = []
        for i in 0..<18 {
            let seed = Double(i)
            result.append(BubbleParticle(
                xNormalized: Self.seededRandom(seed: seed * 13.7),
                diameter: CGFloat(2.5 + Self.seededRandom(seed: seed * 7.3) * 5.5),
                speed: 0.08 + Self.seededRandom(seed: seed * 11.1) * 0.14,
                phaseOffset: Self.seededRandom(seed: seed * 5.9),
                wobbleAmplitude: CGFloat(2 + Self.seededRandom(seed: seed * 3.1) * 5),
                wobbleFrequency: 1.2 + Self.seededRandom(seed: seed * 9.7) * 2.0,
                opacity: 0.25 + Self.seededRandom(seed: seed * 2.3) * 0.4
            ))
        }
        self.particles = result
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            Canvas { context, canvasSize in
                let fillHeight = canvasSize.height * CGFloat(max(0, progress))
                let fillTop = canvasSize.height - fillHeight
                
                guard fillHeight > 10 else { return }
                
                for particle in particles {
                    // Cycle position from bottom to top of the liquid area
                    let rawCycle = (time * particle.speed + particle.phaseOffset)
                    let cycle = rawCycle - rawCycle.rounded(.down) // 0...1
                    let y = fillTop + fillHeight * CGFloat(1.0 - cycle)
                    
                    // Horizontal position with sinusoidal wobble
                    let margin = particle.diameter + 4
                    let usableWidth = canvasSize.width - margin * 2
                    let baseX = margin + usableWidth * CGFloat(particle.xNormalized)
                    let wobble = particle.wobbleAmplitude * CGFloat(sin(time * particle.wobbleFrequency + particle.phaseOffset * .pi * 2))
                    let x = baseX + wobble
                    
                    // Fade in near bottom, fade out near top
                    let edgeFade = min(1.0, min(cycle * 5, (1.0 - cycle) * 5))
                    let alpha = edgeFade * particle.opacity
                    
                    let rect = CGRect(
                        x: x - particle.diameter / 2,
                        y: y - particle.diameter / 2,
                        width: particle.diameter,
                        height: particle.diameter
                    )
                    
                    // Draw a soft white bubble with slight highlight
                    context.opacity = alpha
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white)
                    )
                    
                    // Inner highlight for glassy bubble look
                    if particle.diameter > 4 {
                        let highlightSize = particle.diameter * 0.4
                        let highlightRect = CGRect(
                            x: x - highlightSize / 2 - particle.diameter * 0.15,
                            y: y - highlightSize / 2 - particle.diameter * 0.15,
                            width: highlightSize,
                            height: highlightSize
                        )
                        context.opacity = alpha * 0.6
                        context.fill(
                            Path(ellipseIn: highlightRect),
                            with: .color(.white)
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    /// Deterministic pseudo-random from a seed, returning 0..<1
    private static func seededRandom(seed: Double) -> Double {
        let x = sin(seed * 12.9898 + 78.233) * 43758.5453
        return x - x.rounded(.down)
    }
}

private struct FluidLayer: Identifiable, Equatable {
    var id: String { type.rawValue }
    let type: FluidType
    let proportionTop: Double
}

// Water bottle silhouette matching the app icon
struct WaterBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = w / 2

        // Proportions closely traced from the app icon water bottle
        // Body: tall rectangle with small rounded bottom corners
        let bodyHalfW = w * 0.48
        let bodyBottom = h
        let bodyTop = h * 0.26
        let bodyCorner = w * 0.07

        // Shoulder: quick inward curve from body to cap
        let shoulderMid = h * 0.22

        // Cap: wide dome (about 80% of body width)
        let capHalfW = w * 0.40
        let capTop = h * 0.10

        // Spout: small cylinder on top of cap
        let spoutHalfW = w * 0.09
        let spoutTop: CGFloat = 0
        let spoutBottom = h * 0.10
        let spoutCorner = spoutHalfW * 0.6

        // === Bottom edge (left to right) ===
        path.move(to: CGPoint(x: cx - bodyHalfW + bodyCorner, y: bodyBottom))
        path.addLine(to: CGPoint(x: cx + bodyHalfW - bodyCorner, y: bodyBottom))

        // Bottom-right corner
        path.addArc(
            tangent1End: CGPoint(x: cx + bodyHalfW, y: bodyBottom),
            tangent2End: CGPoint(x: cx + bodyHalfW, y: bodyBottom - bodyCorner),
            radius: bodyCorner
        )

        // === Right body wall (straight up) ===
        path.addLine(to: CGPoint(x: cx + bodyHalfW, y: bodyTop))

        // === Right shoulder (quick curve inward to cap) ===
        path.addCurve(
            to: CGPoint(x: cx + capHalfW, y: shoulderMid),
            control1: CGPoint(x: cx + bodyHalfW, y: bodyTop - h * 0.02),
            control2: CGPoint(x: cx + capHalfW, y: shoulderMid + h * 0.02)
        )

        // === Right cap dome (wide arc up to spout) ===
        path.addCurve(
            to: CGPoint(x: cx + spoutHalfW, y: spoutBottom),
            control1: CGPoint(x: cx + capHalfW, y: capTop),
            control2: CGPoint(x: cx + capHalfW * 0.55, y: spoutBottom)
        )

        // === Spout right side up ===
        path.addLine(to: CGPoint(x: cx + spoutHalfW, y: spoutTop + spoutCorner))

        // Spout top-right corner
        path.addArc(
            tangent1End: CGPoint(x: cx + spoutHalfW, y: spoutTop),
            tangent2End: CGPoint(x: cx, y: spoutTop),
            radius: spoutCorner
        )

        // Spout top edge
        path.addLine(to: CGPoint(x: cx - spoutHalfW + spoutCorner, y: spoutTop))

        // Spout top-left corner
        path.addArc(
            tangent1End: CGPoint(x: cx - spoutHalfW, y: spoutTop),
            tangent2End: CGPoint(x: cx - spoutHalfW, y: spoutBottom),
            radius: spoutCorner
        )

        // === Spout left side down ===
        path.addLine(to: CGPoint(x: cx - spoutHalfW, y: spoutBottom))

        // === Left cap dome (mirror of right) ===
        path.addCurve(
            to: CGPoint(x: cx - capHalfW, y: shoulderMid),
            control1: CGPoint(x: cx - capHalfW * 0.55, y: spoutBottom),
            control2: CGPoint(x: cx - capHalfW, y: capTop)
        )

        // === Left shoulder (quick curve outward to body) ===
        path.addCurve(
            to: CGPoint(x: cx - bodyHalfW, y: bodyTop),
            control1: CGPoint(x: cx - capHalfW, y: shoulderMid + h * 0.02),
            control2: CGPoint(x: cx - bodyHalfW, y: bodyTop - h * 0.02)
        )

        // === Left body wall (straight down) ===
        path.addLine(to: CGPoint(x: cx - bodyHalfW, y: bodyBottom - bodyCorner))

        // Bottom-left corner
        path.addArc(
            tangent1End: CGPoint(x: cx - bodyHalfW, y: bodyBottom),
            tangent2End: CGPoint(x: cx - bodyHalfW + bodyCorner, y: bodyBottom),
            radius: bodyCorner
        )

        path.closeSubpath()
        return path
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
