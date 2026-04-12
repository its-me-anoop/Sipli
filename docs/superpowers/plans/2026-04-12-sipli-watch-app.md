# Sipli Watch App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a watchOS 11 companion app for Sipli with glanceable progress, quick intake logging, complications, interactive widgets, and haptic reminders.

**Architecture:** Shared App Group + iCloud KVStore sync (same mechanism as existing widget). Extract shared models/services into a cross-target group. Watch gets its own `WatchHydrationStore` that reads/writes via the shared `PersistenceService`.

**Tech Stack:** SwiftUI (watchOS), WidgetKit, AppIntents, HealthKit, WatchKit haptics

---

## File Structure

### Shared code (add to new "Shared" group, included in iPhone + Watch + Widget targets)

| File | Responsibility |
|------|---------------|
| `WaterQuest/Models/HydrationEntry.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Models/UserProfile.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Models/FluidType.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Models/GoalBreakdown.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Models/PersistedState.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Models/WeatherSnapshot.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Models/WorkoutSummary.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Models/UnitSystem.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Services/PersistenceService.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Services/GoalCalculator.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Services/Formatters.swift` | Already exists — add to Watch target membership |
| `WaterQuest/Services/DateExtensions.swift` | Already exists — add to Watch target membership |

### New Watch app files

| File | Responsibility |
|------|---------------|
| `SipliWatch/SipliWatchApp.swift` | Watch app entry point |
| `SipliWatch/WatchHydrationStore.swift` | Watch-scoped state management |
| `SipliWatch/WatchHaptics.swift` | watchOS-specific haptic feedback (WKInterfaceDevice) |
| `SipliWatch/Views/WatchDashboardView.swift` | Main screen: progress ring + stats + add button |
| `SipliWatch/Views/WatchQuickAddView.swift` | Amount picker with Digital Crown |
| `SipliWatch/Views/WatchFluidPickerView.swift` | Top 6 fluid type selector |
| `SipliWatch/Views/WatchTodayLogView.swift` | Today's entry list (inline below dashboard) |
| `SipliWatch/Views/WatchProgressRing.swift` | Simplified progress ring for Watch |
| `SipliWatch/Complications/SipliWatchWidget.swift` | Complications (circular + corner gauge) |
| `SipliWatch/Complications/WatchQuickAddIntent.swift` | Interactive widget intent for quick-add |
| `SipliWatch/Assets.xcassets` | Watch app icon + colors |
| `SipliWatch/Info.plist` | Watch app manifest |

### Modified iPhone files

| File | Change |
|------|--------|
| `WaterQuest/Models/HydrationEntry.swift` | Add `.watchManual` to `HydrationSource` enum |

---

## Task 1: Add `.watchManual` source to HydrationEntry

**Files:**
- Modify: `WaterQuest/Models/HydrationEntry.swift:3-6`

- [ ] **Step 1: Add the new source case**

In `WaterQuest/Models/HydrationEntry.swift`, add `.watchManual` to the `HydrationSource` enum:

```swift
enum HydrationSource: String, Codable {
    case manual
    case healthKit
    case watchManual
}
```

This is backward-compatible since `Codable` decoding uses raw string values, and existing JSON won't contain `"watchManual"`.

- [ ] **Step 2: Build iPhone target to verify no regressions**

Run: Build the `WaterQuest` scheme for iPhone simulator.
Expected: Build succeeds. No exhaustive switch issues since HydrationSource isn't switched on directly.

- [ ] **Step 3: Commit**

```
git add WaterQuest/Models/HydrationEntry.swift
git commit -m "feat: add watchManual source to HydrationSource enum"
```

---

## Task 2: Create watchOS target in Xcode project

**Files:**
- Create: `SipliWatch/` directory
- Create: `SipliWatch/SipliWatchApp.swift`
- Create: `SipliWatch/Assets.xcassets`
- Create: `SipliWatch/Info.plist`
- Modify: `WaterQuest.xcodeproj/project.pbxproj` (via Xcode)

- [ ] **Step 1: Add watchOS target via Xcode**

In Xcode:
1. File → New → Target → watchOS → App
2. Product Name: `SipliWatch`
3. Bundle Identifier: `com.waterquest.hydration.watchapp`
4. Interface: SwiftUI
5. Language: Swift
6. Deployment Target: watchOS 11.0
7. Embed in: WaterQuest (companion app)

- [ ] **Step 2: Configure App Group entitlement**

