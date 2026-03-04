import SwiftUI

struct SplashScreenView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            AppWaterBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: isRegular ? 180 : 120)

                SplashHeroView(isRegular: isRegular, reduceMotion: reduceMotion)

                VStack(spacing: isRegular ? 12 : 8) {
                    Text("Sipli")
                        .font(.system(isRegular ? .largeTitle : .title, design: .rounded).weight(.bold))
                        .kerning(0.3)
                    Text("Hydration that fits your day")
                        .font(isRegular ? .title3.weight(.medium) : .subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, isRegular ? 36 : 26)

                Spacer()

                VStack(spacing: 10) {
                    ProgressView()
                        .tint(Theme.lagoon)
                        .controlSize(.regular)
                    Text("Getting things ready...")
                        .font(isRegular ? .subheadline : .footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, isRegular ? 72 : 56)
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct SplashHeroView: View {
    let isRegular: Bool
    let reduceMotion: Bool

    private var ringSize: CGFloat { isRegular ? 252 : 186 }
    private var coreSize: CGFloat { isRegular ? 162 : 118 }
    private var mascotSize: CGFloat { isRegular ? 112 : 84 }

    var body: some View {
        if reduceMotion {
            heroContent(time: 0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                heroContent(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    @ViewBuilder
    private func heroContent(time: TimeInterval) -> some View {
        let phaseA = time.truncatingRemainder(dividingBy: 2.4)
        let phaseB = (time + 1.2).truncatingRemainder(dividingBy: 2.9)
        let orbitX = cos(time * 1.2)
        let orbitY = sin(time * 1.1)

        ZStack {
            Circle()
                .fill(Theme.progressGlow)
                .frame(width: ringSize * 1.25, height: ringSize * 1.25)
                .blur(radius: 12)
                .opacity(0.72)

            Circle()
                .stroke(Theme.lagoon.opacity(0.3), lineWidth: 1.4)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .stroke(Theme.mint.opacity(0.22), lineWidth: 1)
                .frame(width: ringSize * 0.76, height: ringSize * 0.76)

            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Theme.lagoon.opacity(0.25),
                            Theme.mint.opacity(0.2),
                            Theme.lavender.opacity(0.2),
                            Theme.lagoon.opacity(0.25)
                        ],
                        center: .center
                    )
                )
                .frame(width: coreSize, height: coreSize)
                .modifier(
                    RippleModifier(
                        origin: CGPoint(
                            x: coreSize * 0.5 + CGFloat(orbitX) * 22,
                            y: coreSize * 0.5 + CGFloat(orbitY) * 18
                        ),
                        elapsedTime: phaseA,
                        duration: 2.4,
                        amplitude: 14,
                        frequency: 19,
                        decay: 7,
                        speed: 980
                    )
                )
                .modifier(
                    RippleModifier(
                        origin: CGPoint(
                            x: coreSize * 0.5 - CGFloat(orbitY) * 20,
                            y: coreSize * 0.5 + CGFloat(orbitX) * 20
                        ),
                        elapsedTime: phaseB,
                        duration: 2.9,
                        amplitude: 12,
                        frequency: 16,
                        decay: 6,
                        speed: 920
                    )
                )
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.26), .clear],
                                center: .topLeading,
                                startRadius: 1,
                                endRadius: coreSize * 0.66
                            )
                        )
                )
                .compositingGroup()
                .shadow(color: Theme.lagoon.opacity(0.35), radius: 18, x: 0, y: 8)

            Circle()
                .fill(Color.white.opacity(0.42))
                .frame(width: isRegular ? 13 : 10, height: isRegular ? 13 : 10)
                .blur(radius: 0.2)
                .offset(
                    x: CGFloat(cos(time * 1.5)) * (coreSize * 0.44),
                    y: CGFloat(sin(time * 1.3)) * (coreSize * 0.42)
                )
                .opacity(reduceMotion ? 0.65 : 0.95)

            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: mascotSize, height: mascotSize)
                .shadow(color: Theme.lagoon.opacity(0.36), radius: 16, x: 0, y: 6)
                .accessibilityHidden(true)
        }
        .frame(width: ringSize * 1.36, height: ringSize * 1.36)
    }
}

#if DEBUG
#Preview("Splash") {
    PreviewEnvironment {
        SplashScreenView()
    }
}
#endif
