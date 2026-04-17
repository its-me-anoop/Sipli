# Notification Overhaul — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the foundation layer of the notification overhaul: register iPhone notification categories with tap actions, deep-link notification taps into the Add Intake sheet, wire the already-written Apple Intelligence message generator into the live scheduling path (premium-gated, with a curated fallback), remove dead/destructive code, and introduce the immutable `NotificationContext` snapshot that later phases will extend.

**Architecture:** Introduce a pure `NotificationContext` value type that the scheduler consumes; callers assemble it via `HydrationStore.buildNotificationContext()`. Register a single `HYDRATION_REMINDER` `UNNotificationCategory` (with `LOG_250ML`, `LOG_500ML`, `SNOOZE_1H` actions) at app launch and install a shared `NotificationHandler` (`UNUserNotificationCenterDelegate`) that dispatches action taps back into `HydrationStore`. Rewire message selection through a new `messageFor(context:slot:)` method; fold the Apple Intelligence path in as a best-effort async replacement of the first-fire notification per batch.

**Tech Stack:** Swift 5.9, SwiftUI, `UserNotifications`, `FoundationModels` (iOS 26+ only, optional), XcodeGen 2.44, Xcode 16.

**Scope note:** This plan covers Phase 1 only. Phases 2 (context + celebration), 3 (habit anchors), and 4 (smart system) will each get their own plan written after the preceding phase ships. See `docs/superpowers/specs/2026-04-17-notification-overhaul-design.md` for the full design.

---

## File Structure

**New files**

| Path | Responsibility |
|------|---------------|
| `WaterQuest/Models/NotificationContext.swift` | Immutable snapshot passed to scheduler. Minimal Phase 1 fields: profile, entries, goalML, currentStreak, hasPremiumAccess. |
| `WaterQuest/Services/NotificationCategories.swift` | Stable identifiers for notification categories and actions. `registerAll()` called once at app launch. |
| `WaterQuest/Services/NotificationHandler.swift` | `UNUserNotificationCenterDelegate` singleton. Dispatches action taps back into a weak `HydrationStore` reference. |
| `WaterQuestTests/WaterQuestTests.swift` | Test target entry point. Contains sanity test. |
| `WaterQuestTests/NotificationContextTests.swift` | Unit tests for `NotificationContext` helpers (progress, streak). |
| `WaterQuestTests/NotificationMessageTests.swift` | Unit tests for `NotificationScheduler.messageFor(context:slot:)`. |
| `WaterQuestTests/NotificationCategoriesTests.swift` | Unit tests for `NotificationCategories.all`. |

**Modified files**

| Path | Change |
|------|--------|
| `project.yml` | Update stale `PRODUCT_NAME` to match generated pbxproj; add `WaterQuestTests` target; add `test` targets to the scheme. |
| `WaterQuest/Services/NotificationScheduler.swift` | Accept `NotificationContext` instead of loose args. Replace `curatedMessage(progress:isEscalation:)` with `messageFor(context:slot:)`. Wire AI generation for first-fire notification in smart batches. Add `userInfo["deepLink"]` to all notification content. Delete `minimumGapSeconds`. Remove `removeAllDeliveredNotifications()` from `scheduleReminders`. Extract shared interval math. |
| `WaterQuest/Services/HydrationStore.swift` | Add `buildNotificationContext()`. Update single `onIntakeLogged` call-site to pass context. |
| `WaterQuest/App/WaterQuestApp.swift` | Register categories on launch. Install `NotificationHandler.shared` as `UNUserNotificationCenter` delegate. Wire `store` reference into handler. Update all three `scheduleReminders` call-sites to use the new context parameter. Forward notification-driven deep-link via existing `deepLinkAddIntake` state. |
| `WaterQuest/Views/SettingsView.swift` | Update `rescheduleReminders()` private helper to use the new context parameter. |

**Why this structure**

- `NotificationContext` is a leaf data type, no dependencies — maximally testable and drop-in reusable by Phases 2-4.
- `NotificationCategories` and `NotificationHandler` are small, single-purpose files rather than a single "NotificationInfra" blob. Each has one reason to change.
- Tests live in a dedicated target so they can `@testable import Sipli` and exercise internal types. The test target is infrastructure that Phases 2-4 will also use.

---

## Task 1 — Set up Xcode test target

The project currently has no test target. Before any TDD, create one. Fix the existing drift between `project.yml` (says `PRODUCT_NAME: Thirsty.ai`) and the generated `project.pbxproj` (currently `PRODUCT_NAME = Sipli`, which is the true shipped value as of commit afc4fc8) so regeneration doesn't silently rename the app.

**Files:**
- Modify: `project.yml`
- Create: `WaterQuestTests/WaterQuestTests.swift`
- Regenerate: `WaterQuest.xcodeproj` (side-effect of `xcodegen generate`)

- [ ] **Step 1: Update `project.yml` with correct product name and new test target**

Replace the `WaterQuest` target block and add the test target. Full updated file:

```yaml
name: Thirsty.ai
options:
  bundleIdPrefix: com.waterquest
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    SWIFT_VERSION: "5.9"
    IPHONEOS_DEPLOYMENT_TARGET: "17.0"
    TARGETED_DEVICE_FAMILY: "1"
    INFOPLIST_FILE: WaterQuest/Supporting/Info.plist
    CODE_SIGN_STYLE: Automatic
    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    # Earth Day 2026 alternate app icon. Once WaterQuest/EarthDayIcon.icon/
    # exists with artwork, uncomment the line below and flip
    # EarthDayEvent.alternateIconAvailable to true to expose the Settings
    # toggle for the green Earth Day icon variant.
    # ASSETCATALOG_COMPILER_ALTERNATE_APP_ICON_NAMES: EarthDayIcon

targets:
  WaterQuest:
    type: application
    platform: iOS
    sources:
      - WaterQuest
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.waterquest.hydration
        PRODUCT_NAME: Sipli
        CURRENT_PROJECT_VERSION: 3
        MARKETING_VERSION: 3.0
        CODE_SIGN_ENTITLEMENTS: WaterQuest/Supporting/WaterQuest.entitlements

  WaterQuestTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - WaterQuestTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.waterquest.hydration.tests
        GENERATE_INFOPLIST_FILE: YES
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Sipli.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Sipli"
        BUNDLE_LOADER: "$(TEST_HOST)"
    dependencies:
      - target: WaterQuest

schemes:
  WaterQuest:
    build:
      targets:
        WaterQuest: all
        WaterQuestTests: [test]
    test:
      targets:
        - WaterQuestTests
```

**Note:** Preserve any existing `targets:` entries for `SipliWatch`, `SipliWidget`, `SipliWatchWidgetsExtension` that already live in the file. Only the `WaterQuest` block changes (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, and `PRODUCT_NAME` updated to match current pbxproj state) and a new `WaterQuestTests` target + `schemes` section are added. Read the current file first with `Read`, then edit precisely.

- [ ] **Step 2: Create placeholder test**

Create `WaterQuestTests/WaterQuestTests.swift`:

```swift
import XCTest
@testable import Sipli

final class WaterQuestTests: XCTestCase {
    func test_sanity() {
        XCTAssertEqual(1 + 1, 2)
    }
}
```

- [ ] **Step 3: Regenerate Xcode project**

Run: `cd /Users/anoopjose/Projects/WaterQuest && xcodegen generate`
Expected output: `Loaded project: ...` and `Generated project successfully.`

Review the pbxproj diff with `git diff WaterQuest.xcodeproj/project.pbxproj`. Only expected changes: new test target entries, scheme test action. If the diff renames `Sipli` → `Thirsty.ai` anywhere, abort — project.yml is still out of sync.

