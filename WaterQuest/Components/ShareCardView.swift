import SwiftUI
import UniformTypeIdentifiers

// MARK: - Content model

/// What a share card shows. Kept as a value type so rendering is a pure
/// function of content — trivially previewable and testable.
enum ShareCardContent {
    case daily(totalML: Double, goalML: Double, streak: Int, unitSystem: UnitSystem, date: Date)
    case weekly(dayFractions: [Double], goalDays: Int, totalML: Double, unitSystem: UnitSystem, weekEnding: Date)
    case achievement(Achievement, earnedOn: Date)

    var caption: String {
        switch self {
        case .daily(let total, let goal, _, let unit, _):
            let pct = goal > 0 ? Int((total / goal) * 100) : 0
            return "\(Formatters.volumeString(ml: total, unit: unit)) today — \(pct)% of my goal, tracked with Sipli"
        case .weekly(_, let goalDays, _, _, _):
            return "\(goalDays) goal day\(goalDays == 1 ? "" : "s") this week, tracked with Sipli"
        case .achievement(let achievement, _):
            return "Just earned “\(achievement.title)” in Sipli"
        }
    }
}

// MARK: - Transferable payload

/// PNG payload for `ShareLink`. The image is rendered up front (cards are
/// tiny — a few ms at 3×) so the share sheet opens instantly.
struct ShareCardPayload: Transferable, Identifiable {
    let id = UUID()
    let pngData: Data
    let caption: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { payload in
            payload.pngData
        }
    }
}

// MARK: - Renderer

@MainActor
enum ShareCardRenderer {
    /// Renders a card at 3× (1080 × 1350 px — a 4:5 feed-friendly frame).
    static func render(_ content: ShareCardContent, colorScheme: ColorScheme = .light) -> ShareCardPayload? {
        let renderer = ImageRenderer(
            content: ShareCardView(content: content)
                .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 450)
        guard let data = renderer.uiImage?.pngData() else { return nil }
        return ShareCardPayload(pngData: data, caption: content.caption)
    }
}

// MARK: - One-tap share sheet

/// UIKit share sheet for surfaces where `ShareLink`'s eager-payload model
/// doesn't fit (toolbar buttons that render the card on demand).
struct ActivityShareSheet: UIViewControllerRepresentable {
    let payload: ShareCardPayload

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = [payload.caption]
        if let image = UIImage(data: payload.pngData) {
            items.insert(image, at: 0)
        }
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Card view

/// The 360 × 450 pt composition that gets rendered to an image. Static by
/// design — no animation, no interactivity; it's a poster, not a screen.
struct ShareCardView: View {
    let content: ShareCardContent

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                centerpiece
                Spacer(minLength: 0)
                footer
            }
            .padding(28)
        }
        .frame(width: 360, height: 450)
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow)
                    .font(Theme.sipliMono(11, weight: .semibold, relativeTo: .caption))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textSecondary)
                Text(dateLine)
                    .font(Theme.editorialSerif(20, weight: .medium, relativeTo: .headline))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            MascotView(size: 44, animated: false)
        }
    }

    @ViewBuilder
    private var centerpiece: some View {
        switch content {
        case .daily(let total, let goal, let streak, let unit, _):
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Theme.lagoon.opacity(0.12), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: min(1, goal > 0 ? total / goal : 0))
                        .stroke(
                            AngularGradient(colors: [Theme.lagoon, Theme.mint, Theme.lagoon], center: .center),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(Formatters.volumeString(ml: total, unit: unit))
                            .font(Theme.editorialSerif(34, weight: .semibold, relativeTo: .title))
                            .foregroundStyle(Theme.lagoon)
                        Text("of \(Formatters.volumeString(ml: goal, unit: unit))")
                            .font(Theme.sipliMono(11, relativeTo: .caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 190, height: 190)

                if streak > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Theme.sun)
                        Text("\(streak)-day streak")
                            .font(Theme.sipliMono(13, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(Theme.ink)
                    }
                }
            }

        case .weekly(let fractions, let goalDays, let total, let unit, _):
            VStack(spacing: 18) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(fractions.prefix(7).enumerated()), id: \.offset) { _, fraction in
                        let clamped = min(1, max(0.04, fraction))
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(fraction >= 1 ? AnyShapeStyle(Theme.glowGradient) : AnyShapeStyle(Theme.lagoon.opacity(0.25)))
                                .frame(width: 26, height: 20 + 110 * clamped)
                        }
                    }
                }
                VStack(spacing: 3) {
                    Text("\(goalDays) of 7 goal days")
                        .font(Theme.editorialSerif(26, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Theme.ink)
                    Text("\(Formatters.volumeString(ml: total, unit: unit)) across the week")
                        .font(Theme.sipliMono(12, relativeTo: .caption))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

        case .achievement(let achievement, _):
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Theme.glowGradient)
                        .frame(width: 130, height: 130)
                        .shadow(color: Theme.lagoon.opacity(0.35), radius: 22, x: 0, y: 10)
                    Image(systemName: achievement.symbol)
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(spacing: 4) {
                    Text(achievement.title)
                        .font(Theme.editorialSerif(30, weight: .semibold, relativeTo: .title))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Text(achievement.detail)
                        .font(Theme.sipliMono(12, relativeTo: .caption))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.lagoon)
            Text("Sipli")
                .font(Theme.editorialSerif(17, weight: .semibold, relativeTo: .body))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text("hydration, made a habit")
                .font(Theme.sipliMono(10, relativeTo: .caption2))
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var background: some View {
        ZStack {
            Theme.paper

            // Quiet concentric ripples anchored off-canvas bottom-right, so the
            // card reads as water without competing with the centerpiece.
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(Theme.lagoon.opacity(0.05 + Double(ring) * 0.015), lineWidth: 1.5)
                    .frame(width: 340 + CGFloat(ring) * 90)
                    .offset(x: 130, y: 240)
            }

            LinearGradient(
                colors: [Theme.mint.opacity(0.08), .clear, Theme.sun.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: Copy

    private var eyebrow: String {
        switch content {
        case .daily: return "Today's hydration"
        case .weekly: return "This week"
        case .achievement: return "Achievement unlocked"
        }
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        switch content {
        case .daily(_, _, _, _, let date): return formatter.string(from: date)
        case .weekly(_, _, _, _, let end): return "Week ending \(formatter.string(from: end))"
        case .achievement(_, let date): return formatter.string(from: date)
        }
    }
}

#if DEBUG
#Preview("Daily") {
    ShareCardView(content: .daily(totalML: 1850, goalML: 2200, streak: 6, unitSystem: .metric, date: Date()))
}

#Preview("Achievement") {
    ShareCardView(content: .achievement(AchievementCatalog.all[1], earnedOn: Date()))
}

#Preview("Weekly") {
    ShareCardView(content: .weekly(dayFractions: [1, 0.8, 1, 0.4, 1, 1, 0.9], goalDays: 4, totalML: 13400, unitSystem: .metric, weekEnding: Date()))
}
#endif
