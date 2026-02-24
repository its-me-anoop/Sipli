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

    var body: some View {
        Form {
            profileSection
            appearanceSection
            goalSection
            scheduleSection
            reminderSection
            permissionsSection
            aboutSection
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
        .task {
            await notifier.refreshAuthorizationStatus()
            await healthKit.refreshAuthorizationStatus()
        }
        .onAppear {
            hydrateLocalStateFromProfile()
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            TextField("Name", text: Binding(
                get: { store.profile.name },
                set: { value in
                    store.updateProfile { $0.name = value }
                }
            ))
            .textInputAutocapitalization(.words)
            .disableAutocorrection(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weight")
                    Spacer()
                    Text("\(Int(store.profile.unitSystem.amountFromKG(store.profile.weightKg))) \(store.profile.unitSystem.bodyWeightUnit)")
                        .foregroundStyle(.secondary)
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

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.label, systemImage: theme.icon)
                        .tag(theme)
                }
            }
        }
    }

    private var goalSection: some View {
        Section("Daily Goal") {
            Toggle("Use custom goal", isOn: $customGoalEnabled)
                .onChange(of: customGoalEnabled) { _, enabled in
                    store.updateProfile { profile in
                        profile.customGoalML = enabled ? profile.unitSystem.ml(from: customGoalValue) : nil
                    }
                }

            if customGoalEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Target")
                        Spacer()
                        Text("\(Int(customGoalValue)) \(store.profile.unitSystem.volumeUnit)")
                            .foregroundStyle(.secondary)
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
            }

            Toggle("Weather adjustment", isOn: Binding(
                get: { store.profile.prefersWeatherGoal },
                set: { value in
                    store.updateProfile { $0.prefersWeatherGoal = value }
                    if value {
                        locationManager.requestPermission()
                    }
                }
            ))

            Toggle("Workout adjustment", isOn: Binding(
                get: { store.profile.prefersHealthKit },
                set: { value in
                    store.updateProfile { $0.prefersHealthKit = value }
                }
            ))
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            DatePicker("Wake", selection: $wakeTime, displayedComponents: .hourAndMinute)
            DatePicker("Sleep", selection: $sleepTime, displayedComponents: .hourAndMinute)
        }
        .onChange(of: wakeTime) {
            updateSchedule()
        }
        .onChange(of: sleepTime) {
            updateSchedule()
        }
    }

    private var reminderSection: some View {
        Section("Reminders") {
            Toggle("Enable reminders", isOn: Binding(
                get: { store.profile.remindersEnabled },
                set: { value in
                    store.updateProfile { $0.remindersEnabled = value }
                    rescheduleReminders()
                }
            ))

            Toggle("Smart reminders", isOn: Binding(
                get: { store.profile.smartRemindersEnabled },
                set: { value in
                    store.updateProfile { $0.smartRemindersEnabled = value }
                    rescheduleReminders()
                }
            ))

            Stepper(value: Binding(
                get: { store.profile.dailyReminderCount },
                set: { value in
                    store.updateProfile { $0.dailyReminderCount = value }
                    rescheduleReminders()
                }
            ), in: 3...12) {
                HStack {
                    Text("Reminders per day")
                    Spacer()
                    Text("\(store.profile.dailyReminderCount)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
            permissionRow(
                title: "HealthKit",
                subtitle: healthStatusText,
                systemImage: "heart.fill",
                tint: healthKit.isAuthorized ? Theme.mint : Theme.sun
            ) {
                Task { await healthKit.requestAuthorization() }
            }

            Button("Sync HealthKit Now") {
                Task {
                    guard let entries = await healthKit.fetchRecentWaterEntries(days: 7) else { return }
                    await MainActor.run {
                        store.syncHealthKitEntriesRange(entries, days: 7)
                    }
                }
            }

            permissionRow(
                title: "Location",
                subtitle: locationStatusText,
                systemImage: "location.fill",
                tint: locationEnabled ? Theme.mint : Theme.sun
            ) {
                locationManager.requestPermission()
            }

            permissionRow(
                title: "Notifications",
                subtitle: notificationStatusText,
                systemImage: "bell.badge.fill",
                tint: notificationEnabled ? Theme.mint : Theme.sun
            ) {
                Task { await notifier.requestAuthorization() }
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Link(destination: Legal.privacyURL) {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Link(destination: Legal.termsURL) {
                HStack {
                    Label("Terms of Use", systemImage: "doc.text.fill")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func permissionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
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
        }
    }

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

#Preview("Settings") {
    PreviewEnvironment {
        SettingsView()
    }
}