- [ ] **Step 4: Run tests to verify the target works**

Run tests via XcodeBuildMCP (`test_sim` with project `WaterQuest.xcodeproj`, scheme `WaterQuest`, simulator id `72CEFB58-398E-4832-B3B2-EB2CF4A583F6`).

Expected: `Test Suite 'WaterQuestTests' passed. Executed 1 test, with 0 failures.`

If the run fails with "no such module 'Sipli'" — the PRODUCT_NAME / module name drifted. Check the generated pbxproj for the WaterQuest target's `PRODUCT_NAME`; the `@testable import` name must match.

- [ ] **Step 5: Commit and push**

```bash
git add project.yml WaterQuest.xcodeproj/project.pbxproj WaterQuestTests/
git commit -m "$(cat <<'EOF'
test: add WaterQuestTests target for notification overhaul

Adds a unit-test bundle target so upcoming notification changes can be
TDD'd. Also syncs project.yml's PRODUCT_NAME/MARKETING_VERSION/
CURRENT_PROJECT_VERSION with the current generated project so xcodegen
regeneration doesn't rename the app.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 2 — Introduce `NotificationContext` value type

A pure data snapshot with no dependencies. The scheduler will switch to consuming this in later tasks; this task just defines the type and tests its helpers.

**Files:**
- Create: `WaterQuest/Models/NotificationContext.swift`
- Create: `WaterQuestTests/NotificationContextTests.swift`

- [ ] **Step 1: Write failing tests for `NotificationContext` helpers**

Create `WaterQuestTests/NotificationContextTests.swift`:

```swift
import XCTest
@testable import Sipli

final class NotificationContextTests: XCTestCase {

    private func makeProfile() -> UserProfile { .default }

    private func makeEntries(volumesML: [Double], on date: Date = Date()) -> [HydrationEntry] {
        volumesML.enumerated().map { idx, volume in
            HydrationEntry(
                id: UUID(),
                date: date.addingTimeInterval(Double(idx) * 60),
                volumeML: volume,
                source: .manual,
                fluidType: .water,
                note: nil
            )
        }
    }

    func test_progress_isRatioOfTodayTotalToGoal() {
        let entries = makeEntries(volumesML: [500, 500])
        let context = NotificationContext(
            profile: makeProfile(),
            entries: entries,
            goalML: 2000,
            currentStreak: 0,
            hasPremiumAccess: false
        )
        XCTAssertEqual(context.progress, 0.5, accuracy: 0.001)
    }

    func test_progress_clampsToOneAboveGoal() {
        let entries = makeEntries(volumesML: [3000])
        let context = NotificationContext(
            profile: makeProfile(),
            entries: entries,
            goalML: 2000,
            currentStreak: 0,
            hasPremiumAccess: false
        )
        XCTAssertEqual(context.progress, 1.0, accuracy: 0.001)
    }

    func test_progress_isZeroWhenGoalIsZero() {
        let context = NotificationContext(
            profile: makeProfile(),
            entries: [],
            goalML: 0,
            currentStreak: 0,
            hasPremiumAccess: false
        )
        XCTAssertEqual(context.progress, 0)
    }

