import SwiftUI
import CoreLocation
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager

    @State private var customGoalEnabled: Bool = false
    @State private var customGoalValue: Double = 2200
    @State private var wakeTime: Date = Date()
    @State private var sleepTime: Date = Date()
    @State private var appearAnimation = false

    var body: some View {
        ZStack(alignment: .top) {
            // Animated background
            SettingsBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                        .offset(y: appearAnimation ? 0 : -20)
                        .opacity(appearAnimation ? 1 : 0)

                    profileSection
                        .offset(y: appearAnimation ? 0 : 20)
                        .opacity(appearAnimation ? 1 : 0)

                    goalSection
                        .offset(y: appearAnimation ? 0 : 25)
                        .opacity(appearAnimation ? 1 : 0)

                    scheduleSection
                        .offset(y: appearAnimation ? 0 : 30)
                        .opacity(appearAnimation ? 1 : 0)

                    remindersSection
                        .offset(y: appearAnimation ? 0 : 35)
                        .opacity(appearAnimation ? 1 : 0)

                    permissionsSection
                        .offset(y: appearAnimation ? 0 : 40)
                        .opacity(appearAnimation ? 1 : 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            if let custom = store.profile.customGoalML {
                customGoalEnabled = true
                customGoalValue = store.profile.unitSystem.amount(fromML: custom)
            } else {
                customGoalEnabled = false
                customGoalValue = store.profile.unitSystem.amount(fromML: store.dailyGoal.baseML)
            }
            wakeTime = dateFromMinutes(store.profile.wakeMinutes)
            sleepTime = dateFromMinutes(store.profile.sleepMinutes)
            Task { await notifier.refreshAuthorizationStatus() }

            withAnimation(Theme.fluidSpring.delay(0.1)) {
                appearAnimation = true
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(Theme.titleFont(size: 28))
                    .foregroundColor(.white)
                Text("Fine-tune your daily hydration flow")
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(Theme.lagoon.opacity(0.2))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.lagoon)
            }
            .frame(width: 44, height: 44)
            .shadow(color: Theme.lagoon.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var profileSection: some View {
        glassSection(title: "Profile", subtitle: "Personal details and unit preferences", systemImage: "person.fill", iconTint: Theme.mint) {
            labeledTextField(title: "Name", placeholder: "Your name", text: binding(get: { store.profile.name }, set: { newValue in
                store.updateProfile { $0.name = newValue }
            }))

            rowDivider

            weightSlider

            rowDivider

            unitPicker
        }
    }

    private var weightSlider: some View {
        let unit = store.profile.unitSystem
        let weightValue = Int(unit.amountFromKG(store.profile.weightKg))

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weight")
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(.white)
                Spacer()
                valuePill("\(weightValue) \(unit.bodyWeightUnit)", color: Theme.mint)
            }
            Slider(value: binding(get: {
                unit.amountFromKG(store.profile.weightKg)
            }, set: { value in
                store.updateProfile { profile in
                    profile.weightKg = unit.kg(from: value)
                }
            }), in: unit == .metric ? 40...140 : 90...300, step: unit == .metric ? 1 : 2) { editing in
                if !editing {
                    Haptics.selection()
                }
            }
            .tint(Theme.mint)
        }
    }

    private var unitPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Units")
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(.white.opacity(0.6))

            Picker("Units", selection: binding(get: { store.profile.unitSystem }, set: { value in
                store.updateProfile { $0.unitSystem = value }
            })) {
                Text("Metric").tag(UnitSystem.metric)
                Text("Imperial").tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)
            .tint(Theme.lagoon)
            .onChange(of: store.profile.unitSystem) {
                Haptics.selection()
            }
        }
    }

    private var goalSection: some View {
        glassSection(title: "Goal", subtitle: "Daily target and adjustments", systemImage: "target", iconTint: Theme.sun) {
            toggleRow(title: "Use custom goal", subtitle: "Set a personalized daily target", isOn: Binding(
                get: { customGoalEnabled },
                set: { enabled in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        customGoalEnabled = enabled
                    }
                    store.updateProfile { profile in
                        if enabled {
                            profile.customGoalML = profile.unitSystem.ml(from: customGoalValue)
                        } else {
                            profile.customGoalML = nil
                        }
                    }
                }
            ), tint: Theme.sun)

            if customGoalEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Daily goal")
                            .font(Theme.bodyFont(size: 14))
                            .foregroundColor(.white)
                        Spacer()
                        valuePill("\(String(format: "%.0f", customGoalValue)) \(store.profile.unitSystem.volumeUnit)", color: Theme.sun)
                    }
                    Slider(value: $customGoalValue, in: store.profile.unitSystem == .metric ? 1500...4500 : 50...150, step: store.profile.unitSystem == .metric ? 50 : 2) { editing in
                        if !editing {
                            Haptics.selection()
                        }
                    }
                        .tint(Theme.sun)
                    Text("Updates immediately and feeds quests")
                        .font(Theme.bodyFont(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .onChange(of: customGoalValue) { _, value in
                            store.updateProfile { profile in
                                profile.customGoalML = profile.unitSystem.ml(from: value)
                            }
                        }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            rowDivider

            toggleRow(title: "Use weather adjustment", subtitle: "Adapt goal for heat and humidity", isOn: binding(get: { store.profile.prefersWeatherGoal }, set: { value in
                store.updateProfile { $0.prefersWeatherGoal = value }
                if value {
                    locationManager.requestLocation()
                }
            }), tint: Theme.sun)

            toggleRow(title: "Use workouts adjustment", subtitle: "Boost goal for active days", isOn: binding(get: { store.profile.prefersHealthKit }, set: { value in
                store.updateProfile { $0.prefersHealthKit = value }
            }), tint: Theme.mint)

        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: customGoalEnabled)
    }

    private var scheduleSection: some View {
        glassSection(title: "Schedule", subtitle: "Set your daily window", systemImage: "clock.fill", iconTint: Theme.lagoon) {
            HStack(spacing: 12) {
                timePicker(title: "Wake", systemImage: "sunrise.fill", tint: Theme.sun, date: $wakeTime)
                timePicker(title: "Sleep", systemImage: "moon.stars.fill", tint: Theme.mint, date: $sleepTime)
            }
            .onChange(of: wakeTime) { updateSchedule() }
            .onChange(of: sleepTime) { updateSchedule() }
        }
    }

    private var remindersSection: some View {
        glassSection(title: "Reminders", subtitle: "Gentle nudges throughout the day", systemImage: "bell.fill", iconTint: Theme.lagoon) {
            toggleRow(title: "Enable reminders", subtitle: "Stay on track with timed alerts", isOn: binding(get: { store.profile.remindersEnabled }, set: { value in
                store.updateProfile { $0.remindersEnabled = value }
                notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
            }), tint: Theme.lagoon)

            rowDivider

            toggleRow(title: "Smart reminders", subtitle: "Skip when active, nudge when quiet", isOn: binding(get: { store.profile.smartRemindersEnabled }, set: { value in
                store.updateProfile { $0.smartRemindersEnabled = value }
                notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
            }), tint: Theme.lagoon)

            rowDivider

            Stepper(value: binding(get: { store.profile.dailyReminderCount }, set: { value in
                store.updateProfile { $0.dailyReminderCount = value }
                notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
            }), in: 3...12) {
                HStack {
                    Text("Reminders per day")
                        .font(Theme.bodyFont(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    valuePill("\(store.profile.dailyReminderCount)", color: Theme.lagoon)
                }
            }
            .tint(Theme.lagoon)
            .onChange(of: store.profile.dailyReminderCount) {
                Haptics.selection()
            }
        }
    }

    private var permissionsSection: some View {
        glassSection(title: "Permissions", subtitle: "Connect health, weather, and alerts", systemImage: "lock.shield.fill", iconTint: Theme.coral) {
            permissionRow(title: "HealthKit", subtitle: "Sync workouts and water logs", systemImage: "heart.fill", status: healthStatus) {
                Task { await healthKit.requestAuthorization() }
            }

            permissionRow(title: "Location", subtitle: "Local weather for goal tuning", systemImage: "location.fill", status: locationStatus) {
                locationManager.requestPermission()
            }

            permissionRow(title: "Notifications", subtitle: "Hydration reminders and streaks", systemImage: "bell.badge.fill", status: notificationStatus) {
                Task { await notifier.requestAuthorization() }
            }
        }
    }

    // MARK: - Section Builder with Liquid Glass
    private func glassSection<Content: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        iconTint: Color = Theme.lagoon,
        @ViewBuilder content: () -> Content
    ) -> some View {
        LiquidGlassCard(cornerRadius: 22, tintColor: iconTint.opacity(0.3), isInteractive: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    iconBubble(systemImage: systemImage, tint: iconTint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(Theme.titleFont(size: 16))
                            .foregroundColor(.white)
                        Text(subtitle)
                            .font(Theme.bodyFont(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }

                content()
            }
            .padding(16)
        }
    }

    private func labeledTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(.white.opacity(0.6))
            TextField(placeholder, text: text)
                .font(Theme.bodyFont(size: 15))
                .foregroundColor(.white)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .tint(Theme.mint)
        }
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>, tint: Color) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.bodyFont(size: 14))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(Theme.bodyFont(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: tint))
        .onChange(of: isOn.wrappedValue) {
            Haptics.selection()
        }
    }

    private func permissionRow(title: String, subtitle: String, systemImage: String, status: StatusIndicator, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconBubble(systemImage: systemImage, tint: status.color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.bodyFont(size: 14))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(Theme.bodyFont(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                statusBadge(status.text, color: status.color)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hapticTap()
    }

    private func iconBubble(systemImage: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.2))
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
        }
        .frame(width: 32, height: 32)
    }

    private func valuePill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.bodyFont(size: 12))
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(color.opacity(0.2))
            )
            .foregroundColor(color)
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.bodyFont(size: 11))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .fill(color.opacity(0.18))
            )
            .foregroundColor(color)
    }

    private func timePicker(title: String, systemImage: String, tint: Color, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                iconBubble(systemImage: systemImage, tint: tint)
                Text(title)
                    .font(Theme.bodyFont(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(tint)
                .onChange(of: date.wrappedValue) {
                    Haptics.selection()
                }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }

    private struct StatusIndicator {
        let text: String
        let color: Color
    }

    private var healthStatus: StatusIndicator {
        if !healthKit.isAvailable {
            return StatusIndicator(text: "Unavailable", color: Theme.coral)
        }
        return healthKit.isAuthorized
            ? StatusIndicator(text: "Connected", color: Theme.mint)
            : StatusIndicator(text: "Not Connected", color: Theme.sun)
    }

    private var locationStatus: StatusIndicator {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return StatusIndicator(text: "Enabled", color: Theme.mint)
        case .denied:
            return StatusIndicator(text: "Denied", color: Theme.coral)
        case .restricted:
            return StatusIndicator(text: "Restricted", color: Theme.coral)
        case .notDetermined:
            return StatusIndicator(text: "Not Set", color: Theme.sun)
        @unknown default:
            return StatusIndicator(text: "Unknown", color: .white.opacity(0.7))
        }
    }

    private var notificationStatus: StatusIndicator {
        switch notifier.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return StatusIndicator(text: "Enabled", color: Theme.mint)
        case .denied:
            return StatusIndicator(text: "Denied", color: Theme.coral)
        case .notDetermined:
            return StatusIndicator(text: "Not Set", color: Theme.sun)
        @unknown default:
            return StatusIndicator(text: "Unknown", color: .white.opacity(0.7))
        }
    }

    private func binding<T>(get: @escaping () -> T, set: @escaping (T) -> Void) -> Binding<T> {
        Binding(get: get, set: set)
    }

    private func updateSchedule() {
        let wakeMinutes = minutes(from: wakeTime)
        let sleepMinutes = minutes(from: sleepTime)
        store.updateProfile { profile in
            profile.wakeMinutes = wakeMinutes
            profile.sleepMinutes = sleepMinutes
        }
        notifier.scheduleReminders(profile: store.profile, entries: store.entries, goalML: store.dailyGoal.totalML)
    }

    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        let hour = minutes / 60
        let minute = minutes % 60
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - Settings Background
private struct SettingsBackground: View {
    @State private var gradientRotation: Double = 0

    var body: some View {
        ZStack {
            Theme.background

            // Rotating gradient orbs
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.lagoon.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(x: -100, y: -50)
                        .rotationEffect(.degrees(gradientRotation))

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.mint.opacity(0.1), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .offset(x: geometry.size.width - 100, y: geometry.size.height - 200)
                        .rotationEffect(.degrees(-gradientRotation * 0.5))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
        }
    }
}

#Preview("Settings") {
    PreviewEnvironment {
        SettingsView()
    }
}