Create `SipliWatch/SipliWatch.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.waterquest.hydration</string>
    </array>
</dict>
</plist>
```

In Xcode → SipliWatch target → Signing & Capabilities → Add "App Groups" → select `group.com.waterquest.hydration`.

- [ ] **Step 3: Add HealthKit capability**

In Xcode → SipliWatch target → Signing & Capabilities → Add "HealthKit".

- [ ] **Step 4: Add shared file memberships**

In Xcode, select each of these files and add them to the `SipliWatch` target membership (checkbox in File Inspector):

- `WaterQuest/Models/HydrationEntry.swift`
- `WaterQuest/Models/UserProfile.swift`
- `WaterQuest/Models/FluidType.swift`
- `WaterQuest/Models/GoalBreakdown.swift`
- `WaterQuest/Models/PersistedState.swift`
- `WaterQuest/Models/WeatherSnapshot.swift`
- `WaterQuest/Models/WorkoutSummary.swift`
- `WaterQuest/Models/UnitSystem.swift`
- `WaterQuest/Services/PersistenceService.swift`
- `WaterQuest/Services/GoalCalculator.swift`
- `WaterQuest/Services/Formatters.swift`
- `WaterQuest/Services/DateExtensions.swift`

- [ ] **Step 5: Write minimal app entry point**

Replace `SipliWatch/SipliWatchApp.swift` with:

```swift
import SwiftUI

@main
struct SipliWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Sipli")
        }
    }
}
```

- [ ] **Step 6: Build Watch target**

Run: Build `SipliWatch` scheme for Apple Watch simulator.
Expected: Build succeeds with a blank "Sipli" text on screen.

- [ ] **Step 7: Commit**

```
git add -A
git commit -m "feat: add SipliWatch watchOS target with shared file memberships"
```

---

## Task 3: WatchHaptics — watchOS-specific haptic feedback

**Files:**
- Create: `SipliWatch/WatchHaptics.swift`

- [ ] **Step 1: Create WatchHaptics**

Create `SipliWatch/WatchHaptics.swift`:

```swift
import WatchKit

enum WatchHaptics {
    static func success() {
        WKInterfaceDevice.current().play(.success)
    }

    static func goalReached() {
        WKInterfaceDevice.current().play(.notification)
    }

    static func reminder() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    static func click() {
        WKInterfaceDevice.current().play(.click)
    }
}
```

- [ ] **Step 2: Build**

Run: Build `SipliWatch` scheme.
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```
git add SipliWatch/WatchHaptics.swift
git commit -m "feat: add WatchHaptics with watchOS-specific haptic patterns"
```

---

## Task 4: WatchHydrationStore — Watch-scoped state management

**Files:**
- Create: `SipliWatch/WatchHydrationStore.swift`

- [ ] **Step 1: Create WatchHydrationStore**

Create `SipliWatch/WatchHydrationStore.swift`:

```swift
import Foundation
import Combine

@MainActor
final class WatchHydrationStore: ObservableObject {
    @Published var entries: [HydrationEntry] = []
    @Published var profile: UserProfile = .default
    @Published var goalBreakdown: GoalBreakdown = GoalBreakdown(baseML: 2450, weatherAdjustmentML: 0, workoutAdjustmentML: 0, totalML: 2450)
    @Published var hasPremiumAccess: Bool = false

    private let persistence = PersistenceService()

    init() {
        loadState()
        persistence.setRemoteDataChangeHandler { [weak self] _ in
            Task { @MainActor in
                self?.loadState()
            }
        }
    }

    // MARK: - Computed Properties

    var todayEntries: [HydrationEntry] {
        let startOfDay = Date().startOfDay
        return entries.filter { $0.date >= startOfDay }
    }

    var todayTotalML: Double {
        todayEntries.reduce(0) { $0 + $1.effectiveML }
    }

    var todayDrinkCount: Int {
        todayEntries.count
    }

    var progress: Double {
        guard goalBreakdown.totalML > 0 else { return 0 }
        return min(todayTotalML / goalBreakdown.totalML, 1.0)
    }

    var remainingML: Double {
        max(goalBreakdown.totalML - todayTotalML, 0)
    }

    var topFluidTypes: [FluidType] {
        let counts = Dictionary(grouping: entries, by: \.fluidType)
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map(\.key)

        if counts.isEmpty {
            return [.water, .coffee, .greenTea, .sparklingWater, .juice, .milk]
        }
        return Array(counts)
    }

    // MARK: - Actions

    func addIntake(volumeML: Double, fluidType: FluidType = .water) {
        let entry = HydrationEntry(
            date: Date(),
            volumeML: volumeML,
            source: .watchManual,
            fluidType: fluidType
        )
        entries.append(entry)
        saveState()
    }

    func deleteEntry(_ entry: HydrationEntry) {
        entries.removeAll { $0.id == entry.id }
        saveState()
    }

    // MARK: - Persistence

    func loadState() {
        let state = persistence.load(PersistedState.self, fallback: .default)
        entries = state.entries
        profile = state.profile
        hasPremiumAccess = state.hasPremiumAccess

        let weather = state.profile.prefersWeatherGoal ? state.lastWeather : nil
        let workout = state.profile.prefersHealthKit ? state.lastWorkout : nil
        goalBreakdown = GoalCalculator.dailyGoal(
            profile: state.profile,
            weather: weather,
            workout: workout
        )
    }

    private func saveState() {
        var state = persistence.load(PersistedState.self, fallback: .default)
        state.entries = entries
        persistence.save(state)
    }
}
```

