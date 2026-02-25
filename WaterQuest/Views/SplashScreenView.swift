import SwiftUI

struct SplashScreenView: View {
    @State private var pulse = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            AppWaterBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: isRegular ? 180 : 120)

                ZStack {
                    Circle()
                        .stroke(Theme.lagoon.opacity(0.22), lineWidth: 1.4)
                        .frame(width: isRegular ? 240 : 176, height: isRegular ? 240 : 176)
                        .scaleEffect(pulse ? 1.04 : 0.9)
                        .opacity(pulse ? 0.9 : 0.45)

                    Circle()
                        .stroke(Theme.mint.opacity(0.18), lineWidth: 1)
                        .frame(width: isRegular ? 180 : 132, height: isRegular ? 180 : 132)
                        .scaleEffect(pulse ? 0.98 : 1.08)
                        .opacity(0.9)

                    Circle()
                        .fill(Theme.lagoon.opacity(0.14))
                        .frame(width: isRegular ? 152 : 112, height: isRegular ? 152 : 112)
                        .blur(radius: 0.2)

                    Image("Mascot")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isRegular ? 112 : 84, height: isRegular ? 112 : 84)
                        .shadow(color: Theme.lagoon.opacity(0.35), radius: 16, x: 0, y: 6)
                        .accessibilityHidden(true)
                }
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

                VStack(spacing: isRegular ? 12 : 8) {
                    Text("Sipli")
                        .font(.system(isRegular ? .largeTitle : .title, design: .rounded).weight(.bold))
                        .kerning(0.3)
                    Text("Hydration that fits your day")
                        .font(isRegular ? .title3.weight(.medium) : .subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, isRegular ? 36 : 26)

                Spacer()

                VStack(spacing: 10) {
                    ProgressView()
                        .tint(Theme.lagoon)
                        .controlSize(.regular)
                    Text("Getting things ready...")
                        .font(isRegular ? .subheadline : .footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, isRegular ? 72 : 56)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
        }
    }
}

#if DEBUG
#Preview("Splash") {
    PreviewEnvironment {
        SplashScreenView()
    }
}
#endif