    func test_todayTotalML_sumsOnlyTodayEntriesByEffectiveML() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let entries = [
            HydrationEntry(date: today,     volumeML: 500,  source: .manual, fluidType: .water),
            HydrationEntry(date: today,     volumeML: 500,  source: .manual, fluidType: .water),
            HydrationEntry(date: yesterday, volumeML: 1000, source: .manual, fluidType: .water),
        ]
        let context = NotificationContext(
            profile: makeProfile(),
            entries: entries,
            goalML: 2000,
            currentStreak: 0,
            hasPremiumAccess: false
        )
        XCTAssertEqual(context.todayTotalML, 1000, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Run tests via `test_sim`.
Expected: compiler errors "cannot find 'NotificationContext' in scope".

- [ ] **Step 3: Implement `NotificationContext`**

Create `WaterQuest/Models/NotificationContext.swift`:

```swift
import Foundation

/// Immutable snapshot of the state a notification-scheduling pass needs.
///
/// Callers (`HydrationStore`, `WaterQuestApp`, `SettingsView`) assemble a
/// context and hand it to ``NotificationScheduler``. The scheduler stays
/// pure — given the same context it produces the same schedule — which
/// keeps it easy to reason about and easy to test.
///
/// Phase 1 fields only. Phase 2 adds `weather` and `recentWorkout`; later
/// phases add `reminderAnchors`, `lastLogAt`, and `logTimeHistogram`.
struct NotificationContext {
    let profile: UserProfile
    let entries: [HydrationEntry]
    let goalML: Double
    let currentStreak: Int
    let hasPremiumAccess: Bool

    /// Effective ml logged today (sum of ``HydrationEntry/effectiveML``).
    var todayTotalML: Double {
        let now = Date()
        return entries
            .filter { $0.date.isSameDay(as: now) }
            .reduce(0) { $0 + $1.effectiveML }
    }

    /// Today's progress ratio, clamped to `[0, 1]`. Returns `0` when the
    /// goal is zero or negative.
    var progress: Double {
        guard goalML > 0 else { return 0 }
        return min(1, todayTotalML / goalML)
    }
}
```

- [ ] **Step 4: Run tests — verify they pass**

Run tests via `test_sim`.
Expected: `NotificationContextTests` all pass.

- [ ] **Step 5: Commit and push**

```bash
git add WaterQuest/Models/NotificationContext.swift WaterQuestTests/NotificationContextTests.swift
git commit -m "$(cat <<'EOF'
feat(notifications): introduce NotificationContext value type

Phase 1 scaffolding for the notification overhaul. NotificationContext
is an immutable snapshot callers hand to the scheduler so the scheduler
itself stays pure and testable. Phase 1 fields only; later phases extend
with weather, workout, anchors, last-log, and histogram.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 3 — Add `HydrationStore.buildNotificationContext()`

Assemble a `NotificationContext` from live store state, including the current streak computed from entries. The streak algorithm mirrors the existing `InsightsView.swift:111-120` logic to stay consistent with what the user sees; we inline it here rather than refactoring `InsightsView` in Phase 1 (YAGNI — extraction moves to Phase 4 when `logTimeHistogram` also gets extracted).

**Files:**
- Modify: `WaterQuest/Services/HydrationStore.swift`
- Modify: `WaterQuestTests/NotificationContextTests.swift` (add one integration test)

- [ ] **Step 1: Add failing integration test for `buildNotificationContext()`**

Append to `WaterQuestTests/NotificationContextTests.swift`:

```swift
extension NotificationContextTests {

    @MainActor
    func test_buildNotificationContext_returnsGoalAndPremiumFromStore() {
        let store = HydrationStore()
        store.updateProfile { $0.weightKg = 70 }
        store.updatePremiumAccess(false)

        let context = store.buildNotificationContext()

        XCTAssertFalse(context.hasPremiumAccess)
        XCTAssertGreaterThan(context.goalML, 0)
        XCTAssertEqual(context.profile.weightKg, 70)
    }
}
```

- [ ] **Step 2: Run test — verify it fails**

Expected: `value of type 'HydrationStore' has no member 'buildNotificationContext'`.

- [ ] **Step 3: Implement `buildNotificationContext()`**

Add to `WaterQuest/Services/HydrationStore.swift` (place this after the `todayCompositions` computed property, around line 100):

```swift
/// Assemble an immutable snapshot of everything the notification scheduler
/// needs. Called from every site that reschedules reminders.
///
/// `currentStreak` replicates the algorithm in `InsightsView.swift` — a run
/// of consecutive goal-met days ending either today (if today is met) or
/// yesterday (if not). We inline rather than extract for Phase 1 because
/// Phase 4 will pull out a proper `StreakCalculator` alongside the
/// histogram work.
func buildNotificationContext() -> NotificationContext {
    NotificationContext(
        profile: effectiveProfile,
        entries: entries,
        goalML: dailyGoal.totalML,
        currentStreak: computeCurrentStreak(goalML: dailyGoal.totalML),
        hasPremiumAccess: hasPremiumAccess,
        capturedAt: Date()
    )
}

private func computeCurrentStreak(goalML: Double) -> Int {
    guard goalML > 0 else { return 0 }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // Totals for last 90 days, index 0 = today.
    var totals: [Double] = []
    for offset in 0..<90 {
        guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
        let total = entries
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0.0) { $0 + $1.effectiveML }
        totals.append(total)
    }

    let startIdx = (totals.first ?? 0) >= goalML ? 0 : 1
    var streak = 0
    for i in startIdx..<totals.count {
        if totals[i] >= goalML { streak += 1 } else { break }
    }
    return streak
}
```

- [ ] **Step 4: Run tests — verify they pass**

Expected: all `NotificationContextTests` pass.

- [ ] **Step 5: Commit and push**

```bash
git add WaterQuest/Services/HydrationStore.swift WaterQuestTests/NotificationContextTests.swift
git commit -m "$(cat <<'EOF'
feat(notifications): add HydrationStore.buildNotificationContext()

Factory that assembles a NotificationContext from live store state,
including currentStreak computed from entries. Mirrors the existing
InsightsView streak algorithm for user-facing consistency; extraction
into a shared StreakCalculator is deferred to Phase 4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 4 — Add `MessageSlot` + `messageFor(context:slot:)`

Replace the private `curatedMessage(progress:isEscalation:)` with a slot-driven API. Phase 1 only implements the tiers the current code already supports (first / mid / late / escalation); Phase 2 adds `.celebration`, Phase 3 adds `.workout` and `.comeback`.

**Files:**
- Modify: `WaterQuest/Services/NotificationScheduler.swift`
- Create: `WaterQuestTests/NotificationMessageTests.swift`

- [ ] **Step 1: Write failing tests**

Create `WaterQuestTests/NotificationMessageTests.swift`:

```swift
import XCTest
@testable import Sipli

final class NotificationMessageTests: XCTestCase {

    private func makeContext(progress: Double, streak: Int = 0) -> NotificationContext {
        let goalML: Double = 2000
        let todayML = progress * goalML
        let entry = HydrationEntry(
            date: Date(),
            volumeML: todayML,
            source: .manual,
            fluidType: .water
        )
        return NotificationContext(
            profile: .default,
            entries: todayML > 0 ? [entry] : [],
            goalML: goalML,
            currentStreak: streak,
            hasPremiumAccess: false
        )
    }

    func test_messageFor_firstSlot_returnsNonEmpty() {
        let scheduler = NotificationScheduler()
        let msg = scheduler.messageFor(context: makeContext(progress: 0.1), slot: .first)
        XCTAssertFalse(msg.isEmpty)
    }

    func test_messageFor_midSlot_returnsNonEmpty() {
        let scheduler = NotificationScheduler()
        let msg = scheduler.messageFor(context: makeContext(progress: 0.4), slot: .mid)
        XCTAssertFalse(msg.isEmpty)
    }

    func test_messageFor_lateSlot_returnsNonEmpty() {
        let scheduler = NotificationScheduler()
        let msg = scheduler.messageFor(context: makeContext(progress: 0.8), slot: .late)
        XCTAssertFalse(msg.isEmpty)
    }

    func test_messageFor_escalationSlot_returnsNonEmpty() {
        let scheduler = NotificationScheduler()
        let msg = scheduler.messageFor(context: makeContext(progress: 0.2), slot: .escalation)
        XCTAssertFalse(msg.isEmpty)
    }

    /// `slotFor(context:)` is the convenience that the scheduler uses when
    /// producing a reminder based solely on progress (no explicit slot).
    func test_slotFor_picksFirstWhenProgressLow() {
        let scheduler = NotificationScheduler()
        XCTAssertEqual(scheduler.slotFor(context: makeContext(progress: 0.1)), .first)
    }

    func test_slotFor_picksMidWhenProgressMid() {
        let scheduler = NotificationScheduler()
        XCTAssertEqual(scheduler.slotFor(context: makeContext(progress: 0.4)), .mid)
    }

    func test_slotFor_picksLateWhenProgressHigh() {
        let scheduler = NotificationScheduler()
        XCTAssertEqual(scheduler.slotFor(context: makeContext(progress: 0.8)), .late)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: `messageFor`, `slotFor`, `MessageSlot` all undeclared.

- [ ] **Step 3: Add `MessageSlot` enum and `messageFor` / `slotFor` to `NotificationScheduler`**

In `WaterQuest/Services/NotificationScheduler.swift`, add the enum above the class declaration (around line 21, before `final class NotificationScheduler`):

```swift
/// Logical slot for a reminder message. Slots decouple copy selection from
/// raw progress thresholds so later phases (celebration, workout, comeback)
/// can add new tiers without reshaping the API.
enum MessageSlot {
    case first       // early in the day or low progress
    case mid         // midday or mid progress
    case late        // late day or high progress
    case escalation  // streak at risk (Phase 4 wires this to time-sensitive)
    // Phase 2: case celebration
    // Phase 3: case workout, case comeback
}
```

Inside the class, replace the existing `curatedMessage(progress:isEscalation:)` method with:

```swift
// MARK: - Message selection

/// Entry point used by both smart and classic scheduling paths. Picks a
/// curated message appropriate for the slot; the AI wire-up (see
/// `scheduleAIReplacement(...)`) can later swap the first-fire notification
/// for a generated message.
func messageFor(context: NotificationContext, slot: MessageSlot) -> String {
    switch slot {
    case .first:
        return earlyMessages.randomElement() ?? "Start your day right — grab some water!"
    case .mid:
        return midMessages.randomElement() ?? "Keep the momentum going — sip up!"
    case .late:
        return lateMessages.randomElement() ?? "Almost there — a few more sips!"
    case .escalation:
        return escalationMessages.randomElement() ?? "It's been a while — time for a sip!"
    }
}

/// Convenience: picks a slot from raw progress when the caller doesn't
/// have a specific one in mind (e.g. an ordinary smart reminder).
func slotFor(context: NotificationContext) -> MessageSlot {
    let p = context.progress
    if p < 0.25 { return .first }
    if p < 0.6  { return .mid }
    return .late
}
```

Keep the `earlyMessages`, `midMessages`, `lateMessages`, `escalationMessages` arrays as they are — they already exist at lines 251-278 and `messageFor` now reads them.

**Keep** the existing `curatedMessage(progress:isEscalation:)` method (lines 238-249) and its call at line 157 untouched for this task. Task 6 rewires the call sites through `messageFor` and deletes `curatedMessage` at that point. This lets the project keep building between tasks.

- [ ] **Step 4: Run tests — verify they pass**

Expected: all `NotificationMessageTests` pass, plus existing tests.

- [ ] **Step 5: Commit and push**

```bash
git add WaterQuest/Services/NotificationScheduler.swift WaterQuestTests/NotificationMessageTests.swift
git commit -m "$(cat <<'EOF'
refactor(notifications): introduce MessageSlot + messageFor API

Replaces the private curatedMessage(progress:isEscalation:) with a
slot-driven messageFor(context:slot:). Phase 2/3 will add .celebration,
.workout, and .comeback slots without reshaping the API. The existing
curated message pools are reused — no user-visible change yet.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 5 — Refactor scheduler signature to `scheduleReminders(context:)`

The scheduler currently takes `profile: UserProfile, entries: [HydrationEntry], goalML: Double`. Change to `context: NotificationContext`. Three call sites update atomically.

**Files:**
- Modify: `WaterQuest/Services/NotificationScheduler.swift`
- Modify: `WaterQuest/App/WaterQuestApp.swift`
- Modify: `WaterQuest/Views/SettingsView.swift`
- Modify: `WaterQuest/Services/HydrationStore.swift`

- [ ] **Step 1: Update scheduler public signature**

In `WaterQuest/Services/NotificationScheduler.swift`, replace the `scheduleReminders` method (lines 65-81) with:

```swift
/// Call this whenever the profile, entries, or app lifecycle change.
/// Tears down previous notifications and schedules fresh ones.
func scheduleReminders(context: NotificationContext) {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    // NOTE: removeAllDeliveredNotifications() deliberately NOT called here —
    // wiping the user's Notification Center on every foreground destroys
    // their history. Task 9 drops the stale call entirely.

    currentContext = context
    lastKnownEntries = context.entries.map { DateEntry(date: $0.date, volumeML: $0.effectiveML) }
    didFireEscalation = false

    guard context.profile.remindersEnabled else { return }

    if context.profile.smartRemindersEnabled {
        scheduleSmartReminders(context: context)
    } else {
        scheduleClassicReminders(context: context)
    }
}
```

Replace the private state fields at lines 38-41 (`currentProfile`, `currentGoalML`) with:

```swift
/// Stored context for rescheduling from `onIntakeLogged`.
private var currentContext: NotificationContext?
```

Update `onIntakeLogged(entry:)` (lines 85-93):

```swift
/// Call this when a new intake is logged so smart reminders reschedule
/// around the latest activity.
func onIntakeLogged(entry: HydrationEntry, context: NotificationContext) {
    lastKnownEntries.append(DateEntry(date: entry.date, volumeML: entry.effectiveML))
    didFireEscalation = false
    currentContext = context

    guard context.profile.remindersEnabled, context.profile.smartRemindersEnabled else { return }
    clearPendingSmartReminders {
        self.scheduleSmartReminders(context: context)
    }
}
```

Update the private `scheduleSmartReminders` signature (line 100):

```swift
private func scheduleSmartReminders(context: NotificationContext) {
    let profile = context.profile
    let goalML = context.goalML
    // ...existing body uses profile and goalML locals; no other change needed
```

The body at lines 101-172 references `profile` and `goalML` as parameters; after extracting to locals at the top they continue to work as-is. Leave the rest of the function body unchanged.

Update `scheduleClassicReminders` (line 282):

```swift
private func scheduleClassicReminders(context: NotificationContext) {
    let profile = context.profile
    // ...existing body continues to use `profile` as a local
```

Update `computeInterval` call sites — currently `computeInterval(profile: profile)`. Stays the same since `profile` is a local in both private schedulers now.

- [ ] **Step 2: Update `HydrationStore.onIntakeLogged` call-sites**

In `WaterQuest/Services/HydrationStore.swift`, find both call-sites of `notificationScheduler?.onIntakeLogged(entry: entry)` (currently at line 108 inside `addIntake` and around line 280 inside the sibling method). Replace with:

```swift
notificationScheduler?.onIntakeLogged(entry: entry, context: buildNotificationContext())
```

Use `Grep` to find every `onIntakeLogged(entry:` call — update them all. (The store has at least 2; verify with `grep -n "onIntakeLogged"` before editing.)

- [ ] **Step 3: Update `WaterQuestApp` call-sites**

In `WaterQuest/App/WaterQuestApp.swift`, replace every `notifier.scheduleReminders(profile: ..., entries: ..., goalML: ...)` with:

```swift
notifier.scheduleReminders(context: store.buildNotificationContext())
```

There are three such call-sites (in `.task` at line 47, inside the subscription `.onChange` at line 60, and in the `scenePhase == .active` branch at line 69). Update all three.

- [ ] **Step 4: Update `SettingsView` call-site**

In `WaterQuest/Views/SettingsView.swift`, replace the `rescheduleReminders()` helper body (around line 878):

```swift
private func rescheduleReminders() {
    notifier.scheduleReminders(context: store.buildNotificationContext())
}
```

- [ ] **Step 5: Build — verify it compiles**

Run `build_sim` via XcodeBuildMCP (project `WaterQuest.xcodeproj`, scheme `WaterQuest`, simulator id `72CEFB58-398E-4832-B3B2-EB2CF4A583F6`).
Expected: Build succeeds.

If compile errors reference old parameter names, search the codebase for any other call-sites missed (including `SipliWatch/` Watch code — though based on earlier exploration the watch uses its own scheduler).

- [ ] **Step 6: Run tests — verify no regression**

Run `test_sim`. Expected: all existing tests pass.

- [ ] **Step 7: Commit and push**

```bash
git add WaterQuest/Services/NotificationScheduler.swift WaterQuest/Services/HydrationStore.swift WaterQuest/App/WaterQuestApp.swift WaterQuest/Views/SettingsView.swift
git commit -m "$(cat <<'EOF'
refactor(notifications): scheduler takes NotificationContext

Scheduler's public signatures now accept a NotificationContext snapshot
instead of loose (profile, entries, goalML) tuples. Callers build the
snapshot via HydrationStore.buildNotificationContext(). No behavior
change — this is the scaffolding Phase 2+ needs (streak, weather,
workout, anchors all land on the same struct later).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 6 — Rewire `scheduleSmartReminders` / `scheduleClassicReminders` through `messageFor`

The `curatedMessage` call at line 157 still exists (we kept it working for Task 5). Replace it (and the classic-mode static string pool) with `messageFor(context:slot:)` so free-tier classic reminders also get progress-aware copy when the reminder fires near certain times of day.

**Files:**
- Modify: `WaterQuest/Services/NotificationScheduler.swift`

- [ ] **Step 1: Update `scheduleSmartReminders` to use `messageFor`**

In `scheduleSmartReminders(context:)`, replace the loop body's message line (was line 157):

```swift
let slot = slotFor(context: context)
let body = messageFor(context: context, slot: slot)
```

Remove the unused `progress` local (it's no longer referenced after this change). Verify with a local build.

- [ ] **Step 1b: Delete the orphaned `curatedMessage` method**

Once the only remaining call site at line 157 is gone, `curatedMessage(progress:isEscalation:)` (lines 238-249) has no callers. Delete the method body entirely. Keep the message arrays (`earlyMessages`, `midMessages`, `lateMessages`, `escalationMessages`) — `messageFor` uses them.

- [ ] **Step 2: Update `scheduleClassicReminders` to use `messageFor`**

Classic mode schedules fixed calendar-repeating notifications. Progress-awareness at schedule time isn't meaningful (the reminder fires every day), but time-of-day-awareness is: a 7am reminder is "first", a 1pm reminder is "mid", an 8pm reminder is "late".

In `scheduleClassicReminders(context:)`, replace the `staticMessages` array and the body assignment. Current (lines 286-301):

```swift
let staticMessages = [ ... ]
// ...
content.body = staticMessages[index % staticMessages.count]
```

Replace with:

```swift
for (index, minutes) in times.enumerated() {
    var dateComponents = DateComponents()
    dateComponents.hour = minutes / 60
    dateComponents.minute = minutes % 60

    let slot = classicSlot(forMinutes: minutes, context: context)

    let content = UNMutableNotificationContent()
    content.title = "Sipli"
    content.body = messageFor(context: context, slot: slot)
    content.sound = .default
    content.categoryIdentifier = NotificationCategoryID.hydrationReminder.rawValue
    // Task 7 adds userInfo["deepLink"] — added there, not here.

    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
    let request = UNNotificationRequest(identifier: "sipli.classic.\(index)", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}
```

Add the `classicSlot` helper on `NotificationScheduler`:

```swift
/// Maps a classic reminder's schedule time to a slot. Classic mode
/// reminders repeat daily so progress isn't known at schedule time;
/// time-of-day is the only signal.
private func classicSlot(forMinutes minutes: Int, context: NotificationContext) -> MessageSlot {
    let wake = context.profile.wakeMinutes
    let sleep = context.profile.sleepMinutes
    let awakeMinutes = max(1, sleep - wake)
    let relative = Double(minutes - wake) / Double(awakeMinutes)
    if relative < 0.33 { return .first }
    if relative < 0.66 { return .mid }
    return .late
}
```

Note: `NotificationCategoryID.hydrationReminder.rawValue` doesn't exist yet — Task 7 creates it. **Temporary:** use the string literal `"HYDRATION_REMINDER"` for this task; Task 7 will replace with the enum.

**Temporary code for this task:**
```swift
content.categoryIdentifier = "HYDRATION_REMINDER"
```

- [ ] **Step 3: Build and run tests — verify no regression**

Run `build_sim` and `test_sim`. Expected: all green.

- [ ] **Step 4: Commit and push**

```bash
git add WaterQuest/Services/NotificationScheduler.swift
git commit -m "$(cat <<'EOF'
refactor(notifications): classic + smart modes share messageFor

Both schedulers now go through messageFor(context:slot:). Classic mode
becomes time-of-day aware (first/mid/late based on when the reminder
fires relative to the awake window). The static 5-line pool is gone;
free-tier reminders now draw from the same curated tiers as premium.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 7 — Register `HYDRATION_REMINDER` notification category + actions

Create stable identifiers and register the category with the system at app launch. This enables the action buttons on notifications without yet wiring a handler (Task 8 does that).

**Files:**
- Create: `WaterQuest/Services/NotificationCategories.swift`
- Create: `WaterQuestTests/NotificationCategoriesTests.swift`
- Modify: `WaterQuest/App/WaterQuestApp.swift`
- Modify: `WaterQuest/Services/NotificationScheduler.swift`

- [ ] **Step 1: Write failing tests**

Create `WaterQuestTests/NotificationCategoriesTests.swift`:

```swift
import XCTest
import UserNotifications
@testable import Sipli

final class NotificationCategoriesTests: XCTestCase {

    func test_all_containsHydrationReminderCategory() {
        let ids = NotificationCategories.all.map(\.identifier)
        XCTAssertTrue(ids.contains(NotificationCategoryID.hydrationReminder.rawValue))
    }

    func test_hydrationReminder_hasLog250MlAction() {
        let category = NotificationCategories.all.first {
            $0.identifier == NotificationCategoryID.hydrationReminder.rawValue
        }
        XCTAssertNotNil(category)
        let actionIds = category?.actions.map(\.identifier) ?? []
        XCTAssertTrue(actionIds.contains(NotificationActionID.log250ml.rawValue))
    }

    func test_hydrationReminder_hasLog500MlAction() {
        let category = NotificationCategories.all.first {
            $0.identifier == NotificationCategoryID.hydrationReminder.rawValue
        }
        let actionIds = category?.actions.map(\.identifier) ?? []
        XCTAssertTrue(actionIds.contains(NotificationActionID.log500ml.rawValue))
    }

    func test_hydrationReminder_hasSnooze1HAction() {
        let category = NotificationCategories.all.first {
            $0.identifier == NotificationCategoryID.hydrationReminder.rawValue
        }
        let actionIds = category?.actions.map(\.identifier) ?? []
        XCTAssertTrue(actionIds.contains(NotificationActionID.snooze1h.rawValue))
    }

    func test_log250Ml_doesNotRequireAuthentication() {
        let category = NotificationCategories.all.first {
            $0.identifier == NotificationCategoryID.hydrationReminder.rawValue
        }
        let log = category?.actions.first { $0.identifier == NotificationActionID.log250ml.rawValue }
        XCTAssertNotNil(log)
        // .authenticationRequired would appear as part of .foreground; the
        // absence of .authenticationRequired lets logs happen from the
        // lock screen.
        XCTAssertFalse(log?.options.contains(.authenticationRequired) ?? true)
    }
}
```

- [ ] **Step 2: Run tests — verify they fail**

Expected: `NotificationCategories`, `NotificationCategoryID`, `NotificationActionID` not declared.

- [ ] **Step 3: Implement categories + identifiers**

Create `WaterQuest/Services/NotificationCategories.swift`:

```swift
import Foundation
import UserNotifications

/// Stable identifiers for notification categories. String values are the
/// identifiers iOS stores — changing them is a breaking change, so only
/// add new cases, never rename.
enum NotificationCategoryID: String {
    case hydrationReminder = "HYDRATION_REMINDER"
    // Phase 2: case hydrationCelebration = "HYDRATION_CELEBRATION"
    // Phase 3: case hydrationComeback     = "HYDRATION_COMEBACK"
    // Phase 3: case hydrationWorkout      = "HYDRATION_WORKOUT"
}

/// Stable identifiers for action buttons. Same rules as
/// ``NotificationCategoryID`` — additive only.
enum NotificationActionID: String {
    case log250ml = "LOG_250ML"
    case log500ml = "LOG_500ML"
    case snooze1h = "SNOOZE_1H"
    // Phase 3: case logGlassComeback = "LOG_GLASS_COMEBACK"
    // Phase 3: case notToday         = "NOT_TODAY"
    // Phase 3: case logGlassWorkout  = "LOG_GLASS_WORKOUT"
}

/// Factory and registration helper for all notification categories used by
/// the iPhone app. Call ``registerAll()`` once at app launch.
enum NotificationCategories {

    /// Every category the app registers with the system.
    static var all: [UNNotificationCategory] {
        [hydrationReminder]
    }

    /// Register the full set with ``UNUserNotificationCenter``. Call once
    /// during app launch, before any notifications are scheduled.
    static func registerAll() {
        UNUserNotificationCenter.current().setNotificationCategories(Set(all))
    }

    private static var hydrationReminder: UNNotificationCategory {
        let log250 = UNNotificationAction(
            identifier: NotificationActionID.log250ml.rawValue,
            title: "Log 250 ml",
            options: []
        )
        let log500 = UNNotificationAction(
            identifier: NotificationActionID.log500ml.rawValue,
            title: "Log 500 ml",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: NotificationActionID.snooze1h.rawValue,
            title: "Snooze 1 hr",
            options: []
        )
        return UNNotificationCategory(
            identifier: NotificationCategoryID.hydrationReminder.rawValue,
            actions: [log250, log500, snooze],
            intentIdentifiers: [],
            options: []
        )
    }
}
```

- [ ] **Step 4: Register categories at app launch**

In `WaterQuest/App/WaterQuestApp.swift`, add to `init()`:

```swift
init() {
    NotificationCategories.registerAll()
    let location = LocationManager()
    _locationManager = StateObject(wrappedValue: location)
    _weatherClient = StateObject(wrappedValue: WeatherClient(locationManager: location))
}
```

- [ ] **Step 5: Swap the temporary string literal in the scheduler**

In `WaterQuest/Services/NotificationScheduler.swift`, find all occurrences of the literal string `"HYDRATION_REMINDER"` (should be 2 — one in smart, one in classic) and replace with `NotificationCategoryID.hydrationReminder.rawValue`.

- [ ] **Step 6: Run tests — verify they pass**

Expected: all `NotificationCategoriesTests` pass.

- [ ] **Step 7: Commit and push**

```bash
git add WaterQuest/Services/NotificationCategories.swift WaterQuest/App/WaterQuestApp.swift WaterQuest/Services/NotificationScheduler.swift WaterQuestTests/NotificationCategoriesTests.swift
git commit -m "$(cat <<'EOF'
feat(notifications): register HYDRATION_REMINDER category with actions

Adds LOG_250ML, LOG_500ML, SNOOZE_1H actions. Categories registered once
at app launch. Handler wiring (NotificationHandler) lands in the next
task — until then the action buttons render but pressing them falls back
to the default tap behavior.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 8 — Implement `NotificationHandler` + install as delegate

The handler is an `NSObject` singleton conforming to `UNUserNotificationCenterDelegate`. It holds a weak `HydrationStore` reference (set during app launch once the `@StateObject` is available) and a weak deep-link proxy for forwarding default taps.

**Files:**
- Create: `WaterQuest/Services/NotificationHandler.swift`
- Modify: `WaterQuest/App/WaterQuestApp.swift`

- [ ] **Step 1: Create `NotificationHandler`**

Create `WaterQuest/Services/NotificationHandler.swift`:

```swift
import Foundation
import UserNotifications

/// Forwarding target for notification default-taps. The app sets this on
/// `NotificationHandler.shared` so default taps can surface the deep-link
/// signal via the existing `@State var deepLinkAddIntake` plumbing in
/// ``WaterQuestApp``.
protocol NotificationDeepLinkForwarding: AnyObject {
    func openAddIntake()
}

/// `UNUserNotificationCenterDelegate` singleton. Installed once in
/// ``WaterQuestApp`` at launch. Holds a weak ``HydrationStore`` so
/// action taps can log intake silently from the lock screen.
///
/// The singleton pattern is intentional: the `UNUserNotificationCenter`
/// delegate API is a singleton on the iOS side too, and the handler needs
/// to exist before any `@StateObject` is initialized so cold launches
/// triggered by a notification tap don't drop the tap on the floor.
@MainActor
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationHandler()

    weak var store: HydrationStore?
    weak var deepLinkForwarder: NotificationDeepLinkForwarding?

    private override init() { super.init() }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when the app is foregrounded and a notification arrives.
    /// Default behavior suppresses the banner; return `.banner` so the
    /// user still sees the reminder even while using the app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Called when the user taps a notification or an action button.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        Task { @MainActor in
            self.handle(actionID: actionID)
            completionHandler()
        }
    }

    // MARK: - Action dispatch

    private func handle(actionID: String) {
        switch actionID {
        case NotificationActionID.log250ml.rawValue:
            logAmount(ml: 250)
        case NotificationActionID.log500ml.rawValue:
            logAmount(ml: 500)
        case NotificationActionID.snooze1h.rawValue:
            snoozeOneHour()
        case UNNotificationDefaultActionIdentifier:
            deepLinkForwarder?.openAddIntake()
        default:
            break
        }
    }

    private func logAmount(ml: Double) {
        guard let store = store else { return }
        // Respect unit system — `addIntake` converts from the given unit.
        // 250 ml and 500 ml are metric-native; pass the ml value and mark
        // the unitSystem explicitly so the store doesn't re-convert.
        _ = store.addIntake(
            amount: ml,
            unitSystem: .metric,
            source: .manual,
            fluidType: .water,
            note: nil
        )
    }

    private func snoozeOneHour() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            // Cancel the next-soonest smart reminder, if any, then
            // schedule a single fire 60 min from now in its place.
            let smart = requests
                .filter { $0.identifier.hasPrefix("sipli.smart.") }
            if let next = smart.min(by: { lhs, rhs in
                let l = (lhs.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
                let r = (rhs.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
                return l < r
            }) {
                center.removePendingNotificationRequests(withIdentifiers: [next.identifier])
            }

            let content = UNMutableNotificationContent()
            content.title = "Sipli"
            content.body = "Here's your snoozed reminder — sip time!"
            content.sound = .default
            content.categoryIdentifier = NotificationCategoryID.hydrationReminder.rawValue
            content.userInfo = ["deepLink": "sipli://add-intake"]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
            let request = UNNotificationRequest(
                identifier: "sipli.snooze.\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}
```

- [ ] **Step 2: Install delegate in `WaterQuestApp`**

In `WaterQuest/App/WaterQuestApp.swift`:

Update `init()`:

```swift
init() {
    NotificationCategories.registerAll()
    UNUserNotificationCenter.current().delegate = NotificationHandler.shared
    let location = LocationManager()
    _locationManager = StateObject(wrappedValue: location)
    _weatherClient = StateObject(wrappedValue: WeatherClient(locationManager: location))
}
```

Conform the app struct to `NotificationDeepLinkForwarding`. Because the `App` itself isn't a class and can't hold weak references, create a small forwarder object that lives as a `@StateObject` and bridges to the `@State` deep-link flag:

Add near the top of the file, below `@main struct WaterQuestApp: App {`:

```swift
@StateObject private var deepLinkForwarder = NotificationDeepLinkForwarder()
```

And at the bottom of the file (before the Environment key extensions):

```swift
@MainActor
final class NotificationDeepLinkForwarder: ObservableObject, NotificationDeepLinkForwarding {
    @Published var shouldOpenAddIntake: Bool = false

    nonisolated func openAddIntake() {
        Task { @MainActor in
            self.shouldOpenAddIntake = true
        }
    }
}
```

In `.task` (around line 39-48), wire the store and forwarder into the handler:

```swift
.task {
    store.notificationScheduler = notifier
    NotificationHandler.shared.store = store
    NotificationHandler.shared.deepLinkForwarder = deepLinkForwarder
    await subscriptionManager.initialise()
    store.updatePremiumAccess(subscriptionManager.hasPremiumAccess)
    _ = subscriptionManager.startTransactionListener()
    guard isSetupComplete else { return }
    await notifier.refreshAuthorizationStatus()
    await healthKit.refreshAuthorizationStatus()
    notifier.scheduleReminders(context: store.buildNotificationContext())
}
```

Hook the forwarder's published flag into the existing deep-link. Add below the existing `.onChange(of: deepLinkAddIntake)` handler:

```swift
.onChange(of: deepLinkForwarder.shouldOpenAddIntake) { _, shouldOpen in
    if shouldOpen {
        deepLinkAddIntake = true
        deepLinkForwarder.shouldOpenAddIntake = false
    }
}
```

- [ ] **Step 3: Build and run tests**

Run `build_sim` then `test_sim`. Expected: all green, no new warnings.

- [ ] **Step 4: Commit and push**

```bash
git add WaterQuest/Services/NotificationHandler.swift WaterQuest/App/WaterQuestApp.swift
git commit -m "$(cat <<'EOF'
feat(notifications): NotificationHandler dispatches action taps

LOG_250ML and LOG_500ML record an intake via HydrationStore.addIntake()
without foregrounding the app (lock-screen friendly). SNOOZE_1H cancels
the soonest pending smart reminder and schedules a single fire 60 min
out. Default taps bridge through a NotificationDeepLinkForwarder into
the existing deepLinkAddIntake plumbing.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 9 — Add `userInfo["deepLink"]` to every scheduled notification

Notifications need to carry the deep-link so default taps know where to go. Task 8 added `userInfo` to the snooze-generated notification; this task adds it to every other scheduling site.

**Files:**
- Modify: `WaterQuest/Services/NotificationScheduler.swift`

- [ ] **Step 1: Add a shared `hydrationReminderContent(body:)` helper**

Several sites build identical `UNMutableNotificationContent` — hoist the common setup into a single method on `NotificationScheduler`:

```swift
// MARK: - Notification content helpers

private func hydrationReminderContent(body: String) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = "Sipli"
    content.body = body
    content.sound = .default
    content.categoryIdentifier = NotificationCategoryID.hydrationReminder.rawValue
    content.userInfo = ["deepLink": "sipli://add-intake"]
    return content
}
```

Place it near the bottom of the class, just before the private `DateEntry` struct.

- [ ] **Step 2: Use the helper in `scheduleSmartReminders`**

Replace the inline content construction (current lines 159-167 inside the `while` loop) with:

```swift
let content = hydrationReminderContent(body: messageFor(context: context, slot: slot))

let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
let request = UNNotificationRequest(identifier: "\(smartIdentifierPrefix)\(batchID).\(index)", content: content, trigger: trigger)
UNUserNotificationCenter.current().add(request)
```

- [ ] **Step 3: Use the helper in `scheduleClassicReminders`**

Replace the inline content construction (current lines 299-303 from Task 6) with:

```swift
let content = hydrationReminderContent(body: messageFor(context: context, slot: slot))
```

- [ ] **Step 4: Build + verify**

Run `build_sim`. Expected: build succeeds.

- [ ] **Step 5: Commit and push**

```bash
git add WaterQuest/Services/NotificationScheduler.swift
git commit -m "$(cat <<'EOF'
feat(notifications): scheduled notifications carry deep-link userInfo

All hydration-reminder notifications now include
userInfo["deepLink"] = "sipli://add-intake". Tapping the body of a
notification opens the Add Intake sheet via the existing deep-link
plumbing. Hoists the notification-content construction into a single
hydrationReminderContent(body:) helper so the three sites don't drift.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 10 — Wire Apple Intelligence for first-in-batch smart reminders (Premium only)

The `_generateAIMessageWithFoundationModels` method already exists but was never called. Wire it so the *soonest* scheduled smart reminder in a batch gets AI-generated copy; subsequent notifications keep curated copy. Premium-gated per D1. Non-blocking with a 2-second timeout.

**Files:**
- Modify: `WaterQuest/Services/NotificationScheduler.swift`

- [ ] **Step 1: Refactor `_generateAIMessageWithFoundationModels` to accept `NotificationContext`**

Replace the existing method (lines 204-233) with:

```swift
#if canImport(FoundationModels)
@available(iOS 26.0, *)
private func _generateAIMessageWithFoundationModels(context: NotificationContext) async -> String? {
    guard SystemLanguageModel.default.isAvailable else { return nil }

    let percentText = String(format: "%.0f", context.progress * 100)
    let streakLine = context.currentStreak > 0
        ? "\nCurrent streak: \(context.currentStreak) days"
        : ""

    let prompt = """
        Generate a single short (max 12 words), friendly, motivational hydration reminder.
        The user has completed \(percentText)% of their daily water goal (\(Int(context.todayTotalML)) of \(Int(context.goalML)) ml).\(streakLine)
        Reply with ONLY the reminder text. No quotes, no punctuation beyond one exclamation mark.
        """

    let session = LanguageModelSession(instructions: """
        You are a cheerful hydration coach inside a mobile app called Sipli.
        You write short, warm, motivational nudges to help people drink more water.
        Keep every response under 12 words. Be encouraging, never guilt-tripping.
        """)

    do {
        let response = try await session.respond(to: prompt)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    } catch {
        return nil
    }
}
#endif
```

Replace the non-gated wrapper (lines 195-202):

```swift
private func generateAIMessage(context: NotificationContext) async -> String? {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
        return await _generateAIMessageWithFoundationModels(context: context)
    }
    #endif
    return nil
}
```

Delete the orphaned `generateMessage(progress:todayTotalML:goalML:isEscalation:)` method (currently at lines 185-191) — it was never called from the scheduling path.

- [ ] **Step 2: Add `scheduleAIReplacementForFirstFire(in:batchID:context:)`**

Inside `NotificationScheduler`, add:

```swift
/// Fire-and-forget: after the synchronous batch is scheduled, try to
/// replace the soonest-firing notification with AI-generated copy.
/// Premium-gated. Skips when FoundationModels isn't available. Honors
/// a 2-second timeout — curated copy stands on timeout or failure.
private func scheduleAIReplacementForFirstFire(
    batchID: Int,
    firstFireDate: Date,
    context: NotificationContext
) {
    guard context.hasPremiumAccess else { return }

    Task { [weak self] in
        guard let self = self else { return }

        let aiText: String?
        do {
            aiText = try await withThrowingTaskGroup(of: String?.self) { group in
                group.addTask { await self.generateAIMessage(context: context) }
                group.addTask {
                    try await Task.sleep(for: .seconds(2))
                    throw CancellationError()
                }
                let result = try await group.next() ?? nil
                group.cancelAll()
                return result
            }
        } catch {
            aiText = nil
        }

        guard let aiText else { return }

        // Replace the first-fire notification.
        await MainActor.run {
            let firstIdentifier = "\(self.smartIdentifierPrefix)\(batchID).0"
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [firstIdentifier])

            let delay = max(1, firstFireDate.timeIntervalSinceNow)
            let content = self.hydrationReminderContent(body: aiText)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let replacement = UNNotificationRequest(
                identifier: "\(self.smartIdentifierPrefix)\(batchID).0.ai",
                content: content,
                trigger: trigger
            )
            center.add(replacement)
        }
    }
}
```

- [ ] **Step 3: Call it from `scheduleSmartReminders`**

At the end of `scheduleSmartReminders(context:)` (just before the closing brace of the function), after the `while` loop:

```swift
    // ...existing while loop body...
    fireDate = fireDate.addingTimeInterval(intervalSeconds)
    index += 1
}

if index > 0 {
    // The first scheduled notification in this batch fires at `nextFireDate`
    // (the value captured before the loop). Kick off AI replacement
    // asynchronously; the curated-copy notification stands if AI is slow.
    scheduleAIReplacementForFirstFire(
        batchID: batchID,
        firstFireDate: nextFireDate,
        context: context
    )
}
```

Note: `nextFireDate` is mutated inside the `while` loop (line 153 — `fireDate = fireDate.addingTimeInterval(intervalSeconds)`). Capture the pre-loop value so the AI replacement knows the actual first fire time. The variable `nextFireDate` already exists at line 124; just add one line after the overdue adjustment and before the `while` loop:

```swift
// If overdue, fire soon.
if nextFireDate <= now {
    nextFireDate = now.addingTimeInterval(60)
}

// Pre-loop snapshot of the first-fire time, before the while loop mutates the iterator.
let firstFireDate = nextFireDate
```

Then pass `firstFireDate` into the `scheduleAIReplacementForFirstFire` call at the bottom of the function.

- [ ] **Step 4: Build + run tests**

Run `build_sim` and `test_sim`. Expected: clean build, all tests pass.

- [ ] **Step 5: Commit and push**

```bash
git add WaterQuest/Services/NotificationScheduler.swift
git commit -m "$(cat <<'EOF'
feat(notifications): wire Apple Intelligence for first-in-batch (Premium)

After the synchronous batch of smart reminders is scheduled, kick off a
non-blocking Task that asks Apple Intelligence for a friendlier message
and replaces the soonest-firing notification. Premium-gated; 2-second
timeout; curated copy stands on failure. Deletes the orphaned
generateMessage(...) helper that was never called.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 11 — Dead code cleanup + interval math refactor

Drop `minimumGapSeconds` (never used), stop nuking the Notification Center on every foreground, and pull the duplicated interval math out of both scheduler paths.

**Files:**
- Modify: `WaterQuest/Services/NotificationScheduler.swift`

- [ ] **Step 1: Remove `minimumGapSeconds`**

Delete line 27:
```swift
private let minimumGapSeconds: Double = 1800 // 30 min
```

Also delete lines 28-31 if they're also unreferenced (check with `grep -n "quietThresholdMultiplier" WaterQuest/Services/NotificationScheduler.swift` — if no other matches, they're dead too):

