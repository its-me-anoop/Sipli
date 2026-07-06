import SwiftUI

/// Full-screen celebration for a newly earned badge. Presents the head of
/// `HydrationStore.pendingAchievementUnlocks`; dismissing pops the queue so
/// multiple unlocks play one at a time.
struct AchievementUnlockOverlay: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var confettiTrigger = 0
    @State private var sharePayload: ShareCardPayload?
    @State private var isDismissing = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            DropletConfetti(trigger: confettiTrigger)
                .ignoresSafeArea()

            card
                .scaleEffect(appeared || reduceMotion ? 1 : 0.82)
                .opacity(appeared ? 1 : 0)
                .padding(.horizontal, 36)
        }
        .onAppear {
            Haptics.success()
            sharePayload = ShareCardRenderer.render(.achievement(achievement, earnedOn: Date()))
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.72)) {
                appeared = true
            }
            if !reduceMotion {
                confettiTrigger += 1
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(spacing: 20) {
            Text("Achievement unlocked")
                .font(Theme.sipliMono(11, weight: .semibold, relativeTo: .caption))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)

            ZStack {
                Circle()
                    .fill(Theme.glowGradient)
                    .frame(width: 104, height: 104)
                    .shadow(color: Theme.lagoon.opacity(0.4), radius: 20, x: 0, y: 8)
                Image(systemName: achievement.symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: reduceMotion ? false : appeared)
            }

            VStack(spacing: 6) {
                Text(achievement.title)
                    .font(Theme.editorialSerif(28, weight: .semibold, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(achievement.detail)
                    .font(Theme.bodyFont())
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                if let payload = sharePayload {
                    ShareLink(
                        item: payload,
                        message: Text(payload.caption),
                        preview: SharePreview(achievement.title, image: Image(systemName: achievement.symbol))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(Theme.titleFont(.body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.lagoon, in: Capsule())
                    }
                }

                Button(action: dismiss) {
                    Text("Keep going")
                        .font(Theme.titleFont(.body))
                        .foregroundStyle(Theme.lagoon)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.top, 4)
        }
        .padding(28)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Theme.glassBorder, lineWidth: 1)
                )
                .shadow(color: Theme.shadowColor, radius: 24, x: 0, y: 12)
        }
    }

    private func dismiss() {
        // Scrim tap + button tap (or a double-tap) must not pop the queue
        // twice and swallow the next celebration.
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Theme.quickSpring) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onDismiss()
        }
    }
}

#if DEBUG
#Preview("Unlock") {
    ZStack {
        AppWaterBackground()
        AchievementUnlockOverlay(achievement: AchievementCatalog.all[1]) {}
    }
}
#endif
