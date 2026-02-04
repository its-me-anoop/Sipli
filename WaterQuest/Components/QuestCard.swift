import SwiftUI

struct QuestCard: View {
    var quest: Quest
    var progress: Double

    @State private var isPressed = false
    @State private var showCheckmark = false
    @State private var glowIntensity: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Quest icon
                ZStack {
                    Circle()
                        .fill(quest.isCompleted ? Theme.sun.opacity(0.3) : Theme.lagoon.opacity(0.2))
                        .frame(width: 40, height: 40)

                    if quest.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.sun)
                            .scaleEffect(showCheckmark ? 1 : 0)
                    } else {
                        Image(systemName: questIcon)
                            .font(.system(size: 16))
                            .foregroundColor(Theme.lagoon)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title)
                        .font(Theme.titleFont(size: 15))
                        .foregroundColor(.white)
                        .strikethrough(quest.isCompleted, color: .white.opacity(0.5))

                    Text(quest.detail)
                        .font(Theme.bodyFont(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer()

                // Reward badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("+\(quest.rewardXP)")
                        .font(Theme.bodyFont(size: 11))
                        .fontWeight(.semibold)
                }
                .foregroundColor(Theme.sun)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Theme.sun.opacity(0.15))
                        .overlay(
                            Capsule()
                                .strokeBorder(Theme.sun.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))

                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: quest.isCompleted
                                    ? [Theme.sun.opacity(0.8), Theme.sun]
                                    : [Theme.mint.opacity(0.8), Theme.lagoon],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)

                }
            }
            .frame(height: 6)
            .animation(Theme.fluidSpring, value: progress)

            // Completion message
            if quest.isCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 12))
                    Text("Quest complete!")
                        .font(Theme.bodyFont(size: 12))
                        .fontWeight(.medium)
                }
                .foregroundColor(Theme.sun)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.liquidGlassGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: quest.isCompleted
                                    ? [Theme.sun.opacity(0.4), Theme.sun.opacity(0.1)]
                                    : [Theme.glassBorder, Theme.glassBorder.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: quest.isCompleted ? Theme.sun.opacity(0.2) : Color.black.opacity(0.15),
            radius: quest.isCompleted ? 12 : 8,
            x: 0,
            y: 4
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(Theme.quickSpring, value: isPressed)
        .animation(Theme.fluidSpring, value: quest.isCompleted)
        .onChange(of: quest.isCompleted) { _, completed in
            if completed {
                withAnimation(Theme.quickSpring.delay(0.1)) {
                    showCheckmark = true
                }
                Haptics.questComplete()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(Theme.quickSpring) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(Theme.quickSpring) { isPressed = false }
                }
        )
    }

    private var questIcon: String {
        let title = quest.title.lowercased()
        if title.contains("morning") || title.contains("early") {
            return "sunrise.fill"
        } else if title.contains("goal") || title.contains("complete") {
            return "target"
        } else if title.contains("streak") {
            return "flame.fill"
        } else if title.contains("drink") || title.contains("water") {
            return "drop.fill"
        }
        return "flag.fill"
    }
}
