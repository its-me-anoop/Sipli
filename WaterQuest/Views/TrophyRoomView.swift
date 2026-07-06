import SwiftUI

/// The badge collection screen. Each category gets its own visual treatment —
/// a milestone path for streaks, editorial rows for volume, a chip cloud for
/// secrets — so the room reads as a curated cabinet, not a settings grid.
struct TrophyRoomView: View {
    @EnvironmentObject private var store: HydrationStore
    /// Cached share card for the latest unlock — rendered once per unlock,
    /// not on every body evaluation.
    @State private var heroSharePayload: ShareCardPayload?

    private var unlocked: [String: Date] { store.unlockedAchievements }

    private var earnedCount: Int {
        AchievementCatalog.all.filter { unlocked[$0.id] != nil }.count
    }

    /// Most recently earned badge, for the hero slot.
    private var latestUnlock: (Achievement, Date)? {
        unlocked
            .compactMap { id, date in AchievementCatalog.byID[id].map { ($0, date) } }
            .max { $0.1 < $1.1 }
    }

    private func achievements(in category: AchievementCategory) -> [Achievement] {
        AchievementCatalog.all.filter { $0.category == category }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if let (latest, date) = latestUnlock {
                    latestUnlockHero(latest, date: date)
                }

                streakPath

                categoryRows(.volume, accent: Theme.mint)
                categoryRows(.explorer, accent: Theme.coral)
                categoryRows(.dedication, accent: Theme.sun)
                categoryRows(.season, accent: Theme.lavender)

                secretShelf
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background { AppWaterBackground().ignoresSafeArea() }
        .navigationTitle("Trophy Room")
        .navigationBarTitleDisplayMode(.large)
        .task(id: latestUnlock?.0.id) {
            guard let (latest, date) = latestUnlock else { return }
            heroSharePayload = ShareCardRenderer.render(.achievement(latest, earnedOn: date))
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                // The droplet evolves with the streak (aura at 7, sparkles at
                // 30, crown at 100) — the Trophy Room is where it shows off.
                MascotView(size: 56, animated: true, streak: store.currentStreak)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.currentStreak > 0 ? "\(store.currentStreak)-day streak" : "Every sip counts")
                        .font(Theme.editorialSerif(22, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Theme.ink)
                    Text(streakTierLine)
                        .font(Theme.captionFont())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.bottom, 8)

            Text("\(earnedCount) of \(AchievementCatalog.all.count) earned")
                .font(Theme.sipliMono(12, weight: .semibold, relativeTo: .caption))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.lagoon.opacity(0.12))
                    Capsule()
                        .fill(Theme.glowGradient)
                        .frame(width: geo.size.width * CGFloat(earnedCount) / CGFloat(max(1, AchievementCatalog.all.count)))
                }
            }
            .frame(height: 6)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(earnedCount) of \(AchievementCatalog.all.count) achievements earned")
    }

    /// What the droplet's current tier means, and what comes next.
    private var streakTierLine: String {
        let streak = store.currentStreak
        switch streak {
        case ..<7: return "Reach a 7-day streak to give your droplet an aura"
        case ..<30: return "Aura earned — sparkles arrive at a 30-day streak"
        case ..<100: return "Sparkles earned — the crown waits at 100 days"
        default: return "Crowned. Your droplet has seen things."
        }
    }

    // MARK: Latest unlock hero

    private func latestUnlockHero(_ achievement: Achievement, date: Date) -> some View {
        HStack(spacing: 18) {
            badgeMedallion(achievement, earned: true, accent: Theme.lagoon, size: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("Latest")
                    .font(Theme.sipliMono(10, weight: .semibold, relativeTo: .caption2))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textSecondary)
                Text(achievement.title)
                    .font(Theme.editorialSerif(24, weight: .semibold, relativeTo: .title2))
                    .foregroundStyle(Theme.ink)
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.captionFont())
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            if let payload = heroSharePayload {
                ShareLink(
                    item: payload,
                    message: Text(payload.caption),
                    preview: SharePreview(achievement.title, image: Image(systemName: achievement.symbol))
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.lagoon)
                        .padding(10)
                }
                .accessibilityLabel("Share \(achievement.title)")
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.summaryCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Theme.glassBorder, lineWidth: 1)
                )
        }
    }

    // MARK: Consistency — milestone path

    private var streakPath: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Consistency", accent: Theme.lagoon)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    let badges = achievements(in: .consistency)
                    ForEach(Array(badges.enumerated()), id: \.element.id) { index, achievement in
                        let earned = unlocked[achievement.id] != nil
                        HStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(earned ? Theme.lagoon.opacity(0.5) : Theme.glassBorder)
                                    .frame(width: 26, height: 2)
                            }
                            VStack(spacing: 6) {
                                badgeMedallion(achievement, earned: earned, accent: Theme.lagoon, size: 54)
                                Text(achievement.title)
                                    .font(Theme.captionFont(.caption2))
                                    .foregroundStyle(earned ? Theme.ink : Theme.textTertiary)
                                    .lineLimit(1)
                            }
                            .frame(width: 84)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(badgeAccessibilityLabel(achievement, earned: earned))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Standard category rows

    private func categoryRows(_ category: AchievementCategory, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(category.displayName, accent: accent)

            VStack(spacing: 0) {
                let badges = achievements(in: category)
                ForEach(Array(badges.enumerated()), id: \.element.id) { index, achievement in
                    let earned = unlocked[achievement.id] != nil
                    HStack(spacing: 14) {
                        badgeMedallion(achievement, earned: earned, accent: accent, size: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(achievement.title)
                                .font(Theme.titleFont(.subheadline))
                                .foregroundStyle(earned ? Theme.ink : Theme.textSecondary)
                            Text(achievement.detail)
                                .font(Theme.captionFont())
                                .foregroundStyle(Theme.textTertiary)
                        }

                        Spacer(minLength: 0)

                        if let date = unlocked[achievement.id] {
                            Text(date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(Theme.sipliMono(10, relativeTo: .caption2))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .padding(.vertical, 10)
                    .opacity(earned ? 1 : 0.75)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(badgeAccessibilityLabel(achievement, earned: earned))

                    if index < badges.count - 1 {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
    }

    // MARK: Secret shelf

    private var secretShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Secret", accent: Theme.ink)
            Text("Found by doing, not by looking.")
                .font(Theme.captionFont())
                .foregroundStyle(Theme.textTertiary)

            FlowChips(items: achievements(in: .secret)) { achievement in
                let earned = unlocked[achievement.id] != nil
                HStack(spacing: 8) {
                    Image(systemName: earned ? achievement.symbol : "questionmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(earned ? Color.white : Theme.textTertiary)
                        .frame(width: 26, height: 26)
                        .background {
                            Circle().fill(earned ? AnyShapeStyle(Theme.glowGradient) : AnyShapeStyle(Theme.glassAccent))
                        }
                    Text(earned ? achievement.title : "???")
                        .font(Theme.sipliMono(12, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(earned ? Theme.ink : Theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(Theme.cardSurface)
                        .overlay(Capsule().stroke(Theme.glassBorder, lineWidth: 1))
                }
                .accessibilityLabel(earned ? badgeAccessibilityLabel(achievement, earned: true) : "Secret achievement, not yet earned")
            }
        }
    }

    // MARK: Pieces

    private func sectionTitle(_ title: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(accent).frame(width: 7, height: 7)
            Text(title)
                .font(Theme.editorialSerif(20, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(Theme.ink)
        }
    }

    private func badgeMedallion(_ achievement: Achievement, earned: Bool, accent: Color, size: CGFloat) -> some View {
        ZStack {
            if earned {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 4)
                Image(systemName: achievement.symbol)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(Theme.glassBorder, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                Image(systemName: achievement.isSecret ? "questionmark" : achievement.symbol)
                    .font(.system(size: size * 0.36, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: size, height: size)
    }

    private func badgeAccessibilityLabel(_ achievement: Achievement, earned: Bool) -> String {
        earned
            ? "\(achievement.title), earned. \(achievement.detail)"
            : "\(achievement.title), locked. \(achievement.detail)"
    }
}

/// Minimal left-aligned wrapping chip layout for the secret shelf.
private struct FlowChips<Item: Identifiable, Chip: View>: View {
    let items: [Item]
    @ViewBuilder let chip: (Item) -> Chip

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                chip(item)
            }
        }
    }
}

/// Simple flow layout (iOS 16+ `Layout`) — wraps chips onto new lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let extra = current.indices.isEmpty ? size.width : size.width + spacing
            if current.width + extra > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.indices.append(index)
            current.width += current.indices.count == 1 ? size.width : size.width + spacing
            current.height = max(current.height, size.height)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#if DEBUG
#Preview("Trophy Room") {
    PreviewEnvironment {
        NavigationStack {
            TrophyRoomView()
        }
    }
}
#endif
