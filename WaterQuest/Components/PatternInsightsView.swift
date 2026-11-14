import SwiftUI

/// One pattern observation: symbol, fact headline and the detail behind it.
struct PatternInsightRow: View {
    let insight: PatternInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.lagoon)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("patternInsight.\(insight.id)")
    }
}

/// Display model for an AI coach note built from pattern facts.
struct CoachTake: Equatable {
    var headline: String
    var message: String
    var nextStep: String?
}

/// The coach note (AI when available, otherwise the top pattern) followed by
/// the remaining patterns. Shown on Insights without the user having to ask.
struct PatternInsightsSection: View {
    let patterns: HydrationPatterns
    let take: CoachTake?
    var maxRows = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let take {
                VStack(alignment: .leading, spacing: 6) {
                    Text(take.headline)
                        .font(Theme.editorialSerif(20, weight: .semibold, relativeTo: .title3))
                        .foregroundStyle(Theme.ink)
                    Text(take.message)
                        .font(.subheadline)
                    if let nextStep = take.nextStep, !nextStep.isEmpty {
                        Label(nextStep, systemImage: "arrow.forward.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.lagoon)
                    }
                }
                .accessibilityIdentifier("coachTake")
            }
            if patterns.insights.isEmpty {
                Text("Log a few more days and your patterns will show up here: your quiet hours, your usual pace and what you drink most.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(patterns.insights.prefix(maxRows)) { insight in
                    PatternInsightRow(insight: insight)
                }
            }
        }
    }
}

/// Home coach card: the living bottle check-in plus the top pattern.
struct CoachCardContent: View {
    let topPattern: PatternInsight?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LivingInsightCard()
            if let topPattern {
                Divider()
                PatternInsightRow(insight: topPattern)
            }
        }
    }
}
