import SwiftUI

/// The Sipli droplet. From v5.0 it grows with the user's streak — the same
/// character, visibly thriving, rather than a menagerie of collectibles:
/// - 7+ day streak: a mint aura joins the glow
/// - 30+ day streak: orbiting sparkles
/// - 100+ day streak: a small crown
struct MascotView: View {
    var size: CGFloat = 80
    var animated: Bool = true
    /// Current goal streak; drives the evolution tier. Defaults to 0 so
    /// existing call sites (onboarding, splash) show the base droplet.
    var streak: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounceOffset: CGFloat = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var eyeBlink: Bool = false
    @State private var mouthWidth: CGFloat = 18
    @State private var sparkleRotation: Double = 0
    @State private var blinkTimer: Timer?

    private var hasAura: Bool { streak >= 7 }
    private var hasSparkles: Bool { streak >= 30 }
    private var hasCrown: Bool { streak >= 100 }

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
                    .frame(width: size * 1.42, height: size * 1.42)
                    .rotationEffect(.degrees(sparkleRotation))
            }

            // Orbiting sparkles at the 30-day tier.
            if hasSparkles {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.11, weight: .semibold))
                        .foregroundStyle(Theme.sun.opacity(0.85))
                        .offset(y: -size * 0.82)
                        .rotationEffect(.degrees(Double(i) * 120 + sparkleRotation))
                }
            }

            // Drop body
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.lagoon, Theme.mint.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Theme.lagoon.opacity(0.5), radius: 16, x: 0, y: 8)
                .frame(width: size, height: size * 1.25)

            // Crown at the 100-day tier — small and proud, not a costume.
            if hasCrown {
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.22, weight: .semibold))
                    .foregroundStyle(Theme.sun)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -size * 0.18, y: -size * 0.68)
                    .shadow(color: Theme.sun.opacity(0.5), radius: 4, x: 0, y: 2)
            }

            // Face
            VStack(spacing: size * 0.06) {
                // Eyes
                HStack(spacing: size * 0.12) {
                    eye
                    eye
                }

                // Mouth — happy little curve
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: mouthWidth, height: size * 0.045)
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: mouthWidth * 0.6, height: size * 0.03)
                            .offset(y: size * 0.015)
                    )
            }
            .offset(y: size * 0.12)

            // Sparkle highlights
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: -size * 0.15, y: -size * 0.15)

            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: size * 0.05, height: size * 0.05)
                .offset(x: -size * 0.08, y: -size * 0.22)
        }
        .offset(y: bounceOffset)
        .accessibilityLabel(mascotAccessibilityLabel)
        .onAppear {
            guard animated, !reduceMotion else { return }
            // Gentle bob
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                bounceOffset = -8
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
            // Blink loop
            startBlinking()
        }
        .onDisappear {
            blinkTimer?.invalidate()
            blinkTimer = nil
        }
    }

    private var mascotAccessibilityLabel: String {
        if hasCrown { return "Sipli mascot with a crown — 100-day streak tier" }
        if hasSparkles { return "Sipli mascot with sparkles — 30-day streak tier" }
        if hasAura { return "Sipli mascot with an aura — 7-day streak tier" }
        return "Sipli mascot"
    }

    private var eye: some View {
        ZStack {
            // Eye white
            Capsule()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.09, height: eyeBlink ? size * 0.02 : size * 0.09)
            // Pupil
            if !eyeBlink {
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: size * 0.055, height: size * 0.055)
                    .offset(y: size * 0.005)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: eyeBlink)
    }

    private func startBlinking() {
        // Invalidate any previous loop — onAppear can fire again for the same
        // view identity, and an unreferenced repeating timer lives forever.
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            eyeBlink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                eyeBlink = false
            }
        }
    }
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
