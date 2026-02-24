import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var locationManager: LocationManager

    var onComplete: () -> Void

    @State private var step = 0

    @State private var name = ""
    @State private var unitSystem: UnitSystem = .metric
    @State private var weight: Double = 70
    @State private var activityLevel: ActivityLevel = .steady

    @State private var customGoalEnabled = false
    @State private var customGoalValue: Double = 2200
    @State private var wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var sleepTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var remindersEnabled = true
    @State private var reminderCount = 7

    @State private var prefersWeather = true
    @State private var prefersHealthKit = true

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    private let totalSteps = 7

    var body: some View {
        ZStack {
            AppWaterBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                WaterDropProgressIndicator(currentStep: step, totalSteps: totalSteps)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    nameStep.tag(1)
                    weightStep.tag(2)
                    activityStep.tag(3)
                    goalStep.tag(4)
                    scheduleStep.tag(5)
                    remindersStep.tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 1.05))
                ))

                navigationBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
            .frame(maxWidth: isRegular ? 600 : .infinity)
        }
    }

    private var welcomeStep: some View {
        AnimatedWelcomeStep(isRegular: isRegular)
    }

    private var nameStep: some View {
        AnimatedOnboardingPage(
            title: "Let's get acquainted",
            subtitle: "What should we call you to keep things personal?",
            iconName: "person.wave.2.fill",
            iconAnimation: .wiggle,
            iconColor: Theme.lagoon
        ) {
            TextField("Your Name", text: $name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(14)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
        }
    }

    private var weightStep: some View {
        AnimatedOnboardingPage(
            title: "Tailored to your body",
            subtitle: "We use your weight and preferred units to calculate a baseline hydration goal.",
            iconName: "scalemass.fill",
            iconAnimation: .tilt,
            iconColor: Theme.lagoon
        ) {
            VStack(spacing: 24) {
                Picker("Preferred Units", selection: $unitSystem) {
                    Text("Metric").tag(UnitSystem.metric)
                    Text("Imperial").tag(UnitSystem.imperial)
                }
                .pickerStyle(.segmented)
                
                VStack(spacing: 16) {
                    HStack {
                        Text("Weight")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(weight)) \(unitSystem.bodyWeightUnit)")
                            .font(.title3.bold())
                            .foregroundStyle(Theme.lagoon)
                            .contentTransition(.numericText())
                    }

                    Slider(
                        value: $weight,
                        in: unitSystem == .metric ? 40...140 : 90...300,
                        step: unitSystem == .metric ? 1 : 2
                    )
                    .tint(Theme.lagoon)
                    .animation(.snappy, value: weight)
                }
            }
        }
    }

    private var activityStep: some View {
        AnimatedOnboardingPage(
            title: "Built for your lifestyle",
            subtitle: "More movement means more water. How active are you on an average day?",
            iconName: "figure.run",
            iconAnimation: .bounce,
            iconColor: Theme.coral
        ) {
            VStack(spacing: 16) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy) {
                            activityLevel = level
                        }
                    } label: {
                        HStack {
                            Text(level.label)
                                .font(.headline)
                            Spacer()
                            if activityLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.lagoon)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(activityLevel == level ? Theme.lagoon.opacity(0.15) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(activityLevel == level ? Theme.lagoon.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)

                Toggle("Workout Goal Adjustments", isOn: $prefersHealthKit)
                    .tint(Theme.coral)
                    .font(.headline)
                    .onChange(of: prefersHealthKit) { _, newValue in
                        Haptics.selection()
                        if newValue {
                            Task { await healthKit.requestAuthorization() }
                        }
                    }
            }
        }
    }

    private var goalStep: some View {
        AnimatedOnboardingPage(
            title: "Target your hydration",
            subtitle: "We'll suggest a dynamic goal, or you can take control and set a custom daily target.",
            iconName: "target",
            iconAnimation: .spin,
            iconColor: Theme.sun
        ) {
            VStack(spacing: 24) {
                Toggle("Set a custom daily goal", isOn: $customGoalEnabled)
                    .tint(Theme.lagoon)
                    .font(.headline)
                    .onChange(of: customGoalEnabled) { _, _ in
                        Haptics.selection()
                    }

                if customGoalEnabled {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Your Target")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(customGoalValue)) \(unitSystem.volumeUnit)")
                                .font(.title3.bold())
                                .foregroundStyle(Theme.sun)
                                .contentTransition(.numericText())
                        }

                        Slider(
                            value: $customGoalValue,
                            in: unitSystem == .metric ? 1500...4500 : 50...150,
                            step: unitSystem == .metric ? 50 : 2
                        )
                        .tint(Theme.sun)
                        .animation(.snappy, value: customGoalValue)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Divider().background(Color.white.opacity(0.1))
                    .padding(.vertical, 4)

                Toggle("Weather Goal Adjustments", isOn: $prefersWeather)
                    .tint(Theme.sun)
                    .font(.headline)
                    .onChange(of: prefersWeather) { _, newValue in
                        Haptics.selection()
                        if newValue {
                            locationManager.requestPermission()
                        }
                    }
            }
            .animation(Theme.fluidSpring, value: customGoalEnabled)
        }
    }

    private var scheduleStep: some View {
        AnimatedOnboardingPage(
            title: "Fits your day",
            subtitle: "When does your day begin and end? We'll only send reminders while you're awake.",
            iconName: "sun.and.horizon.fill",
            iconAnimation: .rise,
            iconColor: Theme.sun
        ) {
            VStack(spacing: 20) {
                DatePicker("Wake Time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    .font(.headline)
                
                Divider().background(Color.white.opacity(0.1))
                
                DatePicker("Sleep Time", selection: $sleepTime, displayedComponents: .hourAndMinute)
                    .font(.headline)
            }
            .padding(.vertical, 8)
        }
    }

    private var remindersStep: some View {
        AnimatedOnboardingPage(
            title: "Stay on track",
            subtitle: "Let us gently nudge you throughout the day so you never fall behind.",
            iconName: "bell.and.waves.left.and.right.fill",
            iconAnimation: .ring,
            iconColor: Theme.lavender
        ) {
            Toggle("Enable smart reminders", isOn: $remindersEnabled)
                .tint(Theme.lagoon)
                .font(.headline)
                .onChange(of: remindersEnabled) { _, newValue in
                    Haptics.selection()
                    if newValue {
                        Task { await notifier.requestAuthorization() }
                    }
                }
        }
    }

    private var navigationBar: some View {
        VStack(spacing: 12) {
            // Step counter
            Text("\(step + 1) of \(totalSteps)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(Theme.quickSpring, value: step)

            HStack {
                // Back button with animated fade
                Button(action: {
                    Haptics.selection()
                    withAnimation(Theme.fluidSpring) {
                        step -= 1
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                }
                .buttonStyle(BouncyButtonStyle())
                .opacity(step > 0 ? 1 : 0)
                .disabled(step == 0)
                .animation(Theme.fluidSpring, value: step)

                Spacer()

                // Continue / Start button
                Button(action: {
                    Haptics.impact(.medium)
                    if step == totalSteps - 1 {
                        finishOnboarding()
                    } else {
                        withAnimation(Theme.fluidSpring) {
                            step += 1
                        }
                    }
                }) {
                    Text(step == totalSteps - 1 ? "Start" : "Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Theme.lagoon)
                        .clipShape(Capsule())
                        .shadow(color: Theme.lagoon.opacity(0.3), radius: 8, y: 4)
                        .overlay(
                            Group {
                                if step == totalSteps - 1 {
                                    Capsule()
                                        .fill(.clear)
                                        .shimmer()
                                }
                            }
                        )
                }
                .buttonStyle(BouncyButtonStyle())
                .animation(Theme.quickSpring, value: step)
            }
        }
    }

    private func finishOnboarding() {
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightKg = unitSystem.kg(from: weight)
        let customGoalML = customGoalEnabled ? unitSystem.ml(from: customGoalValue) : nil

        store.updateProfile { profile in
            profile.name = finalName
            profile.unitSystem = unitSystem
            profile.weightKg = weightKg
            profile.activityLevel = activityLevel
            profile.customGoalML = customGoalML
            profile.remindersEnabled = remindersEnabled
            profile.wakeMinutes = minutes(from: wakeTime)
            profile.sleepMinutes = minutes(from: sleepTime)
            profile.dailyReminderCount = reminderCount
            profile.prefersWeatherGoal = prefersWeather
            profile.prefersHealthKit = prefersHealthKit
        }

        if remindersEnabled {
            notifier.scheduleReminders(profile: store.profile)
        }

        onComplete()
    }

    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.lagoon)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// Custom interactive bounce style
private struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Water Drop Progress Indicator
private struct WaterDropProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalSteps, id: \.self) { index in
                WaterDropDot(
                    state: index < currentStep ? .completed : (index == currentStep ? .current : .upcoming)
                )
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

private struct WaterDropDot: View {
    enum DropState {
        case completed, current, upcoming
    }

    let state: DropState

    @State private var isPulsing = false
    @State private var splashScale: CGFloat = 1.0
    @State private var splashOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Splash ring for completed drops
            Circle()
                .stroke(Theme.lagoon.opacity(0.4), lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .scaleEffect(splashScale)
                .opacity(splashOpacity)

            Image(systemName: "drop.fill")
                .font(.system(size: state == .current ? 16 : 12))
                .foregroundStyle(
                    state == .upcoming
                        ? Color.white.opacity(0.25)
                        : Theme.lagoon
                )
                .scaleEffect(isPulsing ? 1.15 : 1.0)
                .shadow(
                    color: state == .current ? Theme.lagoon.opacity(0.4) : .clear,
                    radius: 6
                )
        }
        .animation(Theme.quickSpring, value: state)
        .onAppear {
            if state == .current {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: state) { _, newState in
            if newState == .completed {
                splashScale = 1.0
                splashOpacity = 0.6
                withAnimation(.easeOut(duration: 0.5)) {
                    splashScale = 1.8
                    splashOpacity = 0.0
                }
            }
            if newState == .current {
                isPulsing = false
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}

// MARK: - Icon Animation Types
private enum IconAnimation {
    case pulse, wiggle, tilt, bounce, spin, rise, ring
}

// MARK: - Reusable Onboarding Page
private struct AnimatedOnboardingPage<Content: View>: View {
    let title: String
    let subtitle: String
    let iconName: String
    var iconAnimation: IconAnimation = .pulse
    var iconColor: Color = Theme.lagoon
    @ViewBuilder let content: Content

    @State private var isAnimating = false
    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showCard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 20)

                // Animated glyph with per-step animation
                ZStack {
                    // Pulse rings for spin animation
                    if iconAnimation == .spin {
                        ForEach(0..<2, id: \.self) { i in
                            Circle()
                                .stroke(iconColor.opacity(0.15), lineWidth: 1)
                                .frame(width: 140 + CGFloat(i) * 30, height: 140 + CGFloat(i) * 30)
                                .scaleEffect(isAnimating ? 1.2 : 0.9)
                                .opacity(isAnimating ? 0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 2.5)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(i) * 0.8),
                                    value: isAnimating
                                )
                        }
                    }

                    // Glow ring for rise animation
                    if iconAnimation == .rise {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [iconColor.opacity(isAnimating ? 0.25 : 0.08), .clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)
                            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isAnimating)
                    }

                    Image(systemName: iconName)
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 140, height: 140)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.8), .white.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: iconColor.opacity(0.15), radius: 24, x: 0, y: 12)
                        )
                        .modifier(IconAnimationModifier(animation: iconAnimation, isAnimating: isAnimating))
                }
                .scaleEffect(showIcon ? 1 : 0.6)
                .opacity(showIcon ? 1 : 0)

                // Copy
                VStack(spacing: 12) {
                    Text(title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .offset(y: showTitle ? 0 : 20)
                        .opacity(showTitle ? 1 : 0)

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .offset(y: showSubtitle ? 0 : 15)
                        .opacity(showSubtitle ? 1 : 0)
                }

                // Input Component
                DashboardCard(title: "") {
                    content
                }
                .padding(.horizontal, 24)
                .offset(y: showCard ? 0 : 20)
                .opacity(showCard ? 1 : 0)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                showIcon = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                showTitle = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.45)) {
                showSubtitle = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.6)) {
                showCard = true
            }
            // Start icon loop animation after entrance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// MARK: - Icon Animation Modifier
