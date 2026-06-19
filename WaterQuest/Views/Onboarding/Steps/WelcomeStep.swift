import SwiftUI

struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            welcomeText
                .padding(.horizontal, 24)

            Spacer(minLength: 8)

            SipliCTA(title: "Get started", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var welcomeText: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SipliMark(size: 24)
                Text("SIPLI")
                    .font(.sipliMono(12, weight: .semibold, relativeTo: .caption))
                    .tracking(1.6)
                    .foregroundStyle(OnboardingPalette.ink)
            }

            (Text("Drink water\nlike you ").foregroundStyle(OnboardingPalette.ink)
            + Text("mean it.").italic().foregroundStyle(OnboardingPalette.water))
                .font(.editorialSerif(46, relativeTo: .largeTitle))
                .lineSpacing(-2)

            Text("A hydration habit that actually fits in your life. No streaks to lose sleep over.")
                .font(.system(size: 15))
                .foregroundStyle(OnboardingPalette.ink3)
                .lineSpacing(2)
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("WelcomeStep") {
    WelcomeStep(onContinue: {})
        .background(OnboardingPalette.paper)
}
#endif
