import SwiftUI

// MARK: - Ripple Effect (Metal)
@available(iOS 17.0, *)
private struct RippleModifier: ViewModifier {
    let origin: CGPoint
    let elapsedTime: TimeInterval
    let duration: TimeInterval
    let amplitude: CGFloat
    let frequency: CGFloat
    let decay: CGFloat
    let speed: CGFloat
    let edgeReflectionStrength: CGFloat
    let cornerReflectionStrength: CGFloat
    let reflectionRamp: CGFloat

    func body(content: Content) -> some View {
        content
            .visualEffect { view, proxy in
                let size = proxy.size
                let width = size.width
                let height = size.height
                let maxRadius = max(width, height)
                let radius = speed * CGFloat(elapsedTime)
                let isActive = elapsedTime > 0 && elapsedTime < duration

                func intensity(for distance: CGFloat, strength: CGFloat) -> CGFloat {
                    let overlap = radius - distance
                    guard overlap > 0 else { return 0 }
                    let ramp = max(1, maxRadius * reflectionRamp)
                    return min(1, overlap / ramp) * strength
                }

                func shader(at position: CGPoint, intensity: CGFloat) -> Shader {
                    ShaderLibrary.Ripple(
                        .float2(position),
                        .float(elapsedTime),
                        .float(amplitude * intensity),
                        .float(frequency),
                        .float(decay),
                        .float(speed)
                    )
                }

                let leftDistance = origin.x
                let rightDistance = width - origin.x
                let topDistance = origin.y
                let bottomDistance = height - origin.y

                let topLeftDistance = hypot(origin.x, origin.y)
                let topRightDistance = hypot(rightDistance, origin.y)
                let bottomLeftDistance = hypot(origin.x, bottomDistance)
                let bottomRightDistance = hypot(rightDistance, bottomDistance)

                let leftIntensity = intensity(for: leftDistance, strength: edgeReflectionStrength)
                let rightIntensity = intensity(for: rightDistance, strength: edgeReflectionStrength)
                let topIntensity = intensity(for: topDistance, strength: edgeReflectionStrength)
                let bottomIntensity = intensity(for: bottomDistance, strength: edgeReflectionStrength)

                let topLeftIntensity = intensity(for: topLeftDistance, strength: cornerReflectionStrength)
                let topRightIntensity = intensity(for: topRightDistance, strength: cornerReflectionStrength)
                let bottomLeftIntensity = intensity(for: bottomLeftDistance, strength: cornerReflectionStrength)
                let bottomRightIntensity = intensity(for: bottomRightDistance, strength: cornerReflectionStrength)

                return view
                    .layerEffect(
                        shader(at: origin, intensity: 1),
                        maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                        isEnabled: isActive
                    )
                    .layerEffect(
                        shader(at: CGPoint(x: -origin.x, y: origin.y), intensity: leftIntensity),
                        maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                        isEnabled: isActive && leftIntensity > 0
                    )
                    .layerEffect(
                        shader(at: CGPoint(x: width + rightDistance, y: origin.y), intensity: rightIntensity),
                        maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                        isEnabled: isActive && rightIntensity > 0
                    )
                    .layerEffect(
                        shader(at: CGPoint(x: origin.x, y: -origin.y), intensity: topIntensity),
                        maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                        isEnabled: isActive && topIntensity > 0
                    )
                    .layerEffect(
                        shader(at: CGPoint(x: origin.x, y: height + bottomDistance), intensity: bottomIntensity),
                        maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                        isEnabled: isActive && bottomIntensity > 0
                    )
                    .layerEffect(
                        shader(at: CGPoint(x: -origin.x, y: -origin.y), intensity: topLeftIntensity),
                        maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                        isEnabled: isActive && topLeftIntensity > 0
                    )
                    .layerEffect(
                        shader(at: CGPoint(x: width + rightDistance, y: -origin.y), intensity: topRightIntensity),
                        maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                        isEnabled: isActive && topRightIntensity > 0
                    )
                    .layerEffect(
                        shader(at: CGPoint(x: -origin.x, y: height + bottomDistance), intensity: bottomLeftIntensity),
                        maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                        isEnabled: isActive && bottomLeftIntensity > 0
                    )
                    .layerEffect(
                        shader(at: CGPoint(x: width + rightDistance, y: height + bottomDistance), intensity: bottomRightIntensity),
                        maxSampleOffset: CGSize(width: amplitude, height: amplitude),
                        isEnabled: isActive && bottomRightIntensity > 0
                    )
            }
    }

}

@available(iOS 17.0, *)
private struct RippleEffect<T: Equatable>: ViewModifier {
    var origin: CGPoint
    var trigger: T
    var amplitude: CGFloat = 10
    var frequency: CGFloat = 14
    var decay: CGFloat = 6
    var speed: CGFloat = 1200
    var duration: TimeInterval = 2.2
    var edgeReflectionStrength: CGFloat = 0.55
    var cornerReflectionStrength: CGFloat = 0.35
    var reflectionRamp: CGFloat = 0.28

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, elapsedTime in
                view.modifier(
                    RippleModifier(
                        origin: origin,
                        elapsedTime: elapsedTime,
                        duration: duration,
                        amplitude: amplitude,
                        frequency: frequency,
                        decay: decay,
                        speed: speed,
                        edgeReflectionStrength: edgeReflectionStrength,
                        cornerReflectionStrength: cornerReflectionStrength,
                        reflectionRamp: reflectionRamp
                    )
                )
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(duration, duration: duration)
            }
    }
}

@available(iOS 17.0, *)
private extension View {
    func rippleEffect<T: Equatable>(
        origin: CGPoint,
        trigger: T,
        amplitude: CGFloat = 10,
        frequency: CGFloat = 14,
        decay: CGFloat = 6,
        speed: CGFloat = 1200,
        duration: TimeInterval = 2.2,
        edgeReflectionStrength: CGFloat = 0.55,
        cornerReflectionStrength: CGFloat = 0.35,
        reflectionRamp: CGFloat = 0.28
    ) -> some View {
        modifier(
            RippleEffect(
                origin: origin,
                trigger: trigger,
                amplitude: amplitude,
                frequency: frequency,
                decay: decay,
                speed: speed,
                duration: duration,
                edgeReflectionStrength: edgeReflectionStrength,
                cornerReflectionStrength: cornerReflectionStrength,
                reflectionRamp: reflectionRamp
            )
        )
    }
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @EnvironmentObject private var store: HydrationStore
    @State private var showSplash = true

    var body: some View {
        content
            .task {
                guard showSplash else { return }
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeOut(duration: 0.35)) {
                    showSplash = false
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            if hasOnboarded {
                MainTabView()
            } else {
                OnboardingView {
                    hasOnboarded = true
                }
            }

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(20)
            }

            if let achievement = store.activeAchievement {
                AchievementCelebrationView(achievement: achievement) {
                    store.dismissActiveAchievement()
                }
                .id(achievement.id)
                .transition(AnyTransition.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: store.activeAchievement)
    }
}