private struct IconAnimationModifier: ViewModifier {
    let animation: IconAnimation
    let isAnimating: Bool

    func body(content: Content) -> some View {
        content
            .rotationEffect(rotationAngle)
            .scaleEffect(scaleValue)
            .offset(y: yOffset)
            .animation(animationCurve, value: isAnimating)
    }

    private var rotationAngle: Angle {
        switch animation {
        case .wiggle: return .degrees(isAnimating ? 8 : -8)
        case .tilt: return .degrees(isAnimating ? 12 : -12)
        case .spin: return .degrees(isAnimating ? 360 : 0)
        case .ring: return .degrees(isAnimating ? 15 : -15)
        default: return .zero
        }
    }

    private var scaleValue: CGFloat {
        switch animation {
        case .pulse: return isAnimating ? 1.05 : 0.95
        default: return 1.0
        }
    }

    private var yOffset: CGFloat {
        switch animation {
        case .bounce: return isAnimating ? -6 : 0
        case .rise: return isAnimating ? -8 : 4
        default: return 0
        }
    }

    private var animationCurve: Animation {
        switch animation {
        case .pulse: return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        case .wiggle: return .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
        case .tilt: return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        case .bounce: return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        case .spin: return .linear(duration: 8.0).repeatForever(autoreverses: false)
        case .rise: return .easeInOut(duration: 3.0).repeatForever(autoreverses: true)
        case .ring: return .easeInOut(duration: 2.5).repeatForever(autoreverses: true)
        }
    }
}