- [ ] **Step 2: Build**

Run: Build `SipliWatch` scheme.
Expected: Build succeeds. The store compiles against shared models and PersistenceService.

- [ ] **Step 3: Commit**

```
git add SipliWatch/WatchHydrationStore.swift
git commit -m "feat: add WatchHydrationStore with shared persistence"
```

---

## Task 5: WatchProgressRing — Simplified progress ring

**Files:**
- Create: `SipliWatch/Views/WatchProgressRing.swift`

- [ ] **Step 1: Create WatchProgressRing**

Create `SipliWatch/Views/WatchProgressRing.swift`:

```swift
import SwiftUI

struct WatchProgressRing: View {
    let progress: Double
    let currentML: Double
    let goalML: Double
    let unitSystem: UnitSystem

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        colors: [Color(red: 0.11, green: 0.47, blue: 0.96), Color(red: 0.19, green: 0.76, blue: 0.64)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.86), value: progress)

            // Center text
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(Formatters.shortVolume(ml: currentML, unit: unitSystem)) / \(Formatters.shortVolume(ml: goalML, unit: unitSystem))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 2: Build**

Run: Build `SipliWatch` scheme.
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```
git add SipliWatch/Views/WatchProgressRing.swift
git commit -m "feat: add WatchProgressRing component"
```

---

## Task 6: WatchDashboardView — Main screen

**Files:**
- Create: `SipliWatch/Views/WatchDashboardView.swift`

- [ ] **Step 1: Create WatchDashboardView**

Create `SipliWatch/Views/WatchDashboardView.swift`:

```swift
import SwiftUI

struct WatchDashboardView: View {
    @EnvironmentObject private var store: WatchHydrationStore
    @State private var showQuickAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                WatchProgressRing(
                    progress: store.progress,
                    currentML: store.todayTotalML,
                    goalML: store.goalBreakdown.totalML,
                    unitSystem: store.profile.unitSystem
                )
                .frame(width: 120, height: 120)
                .padding(.top, 4)

                // Stats pills
                HStack(spacing: 8) {
                    StatPill(icon: "drop.fill", text: "\(store.todayDrinkCount) drinks")
                    StatPill(
                        icon: "target",
                        text: "\(Formatters.shortVolume(ml: store.remainingML, unit: store.profile.unitSystem)) left"
                    )
                }

                // Add Water button
                Button {
                    showQuickAdd = true
                } label: {
                    Label("Add Water", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.11, green: 0.47, blue: 0.96))

                // Today's log inline
                WatchTodayLogView()
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            WatchQuickAddView()
        }
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color(red: 0.11, green: 0.47, blue: 0.96).opacity(0.9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(red: 0.11, green: 0.47, blue: 0.96).opacity(0.15), in: Capsule())
    }
}
```

- [ ] **Step 2: Build**

Run: Build `SipliWatch` scheme.
Expected: Build succeeds (WatchTodayLogView and WatchQuickAddView not yet created — will cause build error). Proceed to Task 7 and 8 first, then build.

- [ ] **Step 3: Commit (after Tasks 7-8)**

Commit together with Tasks 7 and 8.

---

## Task 7: WatchTodayLogView — Today's entry list

**Files:**
- Create: `SipliWatch/Views/WatchTodayLogView.swift`

- [ ] **Step 1: Create WatchTodayLogView**

Create `SipliWatch/Views/WatchTodayLogView.swift`:

```swift
import SwiftUI