```swift
private let quietThresholdMultiplier: Double = 2.0
```

- [ ] **Step 2: Confirm `removeAllDeliveredNotifications()` is already gone**

Task 5's edit removed the call from `scheduleReminders(context:)`. Run `grep -n "removeAllDeliveredNotifications" WaterQuest/` — expected: no matches. If any remain elsewhere, delete them.

- [ ] **Step 3: Refactor duplicated interval math**

Both `scheduleSmartReminders` and `scheduleClassicReminders` compute the same interval. Pull out `reminderTimes(profile:)` and `computeInterval(profile:)`.

The existing `computeInterval(profile:)` at line 176 is fine — keep it. Replace the inline duplicate at line 284 in `scheduleClassicReminders(context:)`:

```swift
private func scheduleClassicReminders(context: NotificationContext) {
    let profile = context.profile
    let count = classicReminderCount(profile: profile)
    let times = classicReminderTimes(wakeMinutes: profile.wakeMinutes, sleepMinutes: profile.sleepMinutes, count: count)

    for (index, minutes) in times.enumerated() {
        // ...existing body...
    }
}

/// Number of classic reminders per day. Derived from the same interval
/// math smart mode uses so the two modes stay in lockstep.
private func classicReminderCount(profile: UserProfile) -> Int {
    let awakeMinutes = max(60, profile.sleepMinutes - profile.wakeMinutes)
    let intervalMinutes = computeInterval(profile: profile) / 60
    return max(1, min(12, Int(round(Double(awakeMinutes) / intervalMinutes))))
}
```

