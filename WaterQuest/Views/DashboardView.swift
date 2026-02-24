import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HydrationStore
    @EnvironmentObject private var weather: WeatherClient
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var locationManager: LocationManager

    @StateObject private var aiService = HydrationAIService()

    @State private var entryToEdit: HydrationEntry?
    @State private var isRefreshing = false

    private var goal: GoalBreakdown { store.dailyGoal }
    private var progress: Double { min(1, store.todayTotalML / max(1, goal.totalML)) }

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .navigationTitle("Today")
        .refreshable {
            await refreshSignals()
        }
        .task {
            await refreshSignals()
            await generateAITip()
        }
        .task(id: locationManager.lastLocation?.timestamp) {
            guard store.profile.prefersWeatherGoal else { return }
            await refreshWeather()
        }
        .sheet(item: $entryToEdit) { entry in
            EntryEditorSheet(entry: entry, unitSystem: store.profile.unitSystem) { updatedAmount, updatedFluidType, updatedNote in
                store.updateEntry(
                    id: entry.id,
                    volumeML: store.profile.unitSystem.ml(from: updatedAmount),
                    fluidType: updatedFluidType,
                    note: updatedNote
                )
            } onDelete: {
                deleteEntry(entry)
            }
        }
    }

    // MARK: - Layouts

    private var iPhoneLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                summarySection
                    .padding(.top, 8)

                if let tip = aiService.currentTip {
                    DashboardCard(title: "Hydration Coach", icon: "sparkles") {
                        tipSection(tip)
                    }
                }

                if store.profile.prefersWeatherGoal {
                    DashboardCard(title: "Weather", icon: "cloud.sun.fill") {
                        weatherSection
                    }
                }

                DashboardCard(title: "Today's Activity", icon: "figure.run") {
                    activitySection
                }

                DashboardCard(title: "Today's Log", icon: "drop.fill") {
                    if todayEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "drop")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("No water logged yet.")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(todayEntries) { entry in
                                let fluidTypeTotal = todayEntries
                                    .filter { $0.fluidType == entry.fluidType }
                                    .reduce(0) { $0 + $1.effectiveML }
                                
                                Button {
                                    Haptics.selection()
                                    entryToEdit = entry
                                } label: {
                                    DetailedLogRow(
                                        entry: entry,
                                        unitSystem: store.profile.unitSystem,
                                        fluidTypeTotalML: fluidTypeTotal
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteEntry(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppWaterBackground().ignoresSafeArea())
    }

    private var iPadLayout: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary card spans full width
                HydrationSummaryCard(
                    greeting: greeting,
                    progress: progress,
                    todayTotalML: store.todayTotalML,
                    goalTotalML: goal.totalML,
                    compositions: store.todayCompositions,
                    unitSystem: store.profile.unitSystem
                )

                // Two columns: Coach (left), Weather + Activity (right)
                HStack(alignment: .top, spacing: 20) {
                    // Left column: Hydration Coach (larger)
                    VStack(spacing: 16) {
                        if let tip = aiService.currentTip {
                            DashboardCard(title: "Hydration Coach", icon: "sparkles") {
                                iPadTipSection(tip)
                            }
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)

                    // Right column: Weather + Activity
                    VStack(spacing: 16) {
                        if store.profile.prefersWeatherGoal {
                            DashboardCard(title: "Weather", icon: "cloud.sun.fill") {
                                weatherSection
                            }
                        }

                        DashboardCard(title: "Today\'s Activity", icon: "figure.run") {
                            activitySection
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                }

                // Full-width log at bottom
                DashboardCard(title: "Today\'s Log", icon: "drop.fill") {
                    if todayEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "drop")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("No water logged yet.")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        iPadLogGrid
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .background(AppWaterBackground().ignoresSafeArea())
    }

    private var iPadLogGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(todayEntries.enumerated()), id: \.element.id) { index, entry in
                let fluidTypeTotal = todayEntries
                    .filter { $0.fluidType == entry.fluidType }
                    .reduce(0) { $0 + $1.effectiveML }

                Button {
                    Haptics.selection()
                    entryToEdit = entry
                } label: {
                    DetailedLogRow(
                        entry: entry,
                        unitSystem: store.profile.unitSystem,
                        fluidTypeTotalML: fluidTypeTotal
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        deleteEntry(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var summarySection: some View {
        HydrationSummaryCard(
            greeting: greeting,
            progress: progress,
            todayTotalML: store.todayTotalML,
            goalTotalML: goal.totalML,
            compositions: store.todayCompositions,
            unitSystem: store.profile.unitSystem
        )
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    private func tipSection(_ tip: HydrationTip) -> some View {
        Button {
            Task {
                Haptics.selection()
                await generateAITip()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tip.category.icon)
                    .font(.title3)
                    .foregroundStyle(tip.category.color)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tip.message)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                    Text("Tap to refresh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if aiService.isGenerating {
                    ProgressView()
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func iPadTipSection(_ tip: HydrationTip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category header
            HStack(spacing: 10) {
                Image(systemName: tip.category.icon)
                    .font(.title2)
                    .foregroundStyle(tip.category.color)

                Text(tip.category.label)
                    .font(.headline)
                    .foregroundStyle(tip.category.color)

                Spacer()

                if aiService.isGenerating {
                    ProgressView()
                }
            }

            // Main message
            Text(tip.message)
                .font(.title3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Progress context
            VStack(alignment: .leading, spacing: 8) {
                let pct = Int(progress * 100)
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Theme.lagoon)
                    Text("\(pct)% of daily goal reached")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let temp = activeWeather?.temperatureC {
                    HStack(spacing: 6) {
                        Image(systemName: "thermometer.medium")
                            .foregroundStyle(Theme.coral)
                        Text("Current temperature: \(Int(temp))°C")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.lastWorkout.exerciseMinutes > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .foregroundStyle(Theme.sun)
                        Text("\(Int(store.lastWorkout.exerciseMinutes)) min of activity today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Refresh button
            Button {
                Task {
                    Haptics.selection()
                    await generateAITip()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Get new tip")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tip.category.color)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var weatherSection: some View {
        if let snapshot = activeWeather {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: weatherIcon(snapshot))
                        .font(.title)
                        .foregroundStyle(Theme.lagoon)
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.condition.isEmpty ? "Current weather" : snapshot.condition)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("\(Int(snapshot.temperatureC))°C • Humidity \(Int(snapshot.humidityPercent))%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Adj. Goal")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(Formatters.volumeString(ml: goal.totalML, unit: store.profile.unitSystem))
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Theme.lagoon)
                    }
                }
                
                // Apple Weather Attribution
                Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                    HStack(spacing: 4) {
                        Text("Weather data provided by")
                        Image(systemName: "applelogo")
                        Text("Weather")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.lagoon.opacity(0.8))
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Weather data unavailable")
                    .font(.subheadline.weight(.medium))
                Text(weatherMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activitySection: some View {
        let workout = store.lastWorkout
        let hasActivity = workout.exerciseMinutes > 0 || workout.activeEnergyKcal > 0

        return VStack(spacing: 14) {
            if hasActivity {
                HStack(spacing: 0) {
                    ActivityMetric(
                        icon: "figure.run",
                        value: "\(Int(workout.exerciseMinutes))",
                        label: "min",
                        tint: Theme.coral
                    )

                    Divider()
                        .frame(height: 36)
                        .padding(.horizontal, 12)

                    ActivityMetric(
                        icon: "flame.fill",
                        value: "\(Int(workout.activeEnergyKcal))",
                        label: "kcal",
                        tint: Theme.sun
                    )

                    if goal.workoutAdjustmentML > 0 {
                        Divider()
                            .frame(height: 36)
                            .padding(.horizontal, 12)

                        ActivityMetric(
                            icon: "drop.fill",
                            value: "+\(Formatters.shortVolume(ml: goal.workoutAdjustmentML, unit: store.profile.unitSystem))",
                            label: store.profile.unitSystem.volumeUnit,
                            tint: Theme.lagoon
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                if goal.workoutAdjustmentML > 0 {
                    Text("Goal adjusted for today\u{2019}s activity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundStyle(.quaternary)
                    Text("No workouts recorded today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    private var weatherMessage: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return "Enable Location access in Settings to personalize your hydration goal."
        default:
            return "Trying to load local weather. Your base goal still works without it."
        }
    }

    private var greeting: String {
        let firstName = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hour = Calendar.current.component(.hour, from: Date())

        let timeGreeting: String
        switch hour {
        case 5..<12:
            timeGreeting = "Good morning"
        case 12..<17:
            timeGreeting = "Good afternoon"
        case 17..<22:
            timeGreeting = "Good evening"
        default:
            timeGreeting = "Welcome back"
        }

        if firstName.isEmpty {
            return timeGreeting
        }
        return "\(timeGreeting), \(firstName)"
    }

    private var activeWeather: WeatherSnapshot? {
        weather.currentWeather ?? store.activeWeather
    }

    private var todayEntries: [HydrationEntry] {
        store.todayEntries.sorted { $0.date > $1.date }
    }

    private func weatherIcon(_ snapshot: WeatherSnapshot) -> String {
        if snapshot.conditionKey.isEmpty {
            return "cloud.sun"
        }
        return WeatherSnapshot.sfSymbol(for: snapshot.conditionKey)
    }

    private func deleteEntry(_ entry: HydrationEntry) {
        Haptics.impact(.medium)
        if entry.source == .manual {
            Task {
                await healthKit.deleteWaterIntake(entryID: entry.id)
            }
        }
        store.deleteEntry(entry)
    }

    private func refreshSignals() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if store.profile.prefersHealthKit {
            await healthKit.refreshAuthorizationStatus()
            let summary = await healthKit.fetchTodayWorkoutSummary()
            store.updateWorkout(summary)
            if let entries = await healthKit.fetchRecentWaterEntries(days: 7) {
                store.syncHealthKitEntriesRange(entries, days: 7)
            }
        }

        if store.profile.prefersWeatherGoal {
            await refreshWeather()
        }
    }

    private func refreshWeather() async {
        await weather.refresh()
        if let snapshot = weather.currentWeather {
            store.updateWeather(snapshot)
        } else if locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }

    private func generateAITip() async {
        await aiService.generateTip(
            currentIntake: store.todayTotalML,
            goalML: goal.totalML,
            weatherTemp: activeWeather?.temperatureC,
            exerciseMinutes: Int(store.lastWorkout.exerciseMinutes),
            timeOfDay: TimeOfDay.current
        )
    }

}

private struct HydrationSummaryCard: View {
    let greeting: String
    let progress: Double
    let todayTotalML: Double
    let goalTotalML: Double
    let compositions: [FluidComposition]
    let unitSystem: UnitSystem

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(spacing: isRegular ? 28 : 24) {
            
            // Header Text Area
            HStack {
                VStack(alignment: .leading, spacing: isRegular ? 8 : 6) {
                    Text(greeting)
                        .font(.system(isRegular ? .title : .title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Formatters.volumeString(ml: todayTotalML, unit: unitSystem))
                            .font(.system(isRegular ? .title2 : .title3, design: .rounded).weight(.heavy))
                            .foregroundStyle(Theme.lagoon)
                        Text("of \(Formatters.volumeString(ml: goalTotalML, unit: unitSystem)) today")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.top, 4)
                }
                Spacer()
            }

            // Big Centered Layout
            LiquidProgressView(
                progress: progress,
                compositions: compositions,
                isRegular: isRegular
            )
        }
        .padding(isRegular ? 24 : 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Theme.shadowColor.opacity(0.6), radius: 15, x: 0, y: 8)
    }
}

private struct LogRow: View {
    let entry: HydrationEntry
    let unitSystem: UnitSystem

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.fluidType.iconName)
                .foregroundStyle(entry.fluidType.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(Formatters.volumeString(ml: entry.volumeML, unit: unitSystem))
                        .font(.body)
                    if entry.fluidType != .water {
                        Text(entry.fluidType.displayName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(entry.fluidType.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(entry.fluidType.color.opacity(0.1))
                            )
                    }
                }
                if entry.fluidType != .water {
                    Text("Effective: \(Formatters.volumeString(ml: entry.effectiveML, unit: unitSystem))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(Self.formatter.string(from: entry.date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct EntryEditorSheet: View {
    let entry: HydrationEntry
    let unitSystem: UnitSystem
    let onSave: (_ amount: Double, _ fluidType: FluidType, _ note: String?) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double
    @State private var selectedFluidType: FluidType
    @State private var note: String
    @State private var showDeleteConfirm = false

    init(
        entry: HydrationEntry,
        unitSystem: UnitSystem,
        onSave: @escaping (_ amount: Double, _ fluidType: FluidType, _ note: String?) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.entry = entry
        self.unitSystem = unitSystem
        self.onSave = onSave
        self.onDelete = onDelete
        _amount = State(initialValue: unitSystem.amount(fromML: entry.volumeML))
        _selectedFluidType = State(initialValue: entry.fluidType)
        _note = State(initialValue: entry.note ?? "")
    }

    private var amountRange: ClosedRange<Double> {
        unitSystem == .metric ? 100...1200 : 4...40
    }

    private var amountStep: Double {
        unitSystem == .metric ? 25 : 1
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        Text("\(Int(amount)) \(unitSystem.volumeUnit)")
                            .font(.headline)
                        Spacer()
                    }
                    Slider(value: $amount, in: amountRange, step: amountStep)
                        .tint(selectedFluidType.color)
                }

                Section("Beverage") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FluidType.allCases) { type in
                                Button {
                                    Haptics.selection()
                                    selectedFluidType = type
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: type.iconName)
                                            .font(.title3)
                                            .foregroundStyle(selectedFluidType == type ? .white : type.color)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                Circle()
                                                    .fill(selectedFluidType == type ? type.color : type.color.opacity(0.12))
                                            )
                                        Text(type.displayName)
                                            .font(.caption2)
                                            .foregroundStyle(selectedFluidType == type ? .primary : .secondary)
                                            .lineLimit(1)
                                            .frame(width: 60)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if selectedFluidType != .water {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("\(selectedFluidType.displayName) counts as \(selectedFluidType.hydrationLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Button("Save") {
                        Haptics.impact(.medium)
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(amount, selectedFluidType, trimmed.isEmpty ? nil : trimmed)
                        dismiss()
                    }
                }

                Section {
                    Button("Delete Entry", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

private struct ActivityMetric: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DetailedLogRow: View {
    let entry: HydrationEntry
    let unitSystem: UnitSystem
    let fluidTypeTotalML: Double

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(entry.fluidType.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: entry.fluidType.iconName)
                    .font(.title3)
                    .foregroundStyle(entry.fluidType.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(Formatters.volumeString(ml: entry.volumeML, unit: unitSystem))
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))

                    Text(entry.fluidType.displayName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(entry.fluidType.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(entry.fluidType.color.opacity(0.15))
                        )
                }

                if entry.fluidType != .water {
                    Text("Effective: \(Formatters.volumeString(ml: entry.effectiveML, unit: unitSystem))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text(Self.formatter.string(from: entry.date))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)

                    if let note = entry.note, !note.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            // Fluid type total
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.volumeString(ml: fluidTypeTotalML, unit: unitSystem))
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                Text("\(entry.fluidType.displayName) today")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
    }
}


#if DEBUG
#Preview("Dashboard") {
    PreviewEnvironment {
        DashboardView()
    }
}
#endif
