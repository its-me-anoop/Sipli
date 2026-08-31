import SwiftUI

struct WaveShape: Shape {
    var phase: CGFloat
    var strength: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, strength) }
        set {
            phase = newValue.first
            strength = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath()
        let midHeight = rect.height * 0.5
        let waveLength = rect.width / 1.3

        path.move(to: CGPoint(x: 0, y: midHeight))
        for x in stride(from: 0, through: rect.width + 1, by: 6) {
            let relative = x / waveLength
            let y = midHeight + sin(relative + phase) * strength
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.close()
        return Path(path.cgPath)
    }
}

struct WaveView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        WaveShape(phase: phase, strength: reduceMotion ? 0 : 12)
            .fill(
                LinearGradient(
                    colors: [Theme.lagoon.opacity(0.52), Theme.mint.opacity(0.42)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 3.6).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
    }
}
