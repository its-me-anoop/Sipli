import SwiftUI

/// Earth Day Refill Pledge sheet. Presents a shareable pledge card the user
/// can export via iOS share sheet. Purely local — no network, no analytics.
struct EarthDayPledgeView: View {
    @EnvironmentObject private var store: HydrationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    @State private var shareImage: Image?

    private var trimmedName: String {
        store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasName: Bool { !trimmedName.isEmpty }

    private var pledgeText: String {
        var text = "I pledge to refill, not rebuy, this Earth Week. 🌍💧"
        if hasName { text += "\n— \(trimmedName)" }
        text += "\n\nEvery sip tracked is one less plastic bottle."
        text += "\n\nTrack your hydration with Sipli\n\(Legal.appStoreURL.absoluteString)"
        return text
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Take the Refill Pledge")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    Text("A small Earth Week commitment. Sipli's refill habit is better for you — and a bit kinder to the planet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    pledgeCard
                        .padding(.horizontal, 12)

                    VStack(spacing: 12) {
                        if let shareImage {
                            ShareLink(
                                item: shareImage,
                                subject: Text("Sipli Refill Pledge"),
                                message: Text(pledgeText),
                                preview: SharePreview("Sipli Refill Pledge", image: shareImage)
                            ) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share My Pledge")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule().fill(
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
                            }
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }

                        Button("Maybe Later") {
                            dismiss()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .background { AppWaterBackground().ignoresSafeArea() }
            .navigationTitle("Earth Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { renderShareImage() }
            .onChange(of: trimmedName) { _, _ in renderShareImage() }
        }
    }

    // MARK: - Shareable pledge card

    private var pledgeCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.white)
                Text("EARTH WEEK 2026")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .tracking(1.5)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.18)))

            Text("I pledge to refill,\nnot rebuy,\nthis Earth Week.")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if hasName {
                Text("— \(trimmedName)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }

            VStack(spacing: 2) {
                Text("Every sip tracked")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text("is one less plastic bottle.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image("sipliIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text("Sipli")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                }

                DownloadOnAppStoreBadge()
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.62, blue: 0.42),
                            Color(red: 0.08, green: 0.44, blue: 0.30),
                            Color(red: 0.04, green: 0.30, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 8)
    }

    @MainActor
    private func renderShareImage() {
        let renderer = ImageRenderer(content:
            pledgeCard
                .frame(width: 360)
                .padding(24)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.88, green: 0.96, blue: 0.90),
                            Color(red: 0.72, green: 0.90, blue: 0.80)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        renderer.scale = displayScale

        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}

// MARK: - Download on the App Store Badge

/// Recreates Apple's official "Download on the App Store" badge using SwiftUI.
/// Follows Apple's marketing guidelines: black rounded rectangle with white
/// Apple logo, "Download on the" caption, and "App Store" wordmark.
private struct DownloadOnAppStoreBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "applelogo")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: -1) {
                Text("Download on the")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white)
                    .tracking(0.2)
                Text("App Store")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .tracking(-0.3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 1)
        )
    }
}

#if DEBUG
#Preview("Earth Day Pledge") {
    EarthDayPledgeView()
}
#endif
