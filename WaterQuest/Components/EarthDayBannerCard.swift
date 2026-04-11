import SwiftUI

/// Time-gated Earth Week banner that appears on the Dashboard between
/// April 20-26, 2026. Reuses the same visual language as `DashboardCard`
/// but with a leaf-green gradient and the Earth Week messaging.
struct EarthDayBannerCard: View {
    let onLearnMore: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: "leaf.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Earth Week")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("Apr 20-26")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.white.opacity(0.18))
                        )
                }

                Text("Every refill is one less plastic bottle.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: {
                    Haptics.selection()
                    onLearnMore()
                }) {
                    HStack(spacing: 6) {
                        Text("Take the Refill Pledge")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color(red: 0.05, green: 0.33, blue: 0.22))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.white.opacity(0.95))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)

            Button(action: {
                Haptics.selection()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(Color.white.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss Earth Week banner")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.62, blue: 0.42),
                            Color(red: 0.05, green: 0.45, blue: 0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Earth Week. Every refill is one less plastic bottle. Take the refill pledge.")
    }
}

#if DEBUG
#Preview("Earth Day Banner") {
    VStack {
        EarthDayBannerCard(onLearnMore: {}, onDismiss: {})
            .padding()
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
#endif
