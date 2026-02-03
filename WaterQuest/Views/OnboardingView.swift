import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var locationManager: LocationManager

    var onComplete: () -> Void

    @State private var pageIndex = 0
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
    
    // Animation states
    @State private var appeared = false
    @State private var contentOffset: CGFloat = 50

    var body: some View {
        ZStack(alignment: .top) {
            // Animated gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page indicator
                pageIndicator
                    .padding(.top, 16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)
                
                // Content
                TabView(selection: $pageIndex) {
                    introPage.tag(0)
                    profilePage.tag(1)
                    schedulePage.tag(2)
                    permissionsPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: pageIndex) { _, newValue in
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        contentOffset = 0
                    }
                }

                // Navigation buttons
                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2)) {
                appeared = true
                contentOffset = 0
            }
        }
    }
    
    // MARK: - Page Indicator
    @ViewBuilder
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == pageIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == pageIndex ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: pageIndex)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .modifier(GlassBackgroundModifier(cornerRadius: 20))
    }
    
    // MARK: - Navigation Buttons
    @ViewBuilder
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if pageIndex > 0 {
                Button {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        pageIndex -= 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(Theme.bodyFont(size: 16))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .modifier(GlassButtonModifier())
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }

            Button {
                if pageIndex == 3 {
                    Haptics.success()
                    finishOnboarding()
                } else {
                    Haptics.impact(.medium)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        pageIndex += 1
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(pageIndex == 3 ? "Start Quest" : "Next")
                        .font(Theme.titleFont(size: 16))
                    if pageIndex < 3 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            }
            .modifier(GlassButtonModifier(tint: Theme.lagoon))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: pageIndex)
    }

    // MARK: - Intro Page
    private var introPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Enhanced mascot with glass backdrop
            ZStack {
                // Glass backdrop circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 160, height: 160)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Theme.lagoon.opacity(0.3), radius: 30, x: 0, y: 10)
                
                EnhancedMascotView()
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)
            
            VStack(spacing: 12) {
                Text("WaterQuest")
                    .font(Theme.titleFont(size: 38))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Theme.mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Theme.lagoon.opacity(0.5), radius: 10, x: 0, y: 4)
                
                Text("A playful hydration adventure with quests, streaks, and smart goals that adapt to your day.")
                    .font(Theme.bodyFont(size: 17))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .offset(y: appeared ? 0 : 30)
            .opacity(appeared ? 1 : 0)
            
            // Feature pills
            HStack(spacing: 12) {
                FeaturePill(icon: "flame.fill", text: "Streaks", color: Theme.coral)
                FeaturePill(icon: "target", text: "Quests", color: Theme.lagoon)
                FeaturePill(icon: "chart.line.uptrend.xyaxis", text: "Insights", color: Theme.mint)
            }
            .padding(.top, 8)
            .offset(y: appeared ? 0 : 40)
            .opacity(appeared ? 1 : 0)
            
            Spacer()
            Spacer()
        }
        .padding(.top, 20)
    }

    // MARK: - Profile Page
    private var profilePage: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeader(
                    icon: "person.crop.circle.fill",
                    title: "Build Your Profile",
                    subtitle: "Let's personalize your hydration journey"
                )

                VStack(spacing: 16) {
                    GlassTextField(
                        title: "What should we call you?",
                        placeholder: "Your name",
                        text: $name
                    )

                    GlassSegmentedPicker(
                        title: "Preferred Units",
                        selection: $unitSystem,
                        options: UnitSystem.allCases
                    ) { unit in
                        Text(unit == .metric ? "Metric" : "Imperial")
                    }

                    GlassSlider(
                        title: "Your Weight",
                        value: $weight,
                        range: unitSystem == .metric ? 40...140 : 90...300,
                        step: unitSystem == .metric ? 1 : 2,
                        unit: unitSystem.bodyWeightUnit
                    )

                    GlassSegmentedPicker(
                        title: "Activity Level",
                        selection: $activityLevel,
                        options: ActivityLevel.allCases
                    ) { level in
                        Text(level.label)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Schedule Page
    private var schedulePage: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeader(
                    icon: "clock.fill",
                    title: "Daily Rhythm",
                    subtitle: "Set up your hydration schedule"
                )

                VStack(spacing: 16) {
                    GlassToggle(
                        title: "Custom Daily Goal",
                        subtitle: "Set your own target instead of calculated",
                        isOn: $customGoalEnabled,
                        tint: Theme.mint
                    )

                    if customGoalEnabled {
                        GlassSlider(
                            title: "Daily Goal",
                            value: $customGoalValue,
                            range: unitSystem == .metric ? 1500...4500 : 50...150,
                            step: unitSystem == .metric ? 50 : 2,
                            unit: unitSystem.volumeUnit
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                        ))
                    }

                    HStack(spacing: 12) {
                        GlassTimePicker(title: "Wake Up", icon: "sunrise.fill", date: $wakeTime, tint: Theme.sun)
                        GlassTimePicker(title: "Sleep", icon: "moon.stars.fill", date: $sleepTime, tint: Theme.lagoon)
                    }

                    GlassToggle(
                        title: "Smart Reminders",
                        subtitle: "Get notified throughout the day",
                        isOn: $remindersEnabled,
                        tint: Theme.lagoon
                    )

                    if remindersEnabled {
                        GlassStepper(
                            title: "Reminders per Day",
                            value: $reminderCount,
                            range: 3...12
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: customGoalEnabled)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: remindersEnabled)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Permissions Page
    private var permissionsPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                PageHeader(
                    icon: "bolt.fill",
                    title: "Power-Ups",
                    subtitle: "Enable features to enhance your experience"
                )

                VStack(spacing: 16) {
                    GlassToggle(
                        title: "Weather Integration",
                        subtitle: "Adjust goals based on temperature",
                        isOn: $prefersWeather,
                        tint: Theme.sun
                    )

                    GlassToggle(
                        title: "Health Sync",
                        subtitle: "Connect workouts and water intake",
                        isOn: $prefersHealthKit,
                        tint: Theme.mint
                    )

                    VStack(spacing: 12) {
                        PermissionButton(
                            title: "Health & Activity",
                            icon: "heart.fill",
                            color: .pink
                        ) {
                            Haptics.impact(.medium)
                            Task { await healthKit.requestAuthorization() }
                        }

                        PermissionButton(
                            title: "Location",
                            icon: "location.fill",
                            color: Theme.lagoon
                        ) {
                            Haptics.impact(.medium)
                            locationManager.requestPermission()
                        }

                        PermissionButton(
                            title: "Notifications",
                            icon: "bell.fill",
                            color: Theme.coral
                        ) {
                            Haptics.impact(.medium)
                            Task { await notifier.requestAuthorization() }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Helpers
    private func finishOnboarding() {
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightKg = unitSystem.kg(from: weight)
        let customGoalML = customGoalEnabled ? unitSystem.ml(from: customGoalValue) : nil
        let wakeMinutes = minutes(from: wakeTime)
        let sleepMinutes = minutes(from: sleepTime)

        store.updateProfile { profile in
            profile.name = finalName
            profile.unitSystem = unitSystem
            profile.weightKg = weightKg
            profile.activityLevel = activityLevel
            profile.customGoalML = customGoalML
            profile.remindersEnabled = remindersEnabled
            profile.wakeMinutes = wakeMinutes
            profile.sleepMinutes = sleepMinutes
            profile.dailyReminderCount = reminderCount
            profile.prefersWeatherGoal = prefersWeather
            profile.prefersHealthKit = prefersHealthKit
        }

        if remindersEnabled {
            notifier.scheduleReminders(profile: store.profile)
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            onComplete()
        }
    }

    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

// MARK: - Glass Background Modifier (iOS 26+ Liquid Glass, fallback for older)
struct GlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tint: Color? = nil
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    tint.map { .regular.tint($0) } ?? .regular,
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Glass Button Modifier
struct GlassButtonModifier: ViewModifier {
    var tint: Color? = nil
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    tint.map { .regular.tint($0).interactive() } ?? .regular.interactive(),
                    in: .capsule
                )
        } else {
            content
                .background(
                    Capsule()
                        .fill(tint?.opacity(0.3) ?? Color.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: (tint ?? Theme.lagoon).opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Glass Circle Modifier
struct GlassCircleModifier: ViewModifier {
    var tint: Color? = nil
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    tint.map { .regular.tint($0).interactive() } ?? .regular.interactive(),
                    in: .circle
                )
        } else {
            content
                .background(
                    Circle()
                        .fill(tint?.opacity(0.3) ?? Color.white.opacity(0.15))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Animated Gradient Background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.deepSea, Theme.night],
                startPoint: animateGradient ? .topLeading : .top,
                endPoint: animateGradient ? .bottomTrailing : .bottom
            )
            
            // Floating orbs
            Circle()
                .fill(Theme.lagoon.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animateGradient ? 100 : -100, y: animateGradient ? -150 : -100)
            
            Circle()
                .fill(Theme.mint.opacity(0.1))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: animateGradient ? -80 : 80, y: animateGradient ? 200 : 150)
            
            Circle()
                .fill(Theme.coral.opacity(0.08))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(x: animateGradient ? 50 : -50, y: animateGradient ? 50 : 100)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

// MARK: - Page Header
struct PageHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.lagoon, Theme.mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Theme.lagoon.opacity(0.4), radius: 8, x: 0, y: 4)
            
            Text(title)
                .font(Theme.titleFont(size: 28))
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(Theme.bodyFont(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Feature Pill
struct FeaturePill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(Theme.bodyFont(size: 13))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .modifier(GlassButtonModifier(tint: color))
    }
}

// MARK: - Enhanced Mascot View
struct EnhancedMascotView: View {
    @State private var bounce = false
    @State private var shimmer = false
    
    var body: some View {
        ZStack {
            // Shimmer effect
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.lagoon, Theme.mint, Theme.lagoon],
                        startPoint: shimmer ? .topLeading : .bottomTrailing,
                        endPoint: shimmer ? .bottomTrailing : .topLeading
                    )
                )
                .shadow(color: Theme.lagoon.opacity(0.5), radius: 16, x: 0, y: 8)

            // Face
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Eye()
                    Eye()
                }
                
                // Smile
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 20, height: 6)
            }
            .offset(y: 10)
        }
        .frame(width: 90, height: 110)
        .scaleEffect(bounce ? 1.06 : 1.0)
        .offset(y: bounce ? -4 : 0)
        .rotation3DEffect(.degrees(bounce ? 2 : -2), axis: (x: 0, y: 1, z: 0))
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: bounce)
        .onAppear {
            bounce = true
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

struct Eye: View {
    @State private var blink = false
    
    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.7))
            .frame(width: 8, height: blink ? 2 : 8)
            .animation(.easeInOut(duration: 0.1), value: blink)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                    blink = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        blink = false
                    }
                }
            }
    }
}

