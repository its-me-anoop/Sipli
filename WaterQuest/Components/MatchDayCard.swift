import SwiftUI

/// Dashboard content for the Match Day football-summer challenge.
/// Free feature, visible only while `MatchDay.isActive()`.
///
/// Copy and imagery stay strictly generic-football (SF Symbols ball, no
/// tournament marks) — see the header comment in `MatchDay.swift`.
struct MatchDayCard: View {
    let progress: Double
    let score: Int
    let wins: Int
    let phase: MatchDay.Phase

    private var pitchGreen: Color { Color(red: 0.18, green: 0.55, blue: 0.34) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(MatchDay.commentary(phase: phase, progress: progress, score: score))
                .font(Theme.editorialSerif(18, weight: .semibold, relativeTo: .headline))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Image(systemName: "soccerball")
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(MatchDay.scoreline(score: score, progress: progress))
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
                Spacer()
                phaseBadge
            }

            scarfProgressBar

            HStack(spacing: 8) {
                Image(systemName: "waterbottle.fill")
                    .font(.caption)
                    .foregroundStyle(wins >= MatchDay.winsForGoldenBottle ? Theme.sun : .secondary)
                Text(MatchDay.winsSummary(wins: wins))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Match day. \(MatchDay.commentary(phase: phase, progress: progress, score: score)) \(MatchDay.winsSummary(wins: wins))"
        )
    }

    private var phaseBadge: some View {
        Text(phaseLabel)
            .font(Theme.sipliMono(10, weight: .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(pitchGreen.opacity(0.16)))
            .foregroundStyle(pitchGreen)
    }

    private var phaseLabel: String {
        switch phase {
        case .firstHalf: return "First Half"
        case .secondHalf: return "Second Half"
        case .extraTime: return "Extra Time"
        case .fullTime: return "Full Time"
        }
    }

    /// Scarf-stripe progress bar: alternating green stripes under a clear
    /// fill mask — reads as a football scarf without any club colours.
    private var scarfProgressBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                stripes.opacity(0.22)
                stripes
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: max(0, min(1, progress)) * width)
                    }
            }
            .clipShape(Capsule())
            .animation(Theme.fluidSpring, value: progress)
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    private var stripes: some View {
        HStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { index in
                Rectangle()
                    .fill(index.isMultiple(of: 2) ? pitchGreen : pitchGreen.opacity(0.55))
            }
        }
    }
}

// MARK: - Goal celebration (football variant)

/// Shown instead of the droplet celebration while Match Day is active:
/// the ball rolls in from the leading edge, "GOAL!" pops, and a burst of
/// pitch-green and brand-colour confetti falls. Transform/opacity only;
/// under Reduce Motion it renders a static badge instead.
struct FootballCelebrationOverlay: View {
    @Binding var isShowing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var ballOffset: CGFloat = -240
    @State private var ballRotation: Double = 0
    @State private var textScale: Double = 0.4
    @State private var textOpacity: Double = 0
    @State private var confettiFired = false

    private static let confettiColors: [Color] = [
        Color(red: 0.18, green: 0.55, blue: 0.34), // pitch green
        Theme.lagoon, Theme.mint, Theme.sun, Theme.coral,
    ]

    var body: some View {
        ZStack {
            if reduceMotion {
                staticBadge
            } else {
                animatedCelebration
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            Haptics.splash()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                isShowing = false
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Goal! Today's match is won.")
    }

    private var staticBadge: some View {
        VStack(spacing: 8) {
            Image(systemName: "soccerball")
                .font(.system(size: 44))
            Text("GOAL!")
                .font(Theme.editorialSerif(34, weight: .bold, relativeTo: .largeTitle))
        }
        .foregroundStyle(.primary)
    }

    private var animatedCelebration: some View {
        ZStack {
            if confettiFired {
                ForEach(0..<12, id: \.self) { index in
                    ConfettiPiece(
                        color: Self.confettiColors[index % Self.confettiColors.count],
                        angle: Double(index) * 30,
                        delay: Double(index) * 0.02
                    )
                }
            }

            Image(systemName: "soccerball")
                .font(.system(size: 52))
                .foregroundStyle(.primary)
                .rotationEffect(.degrees(ballRotation))
                .offset(x: ballOffset)

            Text("GOAL!")
                .font(Theme.editorialSerif(40, weight: .bold, relativeTo: .largeTitle))
                .scaleEffect(textScale)
                .opacity(textOpacity)
                .offset(y: -64)
        }
        .onAppear {
            withAnimation(Theme.fluidSpring) {
                ballOffset = 0
                ballRotation = 720
            }
            withAnimation(Theme.quickSpring.delay(0.35)) {
                textScale = 1.0
                textOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                confettiFired = true
            }
        }
    }
}

/// One confetti fleck: flies outward from centre and fades. Transform/opacity only.
private struct ConfettiPiece: View {
    let color: Color
    let angle: Double
    let delay: Double

    @State private var distance: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 8, height: 12)
            .rotationEffect(.degrees(angle * 3))
            .offset(
                x: cos(angle * .pi / 180) * distance,
                y: sin(angle * .pi / 180) * distance
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9).delay(delay)) {
                    distance = 130
                    opacity = 0
                }
            }
    }
}

#Preview("Match Day Card") {
    VStack(spacing: 24) {
        DashboardCard(title: "Match Day", icon: "soccerball") {
            MatchDayCard(progress: 0.42, score: 3, wins: 5, phase: .secondHalf)
        }
        DashboardCard(title: "Match Day", icon: "soccerball") {
            MatchDayCard(progress: 1.0, score: 8, wins: 12, phase: .fullTime)
        }
    }
    .padding()
    .background { AppWaterBackground().ignoresSafeArea() }
}
