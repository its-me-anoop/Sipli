import SwiftUI

struct StatPill: View {
    var label: String
    var value: String
    var icon: String? = nil
    var accentColor: Color = Theme.lagoon

    @State private var animatedValue: String = ""

    var body: some View {
        HStack(spacing: 10) {
            if let iconName = icon {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(Theme.captionFont(.caption2))
                    .foregroundStyle(Theme.textTertiary)

                Text(animatedValue)
                    .font(Theme.titleFont(.subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.card)
        )
        .shadow(color: Theme.shadowColor.opacity(0.58), radius: 7, x: 0, y: 3)
        .onAppear {
            animatedValue = value
        }
        .onChange(of: value) { _, newValue in
            withAnimation(Theme.fluidSpring) {
                animatedValue = newValue
            }
        }
    }
}
