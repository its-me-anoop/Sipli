import SwiftUI
import StoreKit
import CoreLocation
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    @State private var customGoalEnabled = false
    @State private var customGoalValue: Double = 2200
    @State private var wakeTime: Date = Date()
    @State private var sleepTime: Date = Date()
    @State private var earthDayIconEnabled: Bool = UIApplication.shared.alternateIconName == EarthDayEvent.alternateIconName
    @State private var isPremiumPromptDismissed = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass == .regular }
    private var loggedDayCount: Int {
        Set(store.entries.map { $0.date.startOfDay }).count
    }
    private var shouldShowPremiumPrompt: Bool {
        guard !subscriptionManager.hasPremiumAccess else { return false }
        guard !isPremiumPromptDismissed else { return false }
        guard loggedDayCount >= 3 else { return false }

        if let nextEligibleAt = store.premiumUpsellState.nextEligibleAt {
            return nextEligibleAt <= Date()
        }

        return true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                appearanceCard
                premiumGoalCard
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
        .background { AppWaterBackground().ignoresSafeArea() }
        .task {
            await notifier.refreshAuthorizationStatus()
            await healthKit.refreshAuthorizationStatus()
        }
        .onAppear {
            hydrateLocalStateFromProfile()
            isPremiumPromptDismissed = false
        }
    }

    private var premiumGoalCard: some View {
        Group {
            if !subscriptionManager.isSubscribed, shouldShowPremiumPrompt {
                PremiumSoftSellBanner(
                    title: "Upgrade your hydration goals",
                    message: "Unlock weather and workout adjustments, AI insights, HealthKit sync, and smarter reminders when you are ready.",
                    featurePills: [
                        (icon: "cloud.sun.fill", text: "Weather Goals"),
                        (icon: "figure.run", text: "Workout Goals"),
                        (icon: "brain.head.profile.fill", text: "AI Insights"),
                        (icon: "heart.fill", text: "HealthKit Sync")
                    ],
                    ctaTitle: "See Premium",
                    onDismiss: dismissPremiumPrompt,
                    onShowPremium: {
                        Haptics.selection()
                        subscriptionManager.presentPaywall()
                    },
                    onBackgroundTap: {
                        Haptics.selection()
                        subscriptionManager.presentPaywall()
                    }
                )
            }
        }
    }

    private func dismissPremiumPrompt() {
        Haptics.selection()
        isPremiumPromptDismissed = true
        store.dismissPremiumUpsell()
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
                            .fill(Theme.card)
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
            VStack(spacing: 18) {
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

                if EarthDayEvent.isActive()
                    && EarthDayEvent.alternateIconAvailable
                    && UIApplication.shared.supportsAlternateIcons {
                    Divider().opacity(0.3)
                    settingsToggle(
                        "Earth Day icon",
                        icon: "leaf.fill",
                        isOn: Binding(
                            get: { earthDayIconEnabled },
                            set: { value in
                                earthDayIconEnabled = value
                                setEarthDayIcon(enabled: value)
                            }
                        )
                    )
                }
            }
        }
    }

    private func setEarthDayIcon(enabled: Bool) {
        let targetName: String? = enabled ? EarthDayEvent.alternateIconName : nil
        guard UIApplication.shared.alternateIconName != targetName else { return }
        UIApplication.shared.setAlternateIconName(targetName) { error in
            if error != nil {
                Task { @MainActor in
                    // Revert UI state if the OS refused the change (e.g. icon
                    // asset missing or not yet registered in the build).
                    earthDayIconEnabled = UIApplication.shared.alternateIconName == EarthDayEvent.alternateIconName
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

                if subscriptionManager.hasAccess(to: .weatherGoals) {
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
                } else {
                    premiumLockedRow(
                        title: "Weather adjustment",
                        subtitle: "Premium adapts your goal to local temperature and humidity.",
                        systemImage: "cloud.sun.fill",
                        feature: .weatherGoals
                    )
                }

                if subscriptionManager.hasAccess(to: .activityGoals) {
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
                } else {
                    premiumLockedRow(
                        title: "Workout adjustment",
                        subtitle: "Premium increases your goal using Apple Health workout data.",
                        systemImage: "figure.run",
                        feature: .activityGoals
                    )
                }

                Divider().opacity(0.3)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal methodology sources")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Link("National Academies: Dietary Reference Intakes for Water (2005)", destination: Legal.hydrationBaseCitationURL)
                        .font(.caption)
                    Link("CDC: Water and Healthier Drinks", destination: Legal.hydrationHeatCitationURL)
                        .font(.caption)
                    Link("ACSM: Facts About Hydration & Electrolytes", destination: Legal.hydrationExerciseCitationURL)
                        .font(.caption)

                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("This app does not provide medical advice. Hydration goals are general wellness estimates based on the sources above. Consult a healthcare professional for guidance specific to your health needs.")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

                if subscriptionManager.hasAccess(to: .smartReminders) {
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
                } else {
                    premiumLockedRow(
                        title: "Smart reminders",
                        subtitle: "Premium unlocks adaptive reminders based on your schedule and progress.",
                        systemImage: "brain.head.profile.fill",
                        feature: .smartReminders
                    )
                }
            }
        }
    }

    // MARK: - Permissions

    private var permissionsCard: some View {
        DashboardCard(title: "Permissions", icon: "shield.fill") {
            VStack(spacing: 14) {
                if subscriptionManager.hasAccess(to: .healthKitSync) {
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
                                .fill(Theme.card)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    premiumLockedRow(
                        title: "HealthKit sync",
                        subtitle: "Premium syncs your water intake and workout data with Apple Health.",
                        systemImage: "heart.fill",
                        feature: .healthKitSync
                    )
                }

                if subscriptionManager.hasAccess(to: .weatherGoals) {
                    permissionRow(
                        title: "Location",
                        subtitle: locationStatusText,
                        systemImage: "location.fill",
                        tint: locationEnabled ? Theme.mint : Theme.sun,
                        isDetermined: locationManager.authorizationStatus != .notDetermined
                    ) {
                        locationManager.requestPermission()
                    }
                } else {
                    premiumLockedRow(
                        title: "Weather permissions",
                        subtitle: "Premium uses location permission to power weather-based hydration goals.",
                        systemImage: "location.fill",
                        feature: .weatherGoals
                    )
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
                NavigationLink {
                    EarthInfoView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(Color(red: 0.22, green: 0.62, blue: 0.42))
                            .frame(width: 22)
                        Text("Why reusable bottles matter")
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
                            .fill(Theme.card)
                    )
                }
                .buttonStyle(.plain)

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
                            .fill(Theme.card)
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
                            .fill(Theme.card)
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
                        .fill(Theme.card)
                )

                if subscriptionManager.isSubscribed {
                    manageSubscriptionSection
                } else {
                    premiumLockedRow(
                        title: "Explore premium plans",
                        subtitle: "Unlock beverage types, AI insights, HealthKit sync, adaptive goals, and smart reminders.",
                        systemImage: "sparkles",
                        feature: nil
                    )
                }
            }
        }
    }

    // MARK: - Manage Subscription

    @State private var showManageSubscription = false

    private var manageSubscriptionSection: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.selection()
                showManageSubscription = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(Theme.lagoon)
                        .frame(width: 22)
                    Text("Manage Subscription")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text(subscriptionManager.currentPlanName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.mint)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.card)
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showManageSubscription) {
                ManageSubscriptionSheet()
                    .environmentObject(subscriptionManager)
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
                    .fill(Theme.card)
            )
        }
        .buttonStyle(.plain)
    }

    private func premiumLockedRow(
        title: String,
        subtitle: String,
        systemImage: String,
        feature: PremiumFeature?
    ) -> some View {
        Button {
            Haptics.selection()
            subscriptionManager.presentPaywall(for: feature)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(Theme.sun)
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

                VStack(spacing: 2) {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.sun)
                    Text("Premium")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.card)
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
        notifier.scheduleReminders(profile: store.effectiveProfile, entries: store.entries, goalML: store.dailyGoal.totalML)
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

// MARK: - Manage Subscription Sheet

private struct ManageSubscriptionSheet: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private var currentPlanID: ProductID? {
        subscriptionManager.activeProductID
    }

    private var alternatePlan: (id: ProductID, product: Product?)? {
        guard let current = currentPlanID else { return nil }
        let alternate: ProductID = current == .annual ? .monthly : .annual
        return (alternate, subscriptionManager.product(for: alternate))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppWaterBackground().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Current plan
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.lagoon)

                            Text("Sipli Premium")
                                .font(.title2.bold())

                            HStack(spacing: 6) {
                                Text("\(subscriptionManager.currentPlanName) Plan")
                                    .font(.subheadline.weight(.medium))
                                Text("Active")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.mint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Theme.mint.opacity(0.12))
                                    )
                            }
                        }
                        .padding(.top, 8)

                        // Switch plan
                        if let alternate = alternatePlan, let product = alternate.product {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Switch Plan")
                                    .font(.headline)

                                Button {
                                    switchPlan(to: product)
                                } label: {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text(alternate.id.displayName)
                                                    .font(.headline)

                                                if let badge = alternate.id.badgeText {
                                                    Text(badge)
                                                        .font(.caption2.weight(.bold))
                                                        .foregroundStyle(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Theme.sun)
                                                        .clipShape(Capsule())
                                                }
                                            }

                                            Text(alternate.id.shortDescription)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                                            Text(product.displayPrice)
                                                .font(.title3.weight(.bold))
                                                .foregroundStyle(Theme.lagoon)
                                            Text(alternate.id.billingSuffix)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Theme.glassBorder.opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isPurchasing)

                                Text("Plan changes take effect at the end of your current billing period.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if isPurchasing {
                            HStack(spacing: 8) {
                                ProgressView().tint(Theme.lagoon)
                                Text("Processing...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Divider().opacity(0.3)

                        // Cancel subscription
                        VStack(spacing: 12) {
                            Button {
                                Haptics.selection()
                                UIApplication.shared.open(Legal.manageSubscriptionsURL)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundStyle(.red.opacity(0.8))
                                    Text("Cancel Subscription")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(.red.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)

                            Text("Opens iOS Settings where you can cancel or modify your subscription.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Manage Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.lagoon)
                }
            }
        }
    }

    private func switchPlan(to product: Product) {
        isPurchasing = true
        errorMessage = nil

        Task {
            let result = await subscriptionManager.purchase(product)
            isPurchasing = false

            switch result {
            case .success:
                Haptics.success()
                dismiss()
            case .cancelled:
                break
            case .pending:
                errorMessage = "Plan change is pending approval."
            case .failed(let message):
                Haptics.error()
                errorMessage = message
            }
        }
    }
}

#if DEBUG
#Preview("Settings") {
    PreviewEnvironment {
        SettingsView()
    }
}
#endif
