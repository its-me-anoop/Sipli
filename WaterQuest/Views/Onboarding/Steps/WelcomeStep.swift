import SwiftUI

struct WelcomeStep: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bobOffset: CGFloat = 0
    @State private var dropPhase: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            SipliTopBar(stepIndex: 0, total: OnboardingStep.displayedTotal, canGoBack: false, onBack: {})

            VStack(spacing: 0) {
                hero
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)

                welcomeText
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack {
                SipliCTA(title: "Get started", action: onContinue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .padding(.top, 16)
        }
        .background(OnboardingPalette.paper)
        .onAppear { startAnimations() }
    }

    private var hero: some View {
        GeometryReader { proxy in
            ZStack {
                // Hero box with tinted background + soft radial glow
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.910, green: 0.957, blue: 0.984))
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(red: 0.122, green: 0.639, blue: 0.910).opacity(0.18), .clear],
                                    center: .center, startRadius: 5, endRadius: 200
                                )
                            )
                            .frame(width: 360, height: 360)
                            .blur(radius: 8)
                    )

                // Animated water — anchored to the bottom of the hero,
                // occupying the lower ~55% so the bottle dips into it.
                ZStack(alignment: .bottom) {
                    Color.clear  // anchor for alignment
                    waterLayer(width: proxy.size.width, opacity: 0.85, ampPx: 16, period: 9, phaseShift: 0)
                        .frame(height: proxy.size.height * 0.55, alignment: .bottom)
                    waterLayer(width: proxy.size.width, opacity: 0.40, ampPx: 12, period: 11, phaseShift: .pi)
                        .frame(height: proxy.size.height * 0.50, alignment: .bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                // Floating drops
                FloatingDrops(phase: dropPhase, reduceMotion: reduceMotion)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                // Bottle with bob — sits centered, bottom dips into water.
                SipliBottle(fill: 0.62, size: 200)
                    .offset(y: bobOffset)
                    .rotationEffect(.degrees(bobOffset == 0 ? 0 : -3))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    @ViewBuilder
    private func waterLayer(width: CGFloat, opacity: Double, ampPx: CGFloat, period: Double, phaseShift: Double) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? phaseShift : (t * (2 * .pi / period) + phaseShift)
            WaterFill(phase: phase, amplitude: ampPx)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.749, green: 0.902, blue: 0.957), Color(red: 0.122, green: 0.616, blue: 0.867)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .opacity(opacity)
                .frame(width: width)
        }
    }

    private var welcomeText: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SipliMark(size: 24)
                Text("SIPLI")
                    .font(.sipliMono(12, weight: .semibold, relativeTo: .caption))
                    .tracking(1.6)
                    .foregroundStyle(OnboardingPalette.ink)
            }

            (Text("Drink water\nlike you ").foregroundStyle(OnboardingPalette.ink)
            + Text("mean it.").italic().foregroundStyle(OnboardingPalette.water))
                .font(.editorialSerif(46, relativeTo: .largeTitle))
                .lineSpacing(-2)

            Text("A hydration habit that actually fits in your life. No streaks to lose sleep over.")
                .font(.system(size: 15))
                .foregroundStyle(OnboardingPalette.ink3)
                .lineSpacing(2)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            bobOffset = -8
        }
        // Animate drops via TimelineView; phase advances continuously.
    }
}

/// Wavy fill — wave surface sits near the TOP of the supplied rect, the body
/// fills down to the bottom edge. Amplitude stays clear of the rect's top
/// so the wave never clips.
private struct WaterFill: Shape {
    var phase: Double
    var amplitude: CGFloat

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let baseY = amplitude + 4   // clearance from rect.top
        let step: CGFloat = 6
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: baseY))
        var x: CGFloat = 0
        while x <= w {
            let t = x / w
            let y = baseY + sin(t * .pi * 4 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

private struct FloatingDrops: View {
    let phase: Double
    let reduceMotion: Bool

    private struct DropConfig {
        let xPct: CGFloat
        let yPct: CGFloat
        let delay: Double
    }

    private let drops: [DropConfig] = [
        .init(xPct: 0.12, yPct: 0.14, delay: 0.0),
        .init(xPct: 0.82, yPct: 0.18, delay: 1.2),
        .init(xPct: 0.18, yPct: 0.40, delay: 2.1),
        .init(xPct: 0.86, yPct: 0.45, delay: 0.8)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                ForEach(0..<drops.count, id: \.self) { i in
                    let drop = drops[i]
                    let cycle: Double = 3.0
                    let phase = reduceMotion ? 0 : ((t - drop.delay).truncatingRemainder(dividingBy: cycle) / cycle)
                    let progress = max(0, min(1, phase))
                    Circle()
                        .fill(Color.white.opacity(0.55 * (1 - progress)))
                        .frame(width: 12, height: 14)
                        .rotationEffect(.degrees(180))
                        .position(
                            x: drop.xPct * proxy.size.width,
                            y: (drop.yPct + progress * 0.05) * proxy.size.height
                        )
                        .scaleEffect(0.7 + progress * 0.3)
                        .opacity(reduceMotion ? 0.4 : 1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
