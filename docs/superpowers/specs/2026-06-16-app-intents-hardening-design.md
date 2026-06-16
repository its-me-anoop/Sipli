# App Intents Hardening & Test Coverage — Design

Date: 2026-06-16
Branch: redesign-onboarding-tactile-vessel

## Goal

Implement / harden iOS App Intents for Sipli (WaterQuest) so they are correct,
consistent with in-app logging, and fully tested.

## Current state

App Intents already exist and are members of the `WaterQuest` build target:

- `LogWaterIntent` — logs an intake with amount (mL) + optional fluid type.
- `GetTodaysHydrationIntent` — speaks today's total vs. goal.
- `OpenSipliIntent` — opens the app.
- `IntentDonationService` — donates `LogWaterIntent` for Siri prediction.
- `SipliAppShortcuts` — `AppShortcutsProvider` with spoken phrases.
- `FluidTypeAppEnum` — `AppEnum` mirror of `FluidType`.

Data layer: `PersistedState` (Codable) persisted by `PersistenceService`
(app-group file + iCloud KVS). In-app state lives in `HydrationStore`
(`@MainActor ObservableObject`) which loads `PersistedState` once at `init`.

## Problems

1. **No test coverage** for any intent code.
2. **Data-loss bug.** `LogWaterIntent.perform()` writes through a *fresh*
   `PersistenceService()` straight to disk. The live `HydrationStore` loads
   state only at `init` and is **never reloaded when the app returns to the
   foreground** (`WaterQuestApp`'s `.active` handler refreshes subscriptions /
   HealthKit / notifications but not entries). So an entry logged via
   Siri/Shortcuts/Widget while the app is backgrounded is silently overwritten
   the next time the in-app store calls `persist()`.
3. **Untestable / duplicated logic.** `perform()` interleaves disk I/O, goal
   math, dialog formatting, and side effects; the goal-percent math is
   duplicated across `LogWaterIntent` and `GetTodaysHydrationIntent`.

## Design

### 1. Pure intent core — `HydrationIntentCore`

A namespace `enum` with pure, side-effect-free functions operating on
`PersistedState`, with `now` injected for determinism:

```swift
enum HydrationIntentCore {
    static func logWater(into state: inout PersistedState,
                         amountInMilliliters: Int,
                         fluidType: FluidType,
                         now: Date) -> (entry: HydrationEntry, dialog: String)

    static func todaysHydrationDialog(state: PersistedState, now: Date) -> String

    static func undoLastToday(from state: inout PersistedState,
                              now: Date) -> (removed: HydrationEntry?, dialog: String)

    // shared helpers
    static func clampAmount(_ ml: Int) -> Double            // [50, 2000]
    static func goalML(for state: PersistedState) -> Double
    static func todayTotalML(_ state: PersistedState, now: Date) -> Double
    static func percent(total: Double, goal: Double) -> Int
}
```

Goal is computed via `GoalCalculator.dailyGoal(profile:weather:workout:)` using
`profile` + `lastWeather` + `nil` workout — matching the existing intent
behaviour (a quick Siri log doesn't reach for live HealthKit). The full goal
(with workout) is recomputed in-app when the store reloads.

### 2. Intents refactored to the core

- `LogWaterIntent`, `GetTodaysHydrationIntent` become thin wrappers:
  load via `PersistenceService.shared` → call core → save → `WidgetCenter`
  reload + donation.
- Switch from `PersistenceService()` to `PersistenceService.shared` for
  consistent iCloud-timestamp bookkeeping.
- **New** `UndoLastIntakeIntent` — removes the most recent *today* entry and
  speaks confirmation. Added to `SipliAppShortcuts` with phrases.

### 3. Foreground reload — fix the data-loss bug

- Add a pure helper `HydrationMerge.mergeByID(local:incoming:) -> [HydrationEntry]`
  (union by `id`, sorted by date). Refactor `HydrationStore.applyRemoteState`
  to use it.
- Add `HydrationStore.reloadFromDisk()` that loads `PersistedState` via
  `PersistenceService.shared` and applies it through the same merge path
  (so in-memory entries logged since the last save are preserved while
  intent/widget writes are merged in, and `checkGoalCompletion()` re-runs).
- Call `store.reloadFromDisk()` at the top of `WaterQuestApp`'s `.active`
  scenePhase handler (still gated out under XCTest).

### 4. Tests — `WaterQuestTests/SipliAppIntentsTests.swift`

- `FluidTypeAppEnum`: every `FluidType` has a matching enum case; every case
  round-trips (`from` ∘ `toFluidType`); `caseDisplayRepresentations` covers all
  cases.
- `logWater`: clamps below 50 → 50, above 2000 → 2000, default fluid is water,
  specific fluid honoured, `effectiveML` applied to non-water, dialog percent
  matches `percent()`.
- `todaysHydrationDialog`: empty (0%), partial, ≥100%.
- `undoLastToday`: removes most recent today entry; no-op on empty;
  ignores entries from previous days.
- `HydrationMerge.mergeByID`: union of disjoint sets; dedupes shared ids;
  preserves local-only entries; sorted by date.

## Testing strategy

Pure functions only — no disk, no iCloud, no `@MainActor` store in unit tests.
Run via `xcodebuild test` on the `WaterQuest` scheme (iPhone 17 Pro sim).
Commit after each green milestone.

## Out of scope (YAGNI)

- Interactive widget buttons / `AppIntent` widget configuration.
- Per-fluid dedicated shortcuts (covered by `LogWaterIntent`'s fluid parameter).
- Goal-completion counting inside the intent (recomputed on store reload).
