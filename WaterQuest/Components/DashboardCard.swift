import SwiftUI

struct DashboardCard<Content: View>: View {
    let title: String
    var icon: String? = nil
    var backgroundGradient: LinearGradient = Theme.card
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let icon = icon {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(Theme.lagoon)
                        .font(.headline)
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                }
            } else {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(backgroundGradient)
        )
        .shadow(color: Theme.shadowColor.opacity(0.5), radius: 10, x: 0, y: 5)
    }
}

struct PremiumSoftSellBanner: View {
    let title: String
    let message: String
    let featurePills: [(icon: String, text: String)]
    let ctaTitle: String
    let onDismiss: () -> Void
    let onShowPremium: () -> Void
    var onBackgroundTap: (() -> Void)? = nil

    @State private var rippleCounter = 0
    @State private var rippleOrigin = CGPoint(x: 180, y: 72)
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.sun.opacity(0.16))
                            .frame(width: isRegular ? 48 : 40, height: isRegular ? 48 : 40)
                        Image(systemName: "sparkles")
                            .font(isRegular ? .title3 : .body.weight(.semibold))
                            .foregroundStyle(Theme.sun)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(isRegular ? .title3 : .headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)

                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 10)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss premium suggestion")
            }

            if isRegular {
                HStack(spacing: 12) {
                    ForEach(Array(featurePills.enumerated()), id: \.offset) { item in
                        featurePill(icon: item.element.icon, text: item.element.text)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(featurePills.enumerated()), id: \.offset) { item in
                        featurePill(icon: item.element.icon, text: item.element.text)
                    }
                }
            }

            HStack {
                Button(action: onShowPremium) {
                    Text(ctaTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            Capsule()
                                .fill(Theme.lagoon)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Dismiss for now")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(isRegular ? 22 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            onBackgroundTap?()
        }
        .modifier(RippleEffect(at: rippleOrigin, trigger: rippleCounter))
        .onAppear {
            rippleOrigin = CGPoint(x: isRegular ? 320 : 180, y: 72)
            rippleCounter += 1
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.sun.opacity(0.10),
                                Theme.lagoon.opacity(0.08),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.28),
                                Theme.glassBorder.opacity(0.35),
                                Theme.sun.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Theme.shadowColor.opacity(0.32), radius: 14, x: 0, y: 10)
    }

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Theme.lagoon)
                .frame(width: 16)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule()
                .fill(.white.opacity(0.16))
        )
    }
}
