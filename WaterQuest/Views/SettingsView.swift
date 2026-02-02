import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var notifier: NotificationScheduler
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager

    @State private var manualTemp: Double = 22
    @State private var manualHumidity: Double = 55
    @State private var customGoalEnabled: Bool = false
    @State private var customGoalValue: Double = 2200
    @State private var wakeTime: Date = Date()
    @State private var sleepTime: Date = Date()

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(Theme.titleFont(size: 26))
                        .foregroundColor(.white)

                    section(title: "Profile") {
                        TextField("Name", text: binding(get: { store.profile.name }, set: { newValue in
                            store.updateProfile { $0.name = newValue }
                        }))
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Text("Weight")
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text("\(Int(store.profile.unitSystem.amountFromKG(store.profile.weightKg))) \(store.profile.unitSystem.bodyWeightUnit)")
                                .foregroundColor(.white)
                        }
                        Slider(value: binding(get: {
                            store.profile.unitSystem.amountFromKG(store.profile.weightKg)
                        }, set: { value in
                            store.updateProfile { profile in
                                profile.weightKg = profile.unitSystem.kg(from: value)
                            }
                        }), in: store.profile.unitSystem == .metric ? 40...140 : 90...300, step: store.profile.unitSystem == .metric ? 1 : 2)

                        Picker("Units", selection: binding(get: { store.profile.unitSystem }, set: { value in store.updateProfile { $0.unitSystem = value } })) {
                            Text("Metric").tag(UnitSystem.metric)
                            Text("Imperial").tag(UnitSystem.imperial)
                        }
                        .pickerStyle(.segmented)
                    }

                    section(title: "Goal") {
                        Toggle("Use custom goal", isOn: Binding(
                            get: { customGoalEnabled },
                            set: { enabled in
                                customGoalEnabled = enabled
                                store.updateProfile { profile in
                                    if enabled {
                                        profile.customGoalML = profile.unitSystem.ml(from: customGoalValue)
                                    } else {
                                        profile.customGoalML = nil
                                    }
                                }
                            })
                        )
                        .toggleStyle(SwitchToggleStyle(tint: Theme.sun))

                        if customGoalEnabled {
                            Slider(value: $customGoalValue, in: store.profile.unitSystem == .metric ? 1500...4500 : 50...150, step: store.profile.unitSystem == .metric ? 50 : 2)
                            Text("Custom goal: \(String(format: "%.0f", customGoalValue)) \(store.profile.unitSystem.volumeUnit)")
                                .foregroundColor(.white)
                                .font(Theme.bodyFont(size: 13))
                                .onChange(of: customGoalValue) { value in
                                    store.updateProfile { profile in
                                        profile.customGoalML = profile.unitSystem.ml(from: value)
                                    }
                                }
                        }

                        Toggle("Use weather adjustment", isOn: binding(get: { store.profile.prefersWeatherGoal }, set: { value in store.updateProfile { $0.prefersWeatherGoal = value } }))
                            .toggleStyle(SwitchToggleStyle(tint: Theme.sun))

                        Toggle("Use workouts adjustment", isOn: binding(get: { store.profile.prefersHealthKit }, set: { value in store.updateProfile { $0.prefersHealthKit = value } }))
                            .toggleStyle(SwitchToggleStyle(tint: Theme.mint))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Manual Weather Override")
                                .font(Theme.bodyFont(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                            Slider(value: $manualTemp, in: -5...40, step: 1)
                            Slider(value: $manualHumidity, in: 10...95, step: 5)
                            HStack {
                                Text("\(Int(manualTemp))°C, \(Int(manualHumidity))%")
                                    .foregroundColor(.white)
                                Spacer()
                                Button("Apply") {
                                    let snapshot = WeatherSnapshot(temperatureC: manualTemp, humidityPercent: manualHumidity, condition: "Manual")
                                    store.updateManualWeather(snapshot)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    section(title: "Schedule") {
                        HStack(spacing: 12) {
                            timePicker(title: "Wake", date: $wakeTime)
                            timePicker(title: "Sleep", date: $sleepTime)
                        }
                        .onChange(of: wakeTime) { _ in updateSchedule() }
                        .onChange(of: sleepTime) { _ in updateSchedule() }
                    }

                    section(title: "Reminders") {
                        Toggle("Enable reminders", isOn: binding(get: { store.profile.remindersEnabled }, set: { value in
                            store.updateProfile { $0.remindersEnabled = value }
                            notifier.scheduleReminders(profile: store.profile)
                        }))
                        .toggleStyle(SwitchToggleStyle(tint: Theme.lagoon))

                        Stepper(value: binding(get: { store.profile.dailyReminderCount }, set: { value in
                            store.updateProfile { $0.dailyReminderCount = value }
                            notifier.scheduleReminders(profile: store.profile)
                        }), in: 3...12) {
                            Text("\(store.profile.dailyReminderCount) reminders/day")
                                .foregroundColor(.white)
                        }
                    }

                    section(title: "Permissions") {
                        Button("Request HealthKit Access") {
                            Task { await healthKit.requestAuthorization() }
                        }
                        .buttonStyle(.bordered)

                        Button("Request Location Access") {
                            locationManager.requestPermission()
                        }
                        .buttonStyle(.bordered)

                        Button("Request Notifications") {
                            Task { await notifier.requestAuthorization() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            manualTemp = store.activeWeather?.temperatureC ?? 22
            manualHumidity = store.activeWeather?.humidityPercent ?? 55
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
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
            .overlay(
                Text(title)
                    .font(Theme.titleFont(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.top, 10),
            alignment: .topLeading
        )
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
        notifier.scheduleReminders(profile: store.profile)
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
    }
}

#Preview("Settings") {
    PreviewEnvironment {
        SettingsView()
    }
}