struct WatchTodayLogView: View {
    @EnvironmentObject private var store: WatchHydrationStore

    var body: some View {
        if store.todayEntries.isEmpty {
            Text("No drinks logged yet today")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            VStack(spacing: 4) {
                Text("Today's Log")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(store.todayEntries.sorted(by: { $0.date > $1.date })) { entry in
                    WatchEntryRow(entry: entry, unitSystem: store.profile.unitSystem)
                }
                .onDelete { offsets in
                    let sorted = store.todayEntries.sorted(by: { $0.date > $1.date })
                    for offset in offsets {
                        store.deleteEntry(sorted[offset])
                    }
                }
            }
        }
    }
}

// MARK: - Entry Row

private struct WatchEntryRow: View {
    let entry: HydrationEntry
    let unitSystem: UnitSystem

    var body: some View {
        HStack {
            Image(systemName: entry.fluidType.iconName)
                .font(.system(size: 14))
                .foregroundStyle(entry.fluidType.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.fluidType.displayName)
                    .font(.system(size: 12, weight: .medium))
                Text("\(Formatters.shortVolume(ml: entry.volumeML, unit: unitSystem)) · \(entry.date.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 2: Proceed to Task 8**

---

## Task 8: WatchQuickAddView + WatchFluidPickerView — Intake logging

**Files:**
- Create: `SipliWatch/Views/WatchQuickAddView.swift`
- Create: `SipliWatch/Views/WatchFluidPickerView.swift`

- [ ] **Step 1: Create WatchQuickAddView**

Create `SipliWatch/Views/WatchQuickAddView.swift`:

```swift
import SwiftUI

struct WatchQuickAddView: View {
    @EnvironmentObject private var store: WatchHydrationStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAmountIndex: Int = 2  // Default 250ml
    @State private var selectedFluidType: FluidType = .water
    @State private var showFluidPicker = false
    @State private var logged = false

    private let amounts: [Double] = [150, 200, 250, 330, 500, 750]

    private var displayAmount: String {
        Formatters.shortVolume(ml: amounts[selectedAmountIndex], unit: store.profile.unitSystem)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Add \(selectedFluidType.displayName)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text(displayAmount)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .focusable()
                .digitalCrownRotation(
                    $selectedAmountIndex,
                    from: 0,
                    through: amounts.count - 1,
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

            Button {
                store.addIntake(volumeML: amounts[selectedAmountIndex], fluidType: selectedFluidType)
                WatchHaptics.success()
                logged = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            } label: {
                Label("Log \(selectedFluidType == .water ? "Water" : selectedFluidType.displayName)", systemImage: "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.11, green: 0.47, blue: 0.96))
            .disabled(logged)

            Button {
                showFluidPicker = true
            } label: {
                Text("More beverages")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.11, green: 0.47, blue: 0.96))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showFluidPicker) {
            WatchFluidPickerView(selectedFluidType: $selectedFluidType)
        }
    }
}
```

- [ ] **Step 2: Create WatchFluidPickerView**

Create `SipliWatch/Views/WatchFluidPickerView.swift`:

```swift
import SwiftUI

struct WatchFluidPickerView: View {
    @EnvironmentObject private var store: WatchHydrationStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFluidType: FluidType

    var body: some View {
        List(store.topFluidTypes, id: \.self) { fluidType in
            Button {
                selectedFluidType = fluidType
                WatchHaptics.click()
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: fluidType.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(fluidType.color)
                    Text(fluidType.displayName)
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    if fluidType == selectedFluidType {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0.11, green: 0.47, blue: 0.96))
                    }
                }
            }
        }
        .navigationTitle("Beverage")
    }
}
```

- [ ] **Step 3: Build all Watch views**

Run: Build `SipliWatch` scheme.
Expected: Build succeeds. All views compile against shared models.

- [ ] **Step 4: Commit Tasks 6-8 together**

```
git add SipliWatch/Views/
git commit -m "feat: add Watch dashboard, quick add, fluid picker, and today's log views"
```

---

## Task 9: Wire up the Watch app entry point

**Files:**
- Modify: `SipliWatch/SipliWatchApp.swift`

- [ ] **Step 1: Update SipliWatchApp with state management**

Replace `SipliWatch/SipliWatchApp.swift` with:

```swift
import SwiftUI

@main
struct SipliWatchApp: App {
    @StateObject private var store = WatchHydrationStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.loadState()
            }
        }
    }
}
```

- [ ] **Step 2: Build and run on Watch simulator**

Run: Build and run `SipliWatch` scheme on Apple Watch simulator.
Expected: Watch app launches, shows dashboard with progress ring (0% if no entries), stats pills, and Add Water button. Tapping Add Water opens the quick add sheet.

- [ ] **Step 3: Commit**

```
git add SipliWatch/SipliWatchApp.swift
git commit -m "feat: wire up SipliWatchApp with WatchHydrationStore"
```

---

## Task 10: Watch Complications (WidgetKit)

**Files:**
- Create: `SipliWatch/Complications/SipliWatchWidget.swift`

- [ ] **Step 1: Create complications**

Create `SipliWatch/Complications/SipliWatchWidget.swift`:

```swift
import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct WatchTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchWidgetEntry {
        WatchWidgetEntry(date: Date(), progress: 0.65, currentML: 1560, goalML: 2400, unitSystem: .metric)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> WatchWidgetEntry {
        let persistence = PersistenceService()
        let state = persistence.load(PersistedState.self, fallback: .default)

        let todayEntries = state.entries.filter { $0.date >= Date().startOfDay }
        let totalML = todayEntries.reduce(0.0) { $0 + $1.effectiveML }

        let weather = state.profile.prefersWeatherGoal ? state.lastWeather : nil
        let workout = state.profile.prefersHealthKit ? state.lastWorkout : nil
        let goal = GoalCalculator.dailyGoal(profile: state.profile, weather: weather, workout: workout)

        let progress = goal.totalML > 0 ? min(totalML / goal.totalML, 1.0) : 0

        return WatchWidgetEntry(
            date: Date(),
            progress: progress,
            currentML: totalML,
            goalML: goal.totalML,
            unitSystem: state.profile.unitSystem
        )
    }
}

// MARK: - Entry

struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let progress: Double
    let currentML: Double
    let goalML: Double
    let unitSystem: UnitSystem
}

// MARK: - Complication Views

struct CircularComplicationView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "drop.fill")
                .foregroundStyle(Color(red: 0.11, green: 0.47, blue: 0.96))
        } currentValueLabel: {
            Text("\(Int(entry.progress * 100))")
                .font(.system(size: 14, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [
            Color(red: 0.11, green: 0.47, blue: 0.96),
            Color(red: 0.19, green: 0.76, blue: 0.64)
        ]))
    }
}

struct CornerComplicationView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        Text("\(Int(entry.progress * 100))%")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color(red: 0.11, green: 0.47, blue: 0.96))
            .widgetLabel {
                Gauge(value: entry.progress) {
                    Text("Hydration")
                } currentValueLabel: {
                    Text("\(Int(entry.progress * 100))%")
                }
                .tint(Color(red: 0.11, green: 0.47, blue: 0.96))
                .gaugeStyle(.accessoryLinear)
            }
    }
}

// MARK: - Unified Entry View

struct SipliWatchComplicationView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: WatchWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        default:
            CircularComplicationView(entry: entry)
        }
    }
}

// MARK: - Widget (part of Watch app target, no @main — Watch app owns @main)

struct SipliWatchComplication: Widget {
    let kind = "SipliWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchTimelineProvider()) { entry in
            SipliWatchComplicationView(entry: entry)
        }
        .configurationDisplayName("Sipli Hydration")
        .description("Track your daily hydration progress.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}
```

**Note:** This widget is part of the Watch app target directly (watchOS 10+ supports this). No separate widget extension needed. The `@main` stays on `SipliWatchApp`. We register the widget via a `WidgetBundle` in the app entry point (see Task 11).

- [ ] **Step 2: Build**

Run: Build `SipliWatch` scheme.
Expected: Build succeeds with complications registered.

- [ ] **Step 3: Commit**

```
git add SipliWatch/Complications/
git commit -m "feat: add Watch complications (circular progress + corner gauge)"
```

---

## Task 11: Interactive Quick-Add Widget Intent

**Files:**
- Create: `SipliWatch/Complications/WatchQuickAddIntent.swift`

- [ ] **Step 1: Create WatchQuickAddIntent**

Create `SipliWatch/Complications/WatchQuickAddIntent.swift`:

```swift
import AppIntents
import WidgetKit

struct WatchQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Quickly log 250ml of water from the Watch.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let persistence = PersistenceService()
        var state = persistence.load(PersistedState.self, fallback: .default)

        let entry = HydrationEntry(
            date: Date(),
            volumeML: 250,
            source: .watchManual,
            fluidType: .water
        )

        state.entries.append(entry)
        persistence.save(state)
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
```

- [ ] **Step 2: Add interactive widget to complication file**

Add the following to `SipliWatch/Complications/SipliWatchWidget.swift`, as an additional widget in a `WidgetBundle`:

```swift
struct SipliQuickAddWidget: Widget {
    let kind = "SipliQuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchTimelineProvider()) { entry in
            QuickAddWidgetView(entry: entry)
        }
        .configurationDisplayName("Sipli Quick Add")
        .description("Tap to log 250ml of water.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct QuickAddWidgetView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(entry.progress * 100))%")
                    .font(.system(size: 20, weight: .bold))
                Text(Formatters.shortVolume(ml: entry.currentML, unit: entry.unitSystem))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(intent: WatchQuickAddIntent()) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(red: 0.11, green: 0.47, blue: 0.96))
            }
            .buttonStyle(.plain)
        }
    }
}
```

Register both widgets in `SipliWatch/SipliWatchApp.swift` by adding an `additionalScenes` modifier. Update the app entry point to include widget registration:

In `SipliWatchApp`, add the widget scene after `WindowGroup`:

```swift
@main
struct SipliWatchApp: App {
    @StateObject private var store = WatchHydrationStore()
    @StateObject private var healthKit = WatchHealthKitManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environmentObject(store)
                .task {
                    store.healthKitManager = healthKit
                    await healthKit.requestAuthorization()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.loadState()
            }
        }
    }
}
```

The widgets (`SipliWatchComplication` and `SipliQuickAddWidget`) are automatically discovered by WidgetKit as long as they conform to the `Widget` protocol and are compiled into the Watch app target.

- [ ] **Step 3: Build and test**

Run: Build `SipliWatch` scheme.
Expected: Build succeeds. Interactive widget shows progress + tap-to-add button.

- [ ] **Step 4: Commit**

```
git add SipliWatch/Complications/
git commit -m "feat: add interactive quick-add widget with WatchQuickAddIntent"
```

---

## Task 12: Watch HealthKit integration

**Files:**
- Create: `SipliWatch/WatchHealthKitManager.swift`

- [ ] **Step 1: Create WatchHealthKitManager**

Create `SipliWatch/WatchHealthKitManager.swift`:

```swift
import HealthKit

@MainActor
final class WatchHealthKitManager: ObservableObject {
    @Published var isAuthorized = false

    private let healthStore = HKHealthStore()
    private let waterType = HKQuantityType(.dietaryWater)

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isAvailable else { return }

        let typesToWrite: Set<HKSampleType> = [waterType]
        let typesToRead: Set<HKObjectType> = [waterType]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            isAuthorized = healthStore.authorizationStatus(for: waterType) == .sharingAuthorized
        } catch {
            #if DEBUG
            print("Watch HealthKit authorization failed: \(error)")
            #endif
        }
    }

    func logWaterIntake(ml: Double) async {
        guard isAuthorized else { return }

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())

        do {
            try await healthStore.save(sample)
        } catch {
            #if DEBUG
            print("Watch HealthKit save failed: \(error)")
            #endif
        }
    }
}
```

- [ ] **Step 2: Integrate with WatchHydrationStore**

In `SipliWatch/WatchHydrationStore.swift`, add HealthKit logging after `addIntake`:

Add a property:

```swift
var healthKitManager: WatchHealthKitManager?
```

Update `addIntake` to also log to HealthKit:

```swift
func addIntake(volumeML: Double, fluidType: FluidType = .water) {
    let entry = HydrationEntry(
        date: Date(),
        volumeML: volumeML,
        source: .watchManual,
        fluidType: fluidType
    )
    entries.append(entry)
    saveState()

    // Also log to HealthKit
    if let hk = healthKitManager, hk.isAuthorized {
        Task {
            await hk.logWaterIntake(ml: volumeML)
        }
    }
}
```

- [ ] **Step 3: Wire HealthKit into SipliWatchApp**

Update `SipliWatch/SipliWatchApp.swift`:

```swift
import SwiftUI

@main
struct SipliWatchApp: App {
    @StateObject private var store = WatchHydrationStore()
    @StateObject private var healthKit = WatchHealthKitManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environmentObject(store)
                .task {
                    store.healthKitManager = healthKit
                    await healthKit.requestAuthorization()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.loadState()
            }
        }
    }
}
```

- [ ] **Step 4: Build**

Run: Build `SipliWatch` scheme.
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```
git add SipliWatch/WatchHealthKitManager.swift SipliWatch/WatchHydrationStore.swift SipliWatch/SipliWatchApp.swift
git commit -m "feat: add Watch HealthKit integration for water intake logging"
```

---

## Task 13: Goal-reached celebration

**Files:**
- Modify: `SipliWatch/WatchHydrationStore.swift`
- Modify: `SipliWatch/Views/WatchDashboardView.swift`

- [ ] **Step 1: Add goal-reached detection to store**

In `WatchHydrationStore`, add a published property and detection logic:

```swift
@Published var justReachedGoal: Bool = false

func addIntake(volumeML: Double, fluidType: FluidType = .water) {
    let wasBelow = todayTotalML < goalBreakdown.totalML

    let entry = HydrationEntry(
        date: Date(),
        volumeML: volumeML,
        source: .watchManual,
        fluidType: fluidType
    )
    entries.append(entry)
    saveState()

    // Check if we just crossed the goal threshold
    if wasBelow && todayTotalML >= goalBreakdown.totalML {
        justReachedGoal = true
        WatchHaptics.goalReached()
    }

    if let hk = healthKitManager, hk.isAuthorized {
        Task {
            await hk.logWaterIntake(ml: volumeML)
        }
    }
}
```

- [ ] **Step 2: Add celebration overlay to dashboard**

In `WatchDashboardView`, add an overlay that shows briefly when the goal is reached:

```swift
.overlay {
    if store.justReachedGoal {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 32))
                .foregroundStyle(.yellow)
            Text("Goal Reached!")
                .font(.system(size: 16, weight: .bold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    store.justReachedGoal = false
                }
            }
        }
        .transition(.opacity)
    }
}
.animation(.easeInOut, value: store.justReachedGoal)
```

- [ ] **Step 3: Build and run**

Run: Build and run `SipliWatch` on Watch simulator.
Expected: Logging water that crosses the goal threshold shows a trophy celebration with haptic.

- [ ] **Step 4: Commit**

```
git add SipliWatch/WatchHydrationStore.swift SipliWatch/Views/WatchDashboardView.swift
git commit -m "feat: add goal-reached celebration with haptic and overlay"
```

---

## Task 14: Watch app icon and metadata

**Files:**
- Modify: `SipliWatch/Assets.xcassets`
- Modify: `SipliWatch/Info.plist`

- [ ] **Step 1: Add Watch app icon**

Copy the existing Sipli app icon from `WaterQuest/Assets.xcassets/AppIcon.appiconset/` and resize for watchOS sizes. Place in `SipliWatch/Assets.xcassets/AppIcon.appiconset/`. watchOS requires a single 1024x1024 icon; Xcode generates all sizes.

- [ ] **Step 2: Set Watch Info.plist**

Ensure `SipliWatch/Info.plist` contains:

```xml
<key>WKApplication</key>
<true/>
<key>CFBundleDisplayName</key>
<string>Sipli</string>
```

- [ ] **Step 3: Build**

Run: Build `SipliWatch` scheme.
Expected: Build succeeds. App icon appears on watch simulator home screen.

- [ ] **Step 4: Commit**

```
git add SipliWatch/
git commit -m "feat: add Watch app icon and metadata"
```

---

## Task 15: Notification action — "Log 250ml" inline button

**Files:**
- Create: `SipliWatch/WatchNotificationHandler.swift`
- Modify: `SipliWatch/SipliWatchApp.swift`

- [ ] **Step 1: Define notification category and action**

Create `SipliWatch/WatchNotificationHandler.swift`:

```swift
import UserNotifications

enum WatchNotificationHandler {
    static let categoryIdentifier = "HYDRATION_REMINDER"
    static let logActionIdentifier = "LOG_WATER_ACTION"

    static func registerCategories() {
        let logAction = UNNotificationAction(
            identifier: logActionIdentifier,
            title: "Log 250ml 💧",
            options: .foreground
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [logAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func handleAction(identifier: String, store: WatchHydrationStore) {
        if identifier == logActionIdentifier {
            store.addIntake(volumeML: 250, fluidType: .water)
            WatchHaptics.success()
        }
    }
}
```

- [ ] **Step 2: Wire into app delegate**

Update `SipliWatch/SipliWatchApp.swift` to register categories and handle notification responses. Add a `WKApplicationDelegateAdaptor`:

```swift
import SwiftUI
import WatchKit
import UserNotifications

final class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    var store: WatchHydrationStore?

    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = self
        WatchNotificationHandler.registerCategories()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let store {
            WatchNotificationHandler.handleAction(identifier: response.actionIdentifier, store: store)
        }
    }
}

@main
struct SipliWatchApp: App {
    @WKApplicationDelegateAdaptor private var appDelegate: WatchAppDelegate
    @StateObject private var store = WatchHydrationStore()
    @StateObject private var healthKit = WatchHealthKitManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environmentObject(store)
                .task {
                    appDelegate.store = store
                    store.healthKitManager = healthKit
                    await healthKit.requestAuthorization()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.loadState()
            }
        }
    }
}
```

- [ ] **Step 3: Update iPhone NotificationScheduler to use the category**

In the iPhone app's `NotificationScheduler.swift`, when creating notification content for hydration reminders, set:

```swift
content.categoryIdentifier = "HYDRATION_REMINDER"
```

This ensures notifications delivered to the Watch include the "Log 250ml" action button. Find the method that creates `UNMutableNotificationContent` (in `scheduleSmartReminders` and `scheduleClassicReminders`) and add this line to each.

- [ ] **Step 4: Build both targets**

Run: Build `WaterQuest` (iPhone) and `SipliWatch` (Watch) schemes.
Expected: Both build successfully.

- [ ] **Step 5: Commit**

```
git add SipliWatch/WatchNotificationHandler.swift SipliWatch/SipliWatchApp.swift WaterQuest/Services/NotificationScheduler.swift
git commit -m "feat: add inline 'Log 250ml' action to Watch notification reminders"
```

---

## Task 16: End-to-end testing on Watch simulator

- [ ] **Step 1: Build and run both targets**

Run iPhone app on iPhone 17 Pro simulator, then run Watch app on paired Apple Watch simulator.

- [ ] **Step 2: Test data sync**

1. Log water on iPhone → verify Watch dashboard updates (may need to background/foreground Watch app)
2. Log water on Watch → verify iPhone diary shows the entry with `.watchManual` source

- [ ] **Step 3: Test quick add flow**

1. Launch Watch app → Dashboard shows 0%
2. Tap "Add Water" → Quick Add sheet opens
3. Scroll Digital Crown → amounts change (150-750ml)
4. Tap "Log Water" → haptic fires, sheet dismisses, dashboard updates
5. Tap "Add Water" → "More beverages" → select Coffee → log → dashboard updates

- [ ] **Step 4: Test complications**

1. Long-press Watch face → edit complications
2. Add Sipli circular complication → shows progress %
3. Verify complication updates after logging

- [ ] **Step 5: Test edge cases**

1. Log enough water to reach goal → trophy celebration + haptic
2. Delete entry from Today's Log (swipe left) → progress decreases
3. Kill Watch app → relaunch → state persists

- [ ] **Step 6: Final commit**

```
git add -A
git commit -m "chore: finalize Sipli Watch app v1"
```

---

## Summary

| Task | What it builds | Est. steps |
|------|---------------|------------|
| 1 | `.watchManual` source enum case | 3 |
| 2 | Xcode watchOS target + shared file memberships | 7 |
| 3 | WatchHaptics | 3 |
| 4 | WatchHydrationStore | 3 |
| 5 | WatchProgressRing | 3 |
| 6 | WatchDashboardView | 2 (commits with 7-8) |
| 7 | WatchTodayLogView | 1 (commits with 6,8) |
| 8 | WatchQuickAddView + FluidPickerView | 4 |
| 9 | Wire up app entry point | 3 |
| 10 | Complications (circular + corner) | 3 |
| 11 | Interactive quick-add widget | 4 |
| 12 | HealthKit integration | 5 |
| 13 | Goal-reached celebration | 4 |
| 14 | App icon + metadata | 4 |
| 15 | Notification "Log 250ml" inline action | 5 |
| 16 | End-to-end testing | 6 |
| **Total** | | **60 steps** |
