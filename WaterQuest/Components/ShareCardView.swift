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

    @MainActor var previewImage: Image {
        UIImage(data: pngData).map { Image(uiImage: $0) } ?? Image("sipliIcon")
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { payload in
            payload.pngData
        }
    }
}

// MARK: - Renderer

@MainActor
enum ShareCardRenderer {
    /// Renders at 3×. Catalog cards are 1080 × 1350; unusually long
    /// localized achievement copy gets a taller canvas instead of cropping.
    static func render(_ content: ShareCardContent, colorScheme: ColorScheme = .light, locale: Locale = .current) -> ShareCardPayload? {
        let size = ShareCardView.exportSize(for: content)
        let renderer = ImageRenderer(
            content: ShareCardView(content: content)
                .environment(\.colorScheme, colorScheme)
                .environment(\.locale, locale)
                .environment(\.dynamicTypeSize, .large)
        )
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
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

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.timeZone) private var timeZone

    static func exportSize(for content: ShareCardContent) -> CGSize {
        if case .achievement(let achievement, _) = content {
            return CGSize(width: 360, height: AchievementShareMetrics(achievement: achievement).height)
        }
        return CGSize(width: 360, height: 450)
    }

    var body: some View {
        Group {
            if case .achievement(let achievement, _) = content {
                AchievementSharePoster(achievement: achievement, dateLine: dateLine)
            } else {
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    centerpiece
                    Spacer(minLength: 0)
                    footer
                }
                .padding(28)
                .frame(width: 360, height: 450)
                // Decoration is paint, never an intrinsic-size participant.
                .background { background.frame(width: 360, height: 450).clipped() }
            }
        }
        .environment(\.dynamicTypeSize, .large)
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

        case .achievement:
            EmptyView() // Routed through AchievementSharePoster above.
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
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        switch content {
        case .daily(_, _, _, _, let date): return formatter.string(from: date)
        case .weekly(_, _, _, _, let end): return "Week ending \(formatter.string(from: end))"
        case .achievement(_, let date): return formatter.string(from: date)
        }
    }
}

/// Static export typography has fixed point sizes; accessibility settings on the
/// sender's phone must not resize and crop the recipient's image.
@MainActor
struct AchievementShareMetrics {
    let titleSize: CGFloat
    let detailSize: CGFloat
    let titleHeight: CGFloat
    let detailHeight: CGFloat
    let artworkHeight: CGFloat
    let height: CGFloat
    static let inset: CGFloat = 28
    static let textWidth: CGFloat = 304

    static func displayFont(_ size: CGFloat) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: .semibold)
        return font.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? font
    }
    static func measure(_ text: String, font: UIFont) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        return ceil((text as NSString).boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font, .paragraphStyle: style], context: nil).height) + 4
    }
    init(achievement: Achievement) {
        // Header, footer, category line, safe margins and inter-section gaps.
        let fixed: CGFloat = 28 * 2 + 34 + 30 + 14 + 8 + 8 + 12 + 12 + 14
        var result: (CGFloat, CGFloat, CGFloat, CGFloat) = (24, 12, 0, 0)
        for (title, detail): (CGFloat, CGFloat) in [(36, 14), (32, 14), (28, 13), (24, 12)] {
            let th = Self.measure(achievement.title, font: Self.displayFont(title))
            let dh = Self.measure(achievement.detail, font: .systemFont(ofSize: detail))
            result = (title, detail, th, dh)
            if 450 - fixed - th - dh >= 115 { break }
        }
        titleSize = result.0; detailSize = result.1
        titleHeight = result.2; detailHeight = result.3
        artworkHeight = min(180, max(100, 450 - fixed - titleHeight - detailHeight))
        // Code-defined catalog entries remain 4:5. Unusually long localized
        // copy gets a taller keepsake rather than ellipses or clipped text.
        height = max(450, fixed + artworkHeight + titleHeight + detailHeight)
    }
}

