import SwiftUI

struct ActivityStep: View {
    @Binding var state: OnboardingState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let answers: [OnboardingAnswerChip]
    let onContinue: () -> Void
    let onBack: () -> Void

    private var hasHealthKitPremium: Bool {
        subscriptionManager.hasAccess(to: .healthKitSync)
    }

    private struct Option: Identifiable {
        let id: ActivityLevel
        let label: String
        let sub: String
        let emoji: String
        let color: Color
        let mult: String
    }

    private let options: [Option] = [
        Option(id: .chill, label: "Chill", sub: "Mostly desk life", emoji: "🌿", color: OnboardingPalette.mint, mult: "+0%"),
        Option(id: .steady, label: "Steady", sub: "A walk, some movement", emoji: "🚶", color: OnboardingPalette.sun, mult: "+10%"),
        Option(id: .intense, label: "Intense", sub: "Sweat most days", emoji: "🔥", color: OnboardingPalette.coral, mult: "+25%")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AnswerChipStack(chips: answers)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    headline
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(options) { opt in
                            optionCard(opt)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)

                    healthRow
                        .padding(.horizontal, 24)
                        .padding(.bottom, 18)
                }
            }

            VStack {
                SipliCTA(title: "Continue", action: onContinue)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .padding(.top, 12)
        }
    }

    private var headline: some View {
        (Text("How active\n").foregroundStyle(OnboardingPalette.ink)
            + Text("is your average day?").italic().foregroundStyle(OnboardingPalette.water))
            .font(.editorialSerif(40, relativeTo: .largeTitle))
            .lineSpacing(-2)
    }

    private func optionCard(_ opt: Option) -> some View {
        let isSelected = state.activityLevel == opt.id
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                state.activityLevel = opt.id
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(opt.color)
                        .frame(width: 52, height: 52)
                    Text(opt.emoji)
                        .font(.system(size: 26))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(opt.label)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.ink)
                    Text(opt.sub)
                        .font(.system(size: 13))
                        .foregroundStyle(OnboardingPalette.ink3)
                }

                Spacer(minLength: 4)

                Text(opt.mult)
                    .font(.sipliMono(12, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(isSelected ? OnboardingPalette.ink : OnboardingPalette.ink3)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? opt.color : OnboardingPalette.ink.opacity(0.05))
                    )
            }
            .padding(16)
            .padding(.leading, isSelected ? 4 : 16) // make room for the side stripe
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(OnboardingPalette.paper)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(OnboardingPalette.ink))
                        .padding(14)
                }
            }
            .background(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                    if isSelected {
                        Rectangle()
                            .fill(opt.color)
                            .frame(width: 4)
                            .padding(.vertical, 16)
                            .padding(.leading, 0)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? OnboardingPalette.ink : Color.clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? OnboardingPalette.ink.opacity(0.20) : .clear, radius: 14, x: 0, y: 8)
            .scaleEffect(isSelected ? 1.0 : 1.0)
            .offset(y: isSelected ? -1 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var healthRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(OnboardingPalette.coral)
                    .frame(width: 36, height: 36)
                Image(systemName: "heart.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Sync with Apple Health")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                Text("Auto-bump goal on workout days")
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.ink3)
            }
            Spacer()
            PremiumGatedToggle(
                isOn: $state.prefersHealthKit,
                isPremium: hasHealthKitPremium,
                onPaywall: {
                    Haptics.selection()
                    subscriptionManager.presentPaywall(for: .healthKitSync)
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            // Whole-row tap target opens the paywall when locked, mirroring
            // the kit-card pattern from the design.
            if !hasHealthKitPremium {
                Haptics.selection()
                subscriptionManager.presentPaywall(for: .healthKitSync)
            }
        }
        .accessibilityHint(hasHealthKitPremium ? "" : "Premium feature. Opens upgrade screen.")
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnboardingPalette.coral.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingPalette.coral.opacity(0.20), lineWidth: 1.5)
        )
    }
}
