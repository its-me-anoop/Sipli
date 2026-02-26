import SwiftUI
import CoreLocation
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager

    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    @State private var customGoalEnabled = false
    @State private var customGoalValue: Double = 2200
    @State private var wakeTime: Date = Date()
    @State private var sleepTime: Date = Date()

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                appearanceCard
                goalCard
                scheduleCard
                reminderCard
                permissionsCard
                aboutCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.automatic)
        .navigationTitle("Settings")
        .background(Color.clear)
        .task {
            await notifier.refreshAuthorizationStatus()
            await healthKit.refreshAuthorizationStatus()
        }
        .onAppear {
            hydrateLocalStateFromProfile()
        }
    }

    // MARK: - Profile

    private var profileCard: some View {
        DashboardCard(title: "Profile", icon: "person.fill") {
            VStack(spacing: 20) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("Your Name", text: Binding(
                        get: { store.profile.name },
                        set: { value in
                            store.updateProfile { $0.name = value }
                        }
                    ))
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )
                }

                // Weight
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Weight")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(store.profile.unitSystem.amountFromKG(store.profile.weightKg))) \(store.profile.unitSystem.bodyWeightUnit)")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.lagoon)
                            .contentTransition(.numericText())
                    }
                    Slider(
                        value: Binding(
                            get: { store.profile.unitSystem.amountFromKG(store.profile.weightKg) },
                            set: { value in
                                store.updateProfile { profile in
                                    profile.weightKg = profile.unitSystem.kg(from: value)
                                }
                            }
                        ),
                        in: store.profile.unitSystem == .metric ? 40...140 : 90...300,
                        step: store.profile.unitSystem == .metric ? 1 : 2
                    )
                    .tint(Theme.lagoon)
                }

                // Units
                VStack(alignment: .leading, spacing: 8) {
                    Text("Units")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Picker("Units", selection: Binding(
                        get: { store.profile.unitSystem },
                        set: { value in
                            store.updateProfile { $0.unitSystem = value }
                            if customGoalEnabled {
                                let mlValue = store.profile.customGoalML ?? store.dailyGoal.totalML
                                customGoalValue = store.profile.unitSystem.amount(fromML: mlValue)
                            }
                        }
                    )) {
                        Text("Metric").tag(UnitSystem.metric)
                        Text("Imperial").tag(UnitSystem.imperial)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        DashboardCard(title: "Appearance", icon: "paintbrush.fill") {
            HStack(spacing: 10) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        Haptics.selection()
                        withAnimation(Theme.quickSpring) {
                            appTheme = theme
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: theme.icon)
                                .font(.title3)
                                .foregroundStyle(appTheme == theme ? .white : Theme.lagoon)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(appTheme == theme ? Theme.lagoon : Theme.lagoon.opacity(0.12))
                                )
                            Text(theme.label)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(appTheme == theme ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.label) theme")
                    .accessibilityAddTraits(appTheme == theme ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Daily Goal

    private var goalCard: some View {
        DashboardCard(title: "Daily Goal", icon: "target") {
            VStack(spacing: 18) {
                settingsToggle(
                    "Custom goal",
                    icon: "slider.horizontal.3",
                    isOn: $customGoalEnabled
                )
                .onChange(of: customGoalEnabled) { _, enabled in
                    store.updateProfile { profile in
                        profile.customGoalML = enabled ? profile.unitSystem.ml(from: customGoalValue) : nil
                    }
                }

                if customGoalEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(customGoalValue)) \(store.profile.unitSystem.volumeUnit)")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.sun)
                                .contentTransition(.numericText())
                        }
                        Slider(
                            value: $customGoalValue,
                            in: store.profile.unitSystem == .metric ? 1500...4500 : 50...150,
                            step: store.profile.unitSystem == .metric ? 50 : 2
                        )
                        .tint(Theme.sun)
                        .onChange(of: customGoalValue) { _, value in
                            store.updateProfile { profile in
                                profile.customGoalML = profile.unitSystem.ml(from: value)
                            }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Divider().opacity(0.3)

                settingsToggle(
                    "Weather adjustment",
                    icon: "cloud.sun.fill",
                    isOn: Binding(
                        get: { store.profile.prefersWeatherGoal },
                        set: { value in
                            store.updateProfile { $0.prefersWeatherGoal = value }
                            if value {
                                locationManager.requestPermission()
                            }
                        }
                    )
                )

                settingsToggle(
                    "Workout adjustment",
                    icon: "figure.run",
                    isOn: Binding(
                        get: { store.profile.prefersHealthKit },
                        set: { value in
                            store.updateProfile { $0.prefersHealthKit = value }
                        }
                    )
                )
            }
            .animation(Theme.fluidSpring, value: customGoalEnabled)
        }
    }

    // MARK: - Schedule

    private var scheduleCard: some View {
        DashboardCard(title: "Schedule", icon: "sun.and.horizon.fill") {
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sunrise.fill")
                            .foregroundStyle(Theme.sun)
                            .frame(width: 22)
                        Text("Wake")
                            .font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Theme.lagoon)
                }

                Divider().opacity(0.3)

                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.fill")
                            .foregroundStyle(Theme.lavender)
                            .frame(width: 22)
                        Text("Sleep")
                            .font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    DatePicker("", selection: $sleepTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Theme.lagoon)
                }
            }
        }
        .onChange(of: wakeTime) {
            updateSchedule()
        }
        .onChange(of: sleepTime) {
            updateSchedule()
        }
    }

    // MARK: - Reminders

    private var reminderCard: some View {
        DashboardCard(title: "Reminders", icon: "bell.badge.fill") {
            VStack(spacing: 18) {
                settingsToggle(
                    "Enable reminders",
                    icon: "bell.fill",
                    isOn: Binding(
                        get: { store.profile.remindersEnabled },
                        set: { value in
                            store.updateProfile { $0.remindersEnabled = value }
                            rescheduleReminders()
                        }
                    )
                )

                settingsToggle(
                    "Smart reminders",
                    icon: "brain.head.profile.fill",
                    isOn: Binding(
                        get: { store.profile.smartRemindersEnabled },
                        set: { value in
                            store.updateProfile { $0.smartRemindersEnabled = value }
                            rescheduleReminders()
                        }
                    )
                )
            }
        }
    }

    // MARK: - Permissions

    private var permissionsCard: some View {
        DashboardCard(title: "Permissions", icon: "shield.fill") {
            VStack(spacing: 14) {
                permissionRow(
                    title: "HealthKit",
                    subtitle: healthStatusText,
                    systemImage: "heart.fill",
                    tint: healthKit.isAuthorized ? Theme.mint : Theme.sun,
                    isDetermined: healthKit.isAuthorized
                ) {
                    Task { await healthKit.requestAuthorization() }
                }

                Button {
                    Haptics.impact(.light)
                    Task {
                        guard let entries = await healthKit.fetchRecentWaterEntries(days: 7) else { return }
                        await MainActor.run {
                            store.syncHealthKitEntriesRange(entries, days: 7)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Theme.lagoon)
                            .frame(width: 22)
                        Text("Sync HealthKit Now")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                permissionRow(
                    title: "Location",
                    subtitle: locationStatusText,
                    systemImage: "location.fill",
                    tint: locationEnabled ? Theme.mint : Theme.sun,
                    isDetermined: locationManager.authorizationStatus != .notDetermined
                ) {
                    locationManager.requestPermission()
                }

                permissionRow(
                    title: "Notifications",
                    subtitle: notificationStatusText,
                    systemImage: "bell.badge.fill",
                    tint: notificationEnabled ? Theme.mint : Theme.sun,
                    isDetermined: notifier.authorizationStatus != .notDetermined
                ) {
                    Task { await notifier.requestAuthorization() }
                }
            }
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        DashboardCard(title: "About", icon: "info.circle.fill") {
            VStack(spacing: 14) {
                Link(destination: Legal.privacyURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(Theme.lagoon)
                            .frame(width: 22)
                        Text("Privacy Policy")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )
                }

                Link(destination: Legal.termsURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(Theme.lagoon)
                            .frame(width: 22)
                        Text("Terms of Use")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: "number")
                        .foregroundStyle(Theme.lagoon)
                        .frame(width: 22)
                    Text("Version")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.glassBorder, lineWidth: 1)
                )

                Link(destination: Legal.manageSubscriptionsURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "creditcard.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        Text("Manage Subscription")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Reusable Components

    private func settingsToggle(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.lagoon)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
        }
        .tint(Theme.lagoon)
    }

    private func permissionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isDetermined: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            Haptics.selection()
            if isDetermined {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } else {
                action()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Helpers

    private var healthStatusText: String {
        if !healthKit.isAvailable { return "Unavailable" }
        return healthKit.isAuthorized ? "Connected" : "Not connected"
    }

    private var locationEnabled: Bool {
        locationManager.authorizationStatus == .authorizedAlways ||
        locationManager.authorizationStatus == .authorizedWhenInUse
    }

    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "Enabled"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not set"
        @unknown default:
            return "Unknown"
        }
    }

    private var notificationEnabled: Bool {
        switch notifier.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private var notificationStatusText: String {
        switch notifier.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Enabled"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not set"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - State Sync

    private func hydrateLocalStateFromProfile() {
        if let custom = store.profile.customGoalML {
            customGoalEnabled = true
            customGoalValue = store.profile.unitSystem.amount(fromML: custom)
        } else {
            customGoalEnabled = false
            customGoalValue = store.profile.unitSystem.amount(fromML: store.dailyGoal.baseML)
        }

        wakeTime = dateFromMinutes(store.profile.wakeMinutes)
        sleepTime = dateFromMinutes(store.profile.sleepMinutes)
    }

    private func updateSchedule() {
        let wakeMinutes = minutes(from: wakeTime)
        let sleepMinutes = minutes(from: sleepTime)

        store.updateProfile { profile in
            profile.wakeMinutes = wakeMinutes
            profile.sleepMinutes = sleepMinutes
        }

        rescheduleReminders()
    }

    private func rescheduleReminders() {
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

#if DEBUG
#Preview("Settings") {
    PreviewEnvironment {
        SettingsView()
    }
}
#endif