// MARK: - Glass Components
struct GlassTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            TextField(placeholder, text: $text)
                .font(Theme.bodyFont(size: 17))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
    }
}

struct GlassSegmentedPicker<T: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    @ViewBuilder let content: (T) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.bodyFont(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    content(option).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selection) {
                Haptics.selection()
            }
        }
    }
}

struct GlassSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(Int(value)) \(unit)")
                    .font(Theme.titleFont(size: 18))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
            }
            
            Slider(value: $value, in: range, step: step) { editing in
                if !editing {
                    Haptics.selection()
                }
            }
            .tint(Theme.lagoon)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct GlassToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let tint: Color
    
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: tint))
                .labelsHidden()
                .onChange(of: isOn) {
                    Haptics.selection()
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct GlassTimePicker: View {
    let title: String
    let icon: String
    @Binding var date: Date
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(tint)
                Text(title)
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(tint)
                .onChange(of: date) {
                    Haptics.selection()
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct GlassStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        HStack {
            Text(title)
                .font(Theme.bodyFont(size: 16))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    if value > range.lowerBound {
                        value -= 1
                        Haptics.impact(.light)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
                .modifier(GlassCircleModifier())
                .opacity(value > range.lowerBound ? 1 : 0.4)
                
                Text("\(value)")
                    .font(Theme.titleFont(size: 20))
                    .foregroundColor(.white)
                    .frame(minWidth: 30)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
                
                Button {
                    if value < range.upperBound {
                        value += 1
                        Haptics.impact(.light)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
                .modifier(GlassCircleModifier())
                .opacity(value < range.upperBound ? 1 : 0.4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct PermissionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .modifier(GlassCircleModifier(tint: color.opacity(0.5)))
                
                Text("Enable \(title)")
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview("Onboarding") {
    PreviewEnvironment {
        OnboardingView { }
    }
}