- [ ] **Step 4: Build + run tests**

Run `build_sim` and `test_sim`. Expected: green.

- [ ] **Step 5: Commit and push**

```bash
git add WaterQuest/Services/NotificationScheduler.swift
git commit -m "$(cat <<'EOF'
refactor(notifications): drop dead code, share interval math

Removes the never-used minimumGapSeconds and quietThresholdMultiplier
fields. Extracts classicReminderCount so the two scheduling paths can't
drift in their interval calculation. The removeAllDeliveredNotifications
call was already deleted in the context refactor — confirmed no stragglers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Task 12 — Simulator integration verification

Everything up to now has been unit-tested logic plus build-green changes. This task puts the full pipe through its paces on a simulator. No code changes expected unless a bug surfaces.

**Tooling:** XcodeBuildMCP on iPhone 17 Pro simulator id `72CEFB58-398E-4832-B3B2-EB2CF4A583F6` (per project memory).

- [ ] **Step 1: Build and run on simulator**

Call `build_run_sim` via XcodeBuildMCP. Expected: app launches to the main screen.

- [ ] **Step 2: Configure for fast reminder firing**

Tap through to Settings manually (or via `snapshot_ui` + UI automation if enabled in XcodeBuildMCP — check the server's enabled capabilities). Confirm "Smart reminders" toggle is ON (requires premium — enable premium via the StoreKit testing config at `Products.storekit`, or temporarily set `hasPremiumAccess = true` on the store in a `#if DEBUG` hook).