private struct AchievementSharePoster: View {
    let achievement: Achievement
    let dateLine: String
    @Environment(\.colorScheme) private var scheme
    private var metrics: AchievementShareMetrics { AchievementShareMetrics(achievement: achievement) }
    private var spooky: Bool { achievement.id.hasPrefix("spooky.") }
    private var foreground: Color { Theme.ink }
    private var accent: Color {
        if spooky { return SpookySeason.Palette.accent }
        switch achievement.category {
        case .consistency: return Theme.lagoon
        case .volume: return Theme.mint
        case .explorer: return Theme.coral
        case .dedication: return Theme.sun
        case .season, .secret: return Theme.lavender
        }
    }
    private var collection: String {
        if spooky { return "Spooky Season" }
        if achievement.id.hasPrefix("matchday.") { return "Match Day" }
        return achievement.category.displayName
    }
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                Text("Achievement unlocked")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .textCase(.uppercase)
                Text(dateLine).font(.system(size: 11))
                    .foregroundStyle(foreground.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(height: 34)
            Spacer(minLength: 12)
            AchievementShareArtwork(achievement: achievement, accent: accent)
                .frame(height: metrics.artworkHeight)
            Spacer(minLength: 12)
            Text(collection)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.3).textCase(.uppercase)
                .foregroundStyle(foreground.opacity(0.65))
                .frame(height: 14)
            Color.clear.frame(height: 8)
            Text(achievement.title)
                .font(Font(AchievementShareMetrics.displayFont(metrics.titleSize)))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: metrics.titleHeight)
            Color.clear.frame(height: 8)
            Text(achievement.detail)
                .font(.system(size: metrics.detailSize))
                .multilineTextAlignment(.center)
                .foregroundStyle(foreground.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: metrics.detailHeight)
            Spacer(minLength: 14)
            HStack(spacing: 5) {
                Image(systemName: "drop.fill").font(.system(size: 9))
                Text("Sipli").font(.system(size: 17, weight: .semibold, design: .serif))
            }
            .frame(height: 30)
            .foregroundStyle(foreground)
        }
        .foregroundStyle(foreground)
        .padding(AchievementShareMetrics.inset)
        .frame(width: 360, height: metrics.height)
        .background {
            ZStack {
                if spooky && scheme == .dark { SpookySeason.Palette.midnight } else { Theme.paper }
                RadialGradient(colors: [accent.opacity(scheme == .dark ? 0.18 : 0.10), .clear],
                               center: .init(x: 0.5, y: 0.36), startRadius: 5, endRadius: 240)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(foreground.opacity(0.10), lineWidth: 0.75)
                    .padding(12)
            }
            .frame(width: 360, height: metrics.height).clipped()
        }
    }
}

private struct AchievementShareArtwork: View {
    let achievement: Achievement
    let accent: Color
    private var spooky: Bool { achievement.id.hasPrefix("spooky.") }
    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let w = proxy.size.width
            ZStack {
                Circle().fill(accent.opacity(0.10)).frame(width: h * 0.88, height: h * 0.88)
                    .overlay { Circle().stroke(accent.opacity(0.28), lineWidth: 0.8).padding(4) }
                // Small radial marks evoke an earned seal without a generic gradient badge.
                ForEach(0..<12, id: \.self) { index in
                    Capsule().fill(accent.opacity(index.isMultiple(of: 3) ? 0.65 : 0.25))
                        .frame(width: 1.3, height: index.isMultiple(of: 3) ? 7 : 3)
                        .offset(y: -h * 0.48).rotationEffect(.degrees(Double(index) * 30))
                }
                if spooky {
                    Image(systemName: "moon.fill")
                        .font(.system(size: h * 0.41)).foregroundStyle(SpookySeason.Palette.pumpkin.opacity(0.35))
                        .offset(x: -h * 0.20, y: -h * 0.13)
                    BatShape().fill(SpookySeason.Palette.accent)
                        .frame(width: h * 0.24, height: h * 0.12).rotationEffect(.degrees(-12))
                        .offset(x: -h * 0.43, y: -h * 0.20)
                    BatShape().fill(SpookySeason.Palette.accent.opacity(0.65))
                        .frame(width: h * 0.15, height: h * 0.075).rotationEffect(.degrees(15))
                        .offset(x: h * 0.40, y: -h * 0.34)
                }
                StaticBottleArtwork(fill: 0.74, tint: spooky ? SpookySeason.Palette.potion : Theme.lagoon)
                    .frame(width: h * 0.64, height: h * 0.91)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -h * 0.025, y: h * 0.01)
                if spooky && achievement.id == "spooky.first" {
                    PumpkinView().frame(width: h * 0.27, height: h * 0.23)
                        .offset(x: h * 0.28, y: h * 0.28)
                } else {
                    Image(systemName: achievement.symbol)
                        .font(.system(size: h * 0.19, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: h * 0.34, height: h * 0.34)
                        .background(Theme.paper, in: Circle())
                        .overlay { Circle().stroke(accent.opacity(0.7), lineWidth: 1.3) }
                        .offset(x: h * 0.29, y: h * 0.25)
                }
            }
            .frame(width: w, height: h)
        }
        .accessibilityHidden(true)
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
