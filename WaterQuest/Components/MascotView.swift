import SwiftUI

/// The Sipli bottle — the same glass bottle as Home and the app icon. It
/// grows with the user's streak — the same character, visibly thriving,
/// rather than a menagerie of collectibles:
/// - 7+ day streak: a mint aura joins the glow
/// - 30+ day streak: orbiting sparkles
/// - 100+ day streak: a small crown on the cap
struct MascotView: View {
    /// Roughly the old droplet's width; the bottle is drawn `size * 1.3` tall.
    var size: CGFloat = 80
    var animated: Bool = true
    /// Current goal streak; drives the evolution tier. Defaults to 0 so
    /// call sites without a streak show the plain bottle.
    var streak: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.spookyTheme) private var spookyTheme
    @State private var bounceOffset: CGFloat = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var sparkleRotation: Double = 0

    private var hasAura: Bool { streak >= 7 }
    private var hasSparkles: Bool { streak >= 30 }
    private var hasCrown: Bool { streak >= 100 }
    /// Spooky Season costume. A 100-day crown still wins.
    private var hasWitchHat: Bool { !hasCrown && spookyTheme }

    /// The bottle art fills 94% of its square image, so this is where the
    /// top of the cap sits above the centre.
    private var capTop: CGFloat { size * 1.3 * 0.47 }

    var body: some View {
        ZStack {
            // Glow ring
            if animated {
                Circle()
                    .fill(Theme.lagoon.opacity(0.12))
                    .frame(width: size * 1.6, height: size * 1.6)
                    .scaleEffect(glowScale)
                    .blur(radius: 12)
            }

            // Streak aura — a second, warmer ring that says "thriving".
            if hasAura {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [Theme.mint.opacity(0.0), Theme.mint.opacity(0.55), Theme.mint.opacity(0.0)],
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: size * 1.5, height: size * 1.5)
                    .rotationEffect(.degrees(sparkleRotation))
            }

            // Orbiting sparkles at the 30-day tier.
            if hasSparkles {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.11, weight: .semibold))
                        .foregroundStyle(Theme.sun.opacity(0.85))
                        .offset(y: -size * 0.85)
                        .rotationEffect(.degrees(Double(i) * 120 + sparkleRotation))
                }
            }

            // The bottle
            Image("sipliIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size * 1.3, height: size * 1.3)
                .shadow(color: Theme.lagoon.opacity(0.35), radius: 12, x: 0, y: 6)

            // Crown at the 100-day tier — small and proud, perched on the cap.
            if hasCrown {
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.24, weight: .semibold))
                    .foregroundStyle(Theme.sun)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -size * 0.04, y: -capTop - size * 0.1)
                    .shadow(color: Theme.sun.opacity(0.5), radius: 4, x: 0, y: 2)
            }

            if hasWitchHat {
                WitchHat()
                    .frame(width: size * 0.5, height: size * 0.42)
                    .rotationEffect(.degrees(-8))
                    .offset(x: -size * 0.03, y: -capTop - size * 0.1)
            }
        }
        .offset(y: bounceOffset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mascotAccessibilityLabel)
        .onAppear {
            guard animated, !reduceMotion else { return }
            // Gentle bob
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                bounceOffset = -6
            }
            // Pulse glow
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowScale = 1.15
            }
            // Slow orbit shared by the aura and sparkles.
            if hasAura || hasSparkles {
                withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                    sparkleRotation = 360
                }
            }
        }
    }

    private var mascotAccessibilityLabel: String {
        if hasCrown { return "Sipli bottle with a crown — 100-day streak tier" }
        if hasWitchHat { return "Sipli bottle in a witch hat for Spooky Season" }
        if hasSparkles { return "Sipli bottle with sparkles — 30-day streak tier" }
        if hasAura { return "Sipli bottle with an aura — 7-day streak tier" }
        return "Sipli bottle"
    }
}

#Preview("Mascot tiers") {
    HStack(spacing: 36) {
        MascotView(size: 56, streak: 0)
        MascotView(size: 56, streak: 8)
        MascotView(size: 56, streak: 31)
        MascotView(size: 56, streak: 120)
        MascotView(size: 56, streak: 3).environment(\.spookyTheme, true)
    }
    .padding(40)
    .background { AppWaterBackground().ignoresSafeArea() }
}

// MARK: – Large Hero Mascot for Onboarding

struct HeroMascotView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false
    @State private var ripple1: CGFloat = 0.6
    @State private var ripple2: CGFloat = 0.4
    @State private var ripple3: CGFloat = 0.5
    @State private var ripple1Opacity: Double = 0.3
    @State private var ripple2Opacity: Double = 0.25
    @State private var ripple3Opacity: Double = 0.2
    @State private var sparkleRotation: Double = 0

    var body: some View {
        ZStack {
            // Three layered water ripples
            Circle()
                .stroke(Theme.lagoon.opacity(ripple1Opacity), lineWidth: 2)
                .frame(width: 220, height: 220)
                .scaleEffect(ripple1)

            Circle()
                .stroke(Theme.mint.opacity(ripple2Opacity), lineWidth: 1.5)
                .frame(width: 220, height: 220)
                .scaleEffect(ripple2)

            Circle()
                .stroke(Theme.lavender.opacity(ripple3Opacity), lineWidth: 1)
                .frame(width: 220, height: 220)
                .scaleEffect(ripple3)

            // Orbiting sparkle particles
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 3, height: 3)
                    .offset(y: -100)
                    .rotationEffect(.degrees(Double(i) * 60 + sparkleRotation))
            }

            MascotView(size: 120, animated: true)
                .scaleEffect(appear ? 1 : 0.3)
                .opacity(appear ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else {
                appear = true
                return
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) {
                appear = true
            }
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) {
                ripple1 = 1.5
                ripple1Opacity = 0
            }
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false).delay(0.8)) {
                ripple2 = 1.4
                ripple2Opacity = 0
            }
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false).delay(1.6)) {
                ripple3 = 1.3
                ripple3Opacity = 0
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
        }
    }
}

/// Spooky Season costume for the mascot: a pointed hat with a pumpkin band.
private struct WitchHat: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack(alignment: .bottom) {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.22, y: h * 0.82))
                    path.addQuadCurve(to: CGPoint(x: w * 0.62, y: 0), control: CGPoint(x: w * 0.42, y: h * 0.3))
                    path.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.82), control: CGPoint(x: w * 0.62, y: h * 0.4))
                    path.closeSubpath()
                }
                .fill(SpookySeason.Palette.midnight)
                Rectangle()
                    .fill(SpookySeason.Palette.pumpkin)
                    .frame(width: w * 0.54, height: h * 0.1)
                    .offset(y: -h * 0.18)
                Capsule()
                    .fill(SpookySeason.Palette.midnight)
                    .frame(width: w, height: h * 0.18)
            }
        }
        .accessibilityHidden(true)
    }
}