Set wake time to 1 hour ago and sleep time to 2 hours from now so `computeInterval` returns ~60 minutes and the first reminder fires soon after a log.

- [ ] **Step 3: Log an intake, then wait for the smart reminder**

Log 200 ml from the dashboard. Watch the simulator's notification center — the scheduler should register a batch; use `launch_app_logs_sim` to capture the log output.

Advance the simulator time or wait for the first reminder to fire. Use `screenshot` to confirm:
- Notification body renders (curated copy; AI replacement is premium + iOS 26 only)
- Three action buttons visible: "Log 250 ml", "Log 500 ml", "Snooze 1 hr"

- [ ] **Step 4: Verify `LOG_250ML` action logs silently**

From the notification banner (or the notification center), tap "Log 250 ml". The app should *not* foreground. Open the app — the dashboard should show the 250 ml entry.

- [ ] **Step 5: Verify default tap opens Add Intake sheet**

Tap the *body* of a subsequent reminder. The app should foreground and show the Add Intake sheet (the existing `deepLinkAddIntake` flow).

- [ ] **Step 6: Verify `SNOOZE_1H` cancels and reschedules**

Log another intake, wait for the reminder, tap "Snooze 1 hr". Check via `UNUserNotificationCenter.current().getPendingNotificationRequests` (add a temporary debug log, or use the simulator's push inspector) that:
- The soonest `sipli.smart.*` notification is gone.
- A new `sipli.snooze.*` notification is scheduled ~60 minutes out.

- [ ] **Step 7: Fix any bugs surfaced**

If any step fails, diagnose with `launch_app_logs_sim`, make minimal fixes, rerun that step. Commit fixes as `fix(notifications): <short description>` with the same co-author trailer.

- [ ] **Step 8: Write a QA summary note and commit it**

Create `docs/superpowers/plans/2026-04-17-notification-overhaul-phase-1-qa.md`:

```markdown
# Phase 1 QA Summary — 2026-04-17

**Device:** iPhone 17 Pro simulator (72CEFB58-398E-4832-B3B2-EB2CF4A583F6, OS 26.4)
**Build:** <commit sha>

## Checks

- [x] App builds cleanly
- [x] All unit tests pass
- [x] Smart reminder fires with action buttons
- [x] LOG_250ML logs silently from lock screen
- [x] LOG_500ML logs silently from lock screen
- [x] SNOOZE_1H cancels next reminder and schedules +60min
- [x] Default tap opens Add Intake sheet
- [x] Classic reminder shows time-of-day-aware copy

## Notes

<anything notable observed during QA>
```

Commit:

```bash
git add docs/superpowers/plans/2026-04-17-notification-overhaul-phase-1-qa.md
git commit -m "$(cat <<'EOF'
docs: Phase 1 notification overhaul QA summary

Device-level verification checklist for the foundation PR — action
buttons, deep-link, snooze, classic time-of-day copy.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push
```

---

## Done — ready for Phase 2

After Task 12 the Phase 1 scope is complete:

- Action buttons wire into the store without foregrounding the app.
- Notification body tap opens Add Intake.
- Apple Intelligence generates the soonest smart reminder's copy for premium users.
- Classic mode uses the same curated tiers as smart mode.
- `NotificationContext` snapshot is in place for Phases 2-4 to extend.
- Dead code is gone.

Next up: Phase 2 spec section in `docs/superpowers/specs/2026-04-17-notification-overhaul-design.md` — goal-hit celebration + contextual copy from weather/workout/streak. A fresh plan for Phase 2 gets written when you're ready.
