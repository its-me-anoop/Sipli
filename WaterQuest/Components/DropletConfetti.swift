import SwiftUI

/// One-shot celebratory droplet burst. Purely decorative-looking but always
/// tied to a state change (goal crossed, badge unlocked) — never ambient.
///
/// Particles are drawn in a single `Canvas` driven by `TimelineView`, so the
/// whole burst costs one layer; motion is position/scale/opacity only.
/// Renders nothing when Reduce Motion is on.
struct DropletConfetti: View {
    /// Changes to this value trigger a fresh burst.
    let trigger: Int
    var particleCount: Int = 26

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burstStart: Date?

    private static let colors: [Color] = [Theme.lagoon, Theme.mint, Theme.sun, Theme.coral, Theme.lavender]
    private static let lifetime: TimeInterval = 2.0

    var body: some View {
        Group {
            if !reduceMotion, burstStart != nil {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        guard let start = burstStart else { return }
                        let t = timeline.date.timeIntervalSince(start)
                        guard t >= 0, t < Self.lifetime else { return }
                        drawParticles(context: context, size: size, t: t, seed: trigger)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .onChange(of: trigger) { _, _ in
            burstStart = Date()
            // Release the timeline once the burst has played out.
            let expected = trigger
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.lifetime + 0.1) {
                if trigger == expected { burstStart = nil }
            }
        }
    }

    private func drawParticles(context: GraphicsContext, size: CGSize, t: TimeInterval, seed: Int) {
        let origin = CGPoint(x: size.width / 2, y: size.height * 0.42)
        let progress = t / Self.lifetime

        for i in 0..<particleCount {
            // Cheap deterministic per-particle variation from the seed.
            var hash = UInt64(bitPattern: Int64(seed &* 31 &+ i &* 2_654_435_761))
            hash = hash &* 6364136223846793005 &+ 1442695040888963407
            func unit(_ shift: UInt64) -> Double {
                Double((hash >> shift) & 0xFFFF) / 65535.0
            }

            let angle = unit(0) * 2 * .pi
            let speed = 130 + unit(16) * 190
            let gravity = 380.0
            let x = origin.x + cos(angle) * speed * t
            let y = origin.y + sin(angle) * speed * t * 0.7 + 0.5 * gravity * t * t
            let scale = 0.6 + unit(32) * 0.9
            let fade = max(0, 1 - progress * progress * 1.4)
            let color = Self.colors[i % Self.colors.count]

            var drop = context
            drop.opacity = fade
            drop.translateBy(x: x, y: y)
            drop.rotate(by: .radians(angle + t * 2))
            drop.scaleBy(x: scale, y: scale)

            let rect = CGRect(x: -4, y: -5, width: 8, height: 10)
            drop.fill(Ellipse().path(in: rect), with: .color(color))
        }
    }
}