// MARK: - Animated Welcome Step
private struct AnimatedWelcomeStep: View {
    let isRegular: Bool

    @State private var appearStep1 = false // Logo
    @State private var appearStep2 = false // Title
    @State private var appearStep3 = false // Features Box
    @State private var appearStep4 = false // Row 1
    @State private var appearStep5 = false // Row 2
    @State private var appearStep6 = false // Row 3

    var body: some View {
        ScrollView {
            VStack(spacing: isRegular ? 32 : 24) {
                Spacer(minLength: isRegular ? 50 : 30)

                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isRegular ? 180 : 140, height: isRegular ? 180 : 140)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.8), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: Theme.lagoon.opacity(0.15), radius: 24, x: 0, y: 12)
                    )
                    .scaleEffect(appearStep1 ? 1 : 0.6)
                    .opacity(appearStep1 ? 1 : 0)

                VStack(spacing: isRegular ? 14 : 10) {
                    Text("Welcome to Thirsty.ai")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("Build a hydration routine with smart goals, simple logging, and daily momentum.")
                        .font(isRegular ? .title3 : .body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }
                .offset(y: appearStep2 ? 0 : 20)
                .opacity(appearStep2 ? 1 : 0)

                VStack(alignment: .leading, spacing: 12) {
                    OnboardingFeatureRow(icon: "target", text: "Personal goals based on your profile")
                        .opacity(appearStep4 ? 1 : 0)
                        .offset(x: appearStep4 ? 0 : -20)
                    
                    OnboardingFeatureRow(icon: "bell.fill", text: "Reminders scheduled around your day")
                        .opacity(appearStep5 ? 1 : 0)
                        .offset(x: appearStep5 ? 0 : -20)
                    
                    OnboardingFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Progress insights and streak tracking")
                        .opacity(appearStep6 ? 1 : 0)
                        .offset(x: appearStep6 ? 0 : -20)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.glassBorder, lineWidth: 1)
                )
                .offset(y: appearStep3 ? 0 : 20)
                .opacity(appearStep3 ? 1 : 0)

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                appearStep1 = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                appearStep2 = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5)) {
                appearStep3 = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.8)) {
                appearStep4 = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(1.0)) {
                appearStep5 = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(1.2)) {
                appearStep6 = true
            }
        }
    }
}

#Preview("Onboarding") {
    PreviewEnvironment {
        OnboardingView { }
    }
}
