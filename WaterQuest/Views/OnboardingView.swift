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

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()
            WaveView()
                .opacity(0.35)
                .frame(height: 220)
                .offset(y: 260)

            VStack(spacing: 16) {
                TabView(selection: $pageIndex) {
                    introPage.tag(0)
                    profilePage.tag(1)
                    schedulePage.tag(2)
                    permissionsPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 12) {
                    if pageIndex > 0 {
                        Button("Back") {
                            withAnimation { pageIndex -= 1 }
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(pageIndex == 3 ? "Start Quest" : "Next") {
                        if pageIndex == 3 {
                            finishOnboarding()
                        } else {
                            withAnimation { pageIndex += 1 }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var introPage: some View {
        VStack(spacing: 20) {
            Spacer()
            MascotView()
            Text("WaterQuest")
                .font(Theme.titleFont(size: 34))
                .foregroundColor(.white)
            Text("A playful hydration adventure with quests, streaks, and smart goals that adapt to your day.")
                .font(Theme.bodyFont(size: 16))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .padding(.top, 30)
    }

    private var profilePage: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Build Your Hero Profile")
                    .font(Theme.titleFont(size: 26))
                    .foregroundColor(.white)

                textField(title: "Name", text: $name)

                pickerSection(title: "Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases, id: \.self) { unit in
                        Text(unit == .metric ? "Metric" : "Imperial").tag(unit)
                    }
                }

                sliderSection(
                    title: "Weight (\(unitSystem.bodyWeightUnit))",
                    value: $weight,
                    range: unitSystem == .metric ? 40...140 : 90...300,
                    step: unitSystem == .metric ? 1 : 2
                )

                pickerSection(title: "Activity", selection: $activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
        }
    }

    private var schedulePage: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Daily Rhythm")
                    .font(Theme.titleFont(size: 26))
                    .foregroundColor(.white)

                Toggle("Use a custom daily goal", isOn: $customGoalEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Theme.mint))
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(.white)

                if customGoalEnabled {
                    sliderSection(
                        title: "Goal (\(unitSystem.volumeUnit))",
                        value: $customGoalValue,
                        range: unitSystem == .metric ? 1500...4500 : 50...150,
                        step: unitSystem == .metric ? 50 : 2
                    )
                }

                HStack(spacing: 12) {
                    timePicker(title: "Wake", date: $wakeTime)
                    timePicker(title: "Sleep", date: $sleepTime)
                }

                Toggle("Reminders", isOn: $remindersEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Theme.lagoon))
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(.white)

                if remindersEnabled {
                    Stepper(value: $reminderCount, in: 3...12) {
                        Text("\(reminderCount) reminders/day")
                            .font(Theme.bodyFont(size: 14))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var permissionsPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Power-Ups")
                    .font(Theme.titleFont(size: 26))
                    .foregroundColor(.white)

                Toggle("Personalize with weather", isOn: $prefersWeather)
                    .toggleStyle(SwitchToggleStyle(tint: Theme.sun))
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(.white)

                Toggle("Sync workouts & water with Health", isOn: $prefersHealthKit)
                    .toggleStyle(SwitchToggleStyle(tint: Theme.mint))
                    .font(Theme.bodyFont(size: 16))
                    .foregroundColor(.white)

                Button("Enable Health & Activity") {
                    Task { await healthKit.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)

                Button("Enable Location") {
                    locationManager.requestPermission()
                }
                .buttonStyle(.bordered)

                Button("Enable Notifications") {
                    Task { await notifier.requestAuthorization() }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
        }
    }

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
        onComplete()
    }

    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func textField(title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.roundedBorder)
            .font(Theme.bodyFont(size: 16))
    }

    private func pickerSection<T: Hashable>(title: String, selection: Binding<T>, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(.white.opacity(0.6))
            Picker(title, selection: selection, content: content)
                .pickerStyle(.segmented)
        }
    }

    private func sliderSection(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(.white.opacity(0.6))
            Slider(value: value, in: range, step: step)
            Text(String(format: "%.0f", value.wrappedValue))
                .font(Theme.titleFont(size: 18))
                .foregroundColor(.white)
        }
    }

    private func timePicker(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.bodyFont(size: 13))
                .foregroundColor(.white.opacity(0.6))
            DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.card)
        )
    }
}

#Preview("Onboarding") {
    PreviewEnvironment {
        OnboardingView { }
    }
}
