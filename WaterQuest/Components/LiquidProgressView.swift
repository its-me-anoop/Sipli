import SwiftUI

struct LiquidProgressView: View {
    let progress: Double
    let compositions: [FluidComposition]
    let isRegular: Bool
    
    @StateObject private var motionManager = MotionManager()
    
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
        
        // A physical container shape
        ZStack {
            // Background empty state
            ContainerShape()
                .fill(Theme.glassLight)
                .overlay(
                    ContainerShape()
                        .stroke(Theme.glassBorder, lineWidth: 2)
                )
                .shadow(color: Theme.shadowColor, radius: 8, x: 0, y: 4)

            
            // The Liquid Fill
            GeometryReader { geo in
                let height = geo.size.height
                let width = geo.size.width
                
                let fillHeight = height * CGFloat(clampedProgress)
                
                ZStack {
                    // BACK LIQUID COLUMN
                    ZStack {
                        ForEach(layers) { layer in
                            let layerFillHeight = fillHeight * CGFloat(layer.proportionTop)
                            
                            Wave(phase: phase, strength: 8, frequency: 1.5)
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
                            
                            Wave(phase: phase + .pi, strength: 12, frequency: 1.2)
                                .fill(layer.type.color)
                                .offset(y: CGFloat(height - layerFillHeight))
                        }
                    }
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: clampedProgress)
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: layers)
                // Apply rotation based on device motion (sloshing)
                .rotationEffect(.radians(-motionManager.roll), anchor: .center)
            }
            .mask(ContainerShape())
            // Progress Text Overlay
            VStack(spacing: 0) {
                Text(Formatters.percentString(clampedProgress))
                    .font(.system(isRegular ? .largeTitle : .title, design: .rounded).weight(.heavy))
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
            .shadow(color: clampedProgress > 0.5 ? .black.opacity(0.3) : .clear, radius: 2)
        }
        .frame(width: size, height: size)
        .onAppear {
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
