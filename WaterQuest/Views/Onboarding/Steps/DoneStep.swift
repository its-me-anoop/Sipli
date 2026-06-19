import SwiftUI

struct DoneStep: View {
    let state: OnboardingState
    /// Top inset for the text block so it clears the coordinator-owned vessel.
    /// The gradient and confetti stay full-bleed (they ignore this).
    var topInset: CGFloat = 0
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confettiSeed = UUID()

    private var firstName: String {
        let n = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "friend" : n
    }

    private var targetDisplay: String {
        let ml = state.displayedTargetML
        switch state.unitSystem {
        case .metric: return String(format: "%.1f L", ml / 1000.0)
        case .imperial: return "\(Int(state.unitSystem.amount(fromML: ml))) oz"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.863, green: 0.933, blue: 1.0), OnboardingPalette.paper],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if !reduceMotion {
                ConfettiLayer(seed: confettiSeed)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                (Text("You're set,\n").foregroundStyle(OnboardingPalette.ink)
                    + Text("\(firstName).").italic().foregroundStyle(OnboardingPalette.water))
                    .font(.editorialSerif(38, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text("Your daily target: \(Text(targetDisplay).fontWeight(.semibold).foregroundColor(OnboardingPalette.ink)). Let's start with a small sip.")
                    .font(.system(size: 15))
                    .foregroundStyle(OnboardingPalette.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 18)
                    .frame(maxWidth: 320)

                Spacer()

                SipliCTA(title: "Open Sipli", variant: .water, action: onFinish)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
            .padding(.top, topInset)
            .frame(maxWidth: .infinity)
        }
        .onAppear { Haptics.success() }
    }
}

private struct ConfettiLayer: View {
    let seed: UUID
    private struct Piece {
        let x: CGFloat
        let delay: Double
        let color: Color
        let width: CGFloat
        let height: CGFloat
    }
    private static let palette: [Color] = [
        OnboardingPalette.water,
        OnboardingPalette.sun,
        OnboardingPalette.coral,
        OnboardingPalette.mint,
        OnboardingPalette.lilac
    ]
    private let pieces: [Piece]

    init(seed: UUID) {
        self.seed = seed
        var rng = SystemRandomNumberGenerator()
        pieces = (0..<40).map { i in
            Piece(
                x: CGFloat.random(in: 0...1, using: &rng),
                delay: Double.random(in: 0...0.8, using: &rng),
                color: ConfettiLayer.palette[i % ConfettiLayer.palette.count],
                width: CGFloat.random(in: 6...14, using: &rng),
                height: CGFloat.random(in: 10...20, using: &rng)
            )
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                ZStack {
                    ForEach(0..<pieces.count, id: \.self) { i in
                        let p = pieces[i]
                        let local = (t - p.delay).truncatingRemainder(dividingBy: 4.5)
                        let progress = max(0, local) / 4.5
                        let y = -CGFloat(40) + progress * (proxy.size.height + 80)
                        Rectangle()
                            .fill(p.color)
                            .frame(width: p.width, height: p.height)
                            .cornerRadius(2)
                            .rotationEffect(.degrees(progress * 720))
                            .position(x: p.x * proxy.size.width, y: y)
                            .opacity(progress < 0.95 ? 1 : 0)
                    }
                }
            }
        }
    }
}
