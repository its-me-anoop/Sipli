import SwiftUI

struct SplashScreenView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Theme.lagoon.opacity(0.2))
                        .frame(width: 128, height: 128)
                        .scaleEffect(isPulsing ? 1.05 : 0.95)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulsing)

                    MascotView()
                        .scaleEffect(0.9)
                }

                Text("WaterQuest")
                    .font(Theme.titleFont(size: 34))
                    .foregroundColor(.white)

                Text("Hydrate. Level up.")
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(.white.opacity(0.6))

                ProgressView()
                    .tint(Theme.mint)
                    .scaleEffect(1.1)
            }
            .padding(.bottom, 40)

            VStack {
                Spacer()
                WaveView()
                    .frame(height: 180)
                    .opacity(0.7)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            isPulsing = true
        }
    }
}

#Preview("Splash Screen") {
    PreviewEnvironment {
        SplashScreenView()
    }
}
