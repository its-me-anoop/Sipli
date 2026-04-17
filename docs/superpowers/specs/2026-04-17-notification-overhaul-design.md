# Notification System Overhaul — Design

**Status:** Proposed
**Date:** 2026-04-17
**Author:** Brainstorming session with Claude
**Related code:** `WaterQuest/Services/NotificationScheduler.swift`

## Problem

The notification system has latent bugs, half-built features, and significant engagement gaps. Real issues:

- `generateMessage()` (Apple Intelligence path) exists but is never called in the scheduling path; curated messages are used for every notification.
- `didFireEscalation` state and `escalationMessages` pool exist, but `isEscalation` is hard-coded `false` — escalation was scaffolded and abandoned.
- iPhone notifications have no registered `UNNotificationCategory`, so tapping a notification is the only action. (The Watch has a "Log 250ml" button via its own handler.)
- Notifications don't carry a deep link — tapping just opens the app to whatever view was last shown.
- `removeAllDeliveredNotifications()` fires on every `scenePhase == .active`, wiping the user's Notification Center history whenever they open the app for any reason.
- `minimumGapSeconds` is declared but never referenced.
- Classic mode (free tier) uses a static 5-line copy pool with no progress/time awareness.
- Messages never use weather, workouts, streaks, or user name despite all four being available in the app.
- Goal-hit, streak milestones, and 50% progress all emit silence — the highest-value habit-reinforcement moments in the funnel are dark.
- No absence-recovery flow — ghosted users keep getting stale reminders (or none at all in classic mode).
- No habit-stacking anchors — reminders are equal-spaced from wake, not tied to existing daily routines (post-workout, post-meal) that research shows produce stronger habit formation.
- No learned-pattern scheduling — histogram of the user's actual log times is never used.
- No streak-aware urgency — an at-risk 10-day streak reminder looks identical to a morning nudge on day 1.
- App `.badge` authorization is requested but never set.
- No implementation-intentions onboarding (Gollwitzer's "when X happens I will Y" — roughly doubles habit adherence in the literature).

## Goals

- **Fix the real bugs** so the shipped notification system matches what the code/comments promise.
- **Close engagement gaps** by making notifications contextual, celebratory, and behavior-anchored.
- **Build habit-formation leverage** via post-workout anchors, absence recovery, learned patterns, and implementation intentions.
- **Preserve existing premium split** — smart mode stays a Premium feature; new personalization layers on top of the existing `hasAccess(to: .smartReminders)` gate.
- **Ship in independently valuable phases** so each PR delivers user-visible value and can be reviewed/reverted independently.

## Non-goals

- No redesign of the classic-mode free tier beyond making its copy progress-aware. Classic stays minimally differentiated from smart to preserve Premium conversion pressure.
- No social or shared-notification features.
- No push notifications from a backend — all scheduling remains local (`UNNotificationRequest`).
- No cross-device coordination beyond what `PhoneSessionManager` already handles.
- No notification-driven gamification (XP, badges, quests) — that is a separate future initiative deliberately paused earlier in this conversation.

## Phasing

Four PRs, each independently valuable.

| Phase | Scope | Est. effort |
|-------|-------|-------------|
| **1 — Foundation** | #1 action buttons, #2 deep-link, #5 AI wire-up, bug cleanups (#2, #5, #6, #7) | ~1 day |
| **2 — Context + celebration** | #3 goal-hit celebration, #4 contextual copy | ~2-3 days |
| **3 — Habit anchors** | #6 post-workout anchor, #7 absence recovery | ~3-4 days |
| **4 — Smart system** | #8a learned patterns, #8b anchor onboarding, #8c streak urgency, #8d app badge | ~1-2 weeks |

Phase numbering matches the review conversation that preceded this spec. Each phase ships behind the existing Smart Reminders premium gate where the feature is genuinely premium (AI, learned patterns, workout anchors); bug fixes and categories apply to both tiers.

## Architecture

### `NotificationContext` snapshot

`NotificationScheduler` currently takes `profile + entries + goalML`. Phase 1's AI wire-up already needs richer inputs (progress + streak for prompt), and Phases 2+ add weather, workout, anchors, and last-log timestamp. Rather than inject four services (`HydrationStore`, `WeatherClient`, `HealthKitManager`, `SubscriptionManager`) into the scheduler — which would couple the scheduler to the full app graph and make it hard to test — introduce an immutable context snapshot in Phase 1 and extend it in later phases:

```swift
struct NotificationContext {
    let profile: UserProfile
    let entries: [HydrationEntry]
    let goalML: Double
    let currentStreak: Int
    let weather: WeatherSnapshot?
    let recentWorkout: WorkoutSummary?
    let reminderAnchors: [ReminderAnchor]
    let lastLogAt: Date?
    let logTimeHistogram: [Int: Int]?  // hour → log count, nil until 14 days of data
    let hasPremiumAccess: Bool
}
```

Callers (`WaterQuestApp.body.task/onChange`, `SettingsView.rescheduleReminders`, `HydrationStore.onIntakeLogged`) assemble the context and pass it to `scheduleReminders(context:)`. Scheduler stays pure — given a context, it produces a set of notification requests.

### Notification categories

New file `Services/NotificationCategories.swift` registers categories at app launch (called from `WaterQuestApp.init`):

- `HYDRATION_REMINDER` — actions: `LOG_250ML`, `LOG_500ML`, `SNOOZE_1H`
- `HYDRATION_CELEBRATION` — no actions (tap opens Insights for the streak moment)
- `HYDRATION_COMEBACK` — actions: `LOG_GLASS`, `NOT_TODAY` (absence recovery; "Not today" suppresses for 24h)
- `HYDRATION_WORKOUT` — action: `LOG_GLASS` (post-workout anchor)

Action identifiers are stable constants on a `NotificationActionID` enum.

### `NotificationHandler` (`UNUserNotificationCenterDelegate`)

New file `Services/NotificationHandler.swift`, owned by `WaterQuestApp`. Responsibilities:

- Implements `userNotificationCenter(_:didReceive:)` to dispatch action taps.
- For `LOG_250ML` / `LOG_500ML` / `LOG_GLASS` → calls `HydrationStore.log(amount:source:fluidType:note:)` in-process (no app foreground needed; `content.authenticationRequired = false` lets locked devices log).
- For `SNOOZE_1H` → removes pending smart reminders, re-schedules a single reminder 1 hour out.
- For `NOT_TODAY` → writes `lastAbsenceRecoveryAt = Date()` to suppress further comeback nudges for 24h.
- For default tap (no action) → reads `userInfo["deepLink"]`, sets `deepLinkAddIntake = true` via an `@AppStorage`-backed flag the app already reads.
- Must be retained by `WaterQuestApp` to remain as the UNCenter delegate for the app's lifetime.

## Feature designs

### #1 — Log action buttons

**Change.** `scheduleSmartReminders` and `scheduleClassicReminders` each already set `content.categoryIdentifier = "HYDRATION_REMINDER"`. With the new `NotificationCategories` registration, this wires up. No scheduler change beyond the registration.

**Behavior.** Pressing `LOG_250ML` on a locked device records a 250 ml entry silently and clears the notification. Pressing `LOG_500ML` records 500 ml. Pressing `SNOOZE_1H` cancels the next pending smart reminder and schedules a single fire 60 minutes later.

**Decision (locked):** Default log amount = 250 ml (hardcoded for this phase; a quick-log preference is a later pass).

### #2 — Deep-link on tap

**Change.** Every notification's `UNMutableNotificationContent.userInfo` gets `"deepLink": "sipli://add-intake"`. `NotificationHandler.userNotificationCenter(_:didReceive:)` with action `UNNotificationDefaultActionIdentifier` posts the existing deep-link signal.

The app already handles `sipli://add-intake` via `deepLinkAddIntake` environment key in `WaterQuestApp.swift`. No new plumbing on the consuming side.

### #3 — Celebratory goal-hit notification

**Change.** `HydrationStore.checkGoalCompletion()` already fires on goal-crossing. Add a call:

```swift
notificationScheduler?.scheduleGoalCelebration(context: buildContext())
```

**Scheduler addition.** New `scheduleGoalCelebration(context:)`:
1. Remove any remaining pending smart reminders for today (so the user doesn't get more nags after hitting goal).
2. Schedule one immediate `HYDRATION_CELEBRATION` notification (1-second trigger).
3. Copy varies by `context.currentStreak`:
   - Streak 1: "Goal hit! Day 1 of your streak starts now."
   - Streak 2-6: "Day N locked in. Keep it going."
   - Streak 7: "7-day streak! Your body's thanking you."
   - Streak 14/30/60/100: milestone copy.
   - Other: generic celebration.
4. AI generation (when premium + Apple Intelligence) uses streak + goal amount as prompt inputs.

### #4 — Contextual copy

**Change.** Replace `curatedMessage(progress:isEscalation:)` with `messageFor(context:slot:)` where `slot` is an enum `{ first, mid, late, escalation, celebration, workout, comeback }`.

**Priority ladder** (first match wins):
1. **Streak urgency** (`context.currentStreak >= 7 && time > sleep - 2h && progress < 0.8`): "Your N-day streak — one more glass and it's yours."
2. **Workout rehydration** (`context.recentWorkout` within 2h): "Nice N-minute run — rehydrate."
3. **Weather extremes** (`context.weather.tempC > 28` or `< 0`, or `humidity > 80`): "It's 32°C — extra glass today."
4. **Time-of-day + progress**: morning kickoff, midday check-in, evening push.
5. **Generic curated fallback**.

**AI.** The Apple Intelligence prompt receives a structured block:

```
User streak: 7 days
Progress: 45% of 2400 ml
Recent workout: 30min run, 90 minutes ago
Weather: 32°C, 60% humidity
Time of day: 2:30 PM
```

Model replies with a single ≤12-word message. Falls back to the curated ladder on failure.

### #5 — Wire AI generation

**Change.** `scheduleSmartReminders` currently calls `curatedMessage` synchronously at line 157. Split into two paths:

- **Only the first (soonest-firing) notification in a batch**: uses AI (async). The scheduling pass schedules all notifications synchronously with curated copy first (so scheduling can't be blocked), then dispatches a follow-up `Task` that awaits `generateAIMessage(context:)` with a 2-second timeout. On success, the task cancels the first-fire notification and re-schedules it with the AI-generated copy under a different identifier. On failure/timeout, the curated-copy notification stands.
- **All other batch notifications**: use `messageFor(context:slot:)` synchronously. They get regenerated when the app foregrounds or the user logs intake (existing reschedule hooks), so by the time they actually fire the copy often came from a recent AI pass.

**Gating (D1, locked):** AI path is gated on `context.hasPremiumAccess` to stay consistent with the existing `smartRemindersEnabled` premium gate. Free users get curated.

**Cleanup.** If `SystemLanguageModel.default.isAvailable` is false, the path short-circuits immediately (no wasted latency).

### #6 — Post-workout anchor

**Change.** Extend `HealthKitManager`:
- New method `startWorkoutObserver(onNewWorkout:)` registers an `HKObserverQuery` on `HKWorkoutType.workoutType()`.
- Observer callback fetches the latest workout via a small `HKSampleQuery` (limit: 1, sort by end date desc).
- Callback posts `WorkoutSummary` to the app; `WaterQuestApp` forwards to `NotificationScheduler.onWorkoutCompleted(_:context:)`.

**Scheduler addition.** `onWorkoutCompleted(workout:context:)`:
1. Compute fire date = `workout.endDate + 20 minutes`.
2. Guard: fire date is within awake window (≥ `wake` and ≤ `sleep`).
3. Guard: goal not already met.
4. Cancel any existing workout-anchor notification (`sipli.workout.*` identifier prefix).
5. Schedule single fire with `HYDRATION_WORKOUT` category. Copy: "Nice N-minute {type} — rehydrate."

**Authorization.** Workout read authorization is already requested in `HealthKitManager.requestAuthorization()` based on existing references. No new prompt.

### #7 — Absence recovery

**Change.** Add `lastLogAt: Date?` and `lastAbsenceRecoveryAt: Date?` to `PersistedState`. `HydrationStore.logEntry(...)` updates `lastLogAt`.

**Scheduler logic.** On each `scheduleReminders(context:)` pass:
- If `context.lastLogAt` is older than 48h AND `lastAbsenceRecoveryAt` is older than 24h (or nil):
  - Skip the normal smart schedule.
  - Schedule a single `HYDRATION_COMEBACK` notification for the next morning at `wakeMinutes + 60`.
  - Copy: warm, low-pressure. "We missed you — one sip counts today."
- On the next `onIntakeLogged`, auto-exits recovery mode (normal scheduling resumes).

Tapping `NOT_TODAY` writes `lastAbsenceRecoveryAt = Date()`, suppressing for another 24h.

### #8a — Learned-pattern scheduling

**Change.** `HydrationStore` exposes `logTimeHistogram: [Int: Int]` (hour 0-23 → count of logs in that hour over the last 30 days). `nil` until ≥ 14 days of log history.

**Scheduler logic.** When `context.logTimeHistogram` is non-nil:
1. Compute mean logs-per-hour across awake hours as baseline.
2. For each awake hour, compute a weight = `max(0.2, 1 - (logs_in_hour / max_logs))` — hours where the user rarely logs get weight near 1, their most-active hour gets weight 0.2 (never fully silent).
3. Produce a "learned schedule": pick N reminder times where N = current equal-spacing count, sampled proportionally to weights. Enforce 60-min minimum between picks.
4. Blend factor `b` grows linearly from 0.0 at 14 days of history to 1.0 at 30 days. Final schedule = `b * learned + (1 - b) * equal_spaced`, implemented as: pick each slot from learned with probability `b`, else from equal-spaced.

Falls back to current equal-spacing when histogram is nil.

### #8b — Anchor onboarding (implementation intentions)

**Change.** New section in `SettingsView`: "Reminder Anchors" (under the existing Reminders block).
- User adds up to 3 anchors: morning, afternoon, evening.
- Each anchor = `{ label: String, timeMinutes: Int }`. Example: "After coffee, 7:30 AM."
- Anchors saved to `UserProfile.reminderAnchors: [ReminderAnchor]`.

**Scheduler logic.** Anchors are scheduled as dedicated `HYDRATION_REMINDER` notifications at their specified times. They co-exist with the smart pool (smart pool spacing accounts for anchor times to avoid immediate double-fires — minimum 30 min gap).

**Existing-user prompt.** One-time Insights card "New: set your hydration triggers" with CTA to the Settings section. Dismissible; tracked by `hasSeenAnchorOnboarding: Bool` in `PersistedState`.

**Onboarding flow** (new users only): add a skippable step after existing reminders step. Research note included as onboarding copy: "Apps that anchor reminders to existing habits double adherence in the literature."

### #8c — Streak urgency escalation

**Change.** Wire the existing `didFireEscalation` state.

**Scheduler logic.** At each scheduling pass, if all hold:
- `context.currentStreak >= 7`
- Current time > `sleepMinutes - 120` (last 2 hours before bed)
- Today's progress < 80% of goal
- `didFireEscalation == false` for today

Then replace the next pending smart-reminder notification with an urgent variant:
- Cancel the next pending `sipli.smart.*` notification (soonest fire date).
- Schedule a new notification with the same fire time, but with:
  - `content.interruptionLevel = .timeSensitive` (pierces Focus mode)
  - Copy: "Your N-day streak needs one more glass."
  - Identifier: `sipli.escalation.<batchID>`
- Set `didFireEscalation = true` for today; reset at midnight via the daily scheduling pass on foreground.

If no pending smart reminder exists (all already fired), schedule a single fresh one for `now + 60 seconds`.

**Decision (locked, D3):** `.timeSensitive` is acceptable for streaks ≥ 7. Rare, high-stakes, and users with long streaks are opted into the intensity by virtue of their engagement.

### #8d — App badge

**Change.** Compute `glassesRemaining = ceil(max(0, (goal - todayTotal) / 250))`.

**Update sites:**
- After every log in `HydrationStore.logEntry(...)` → `UNUserNotificationCenter.current().setBadgeCount(glassesRemaining)`.
- After goal met → `setBadgeCount(0)`.
- At day rollover (on foreground check) → recompute.
- Each scheduled notification sets `content.badge = NSNumber(value: glassesRemaining)` so iOS keeps the badge in sync when notifications fire in the background.

## Data model changes

**`UserProfile`** (+1 optional field, backward compatible via `decodeIfPresent`):

```swift
var reminderAnchors: [ReminderAnchor]  // default: []
```

**`ReminderAnchor`** (new):

```swift
struct ReminderAnchor: Codable, Identifiable {
    let id: UUID
    var label: String         // e.g. "After coffee"
    var timeMinutes: Int      // minutes past midnight
}
```

**`PersistedState`** (+3 optional fields):

```swift
var lastLogAt: Date?
var lastAbsenceRecoveryAt: Date?
var hasSeenAnchorOnboarding: Bool  // default: false
```

`logTimeHistogram` is derived at read time from `entries` — not persisted.

## Files touched

**New:**
- `WaterQuest/Models/NotificationContext.swift`
- `WaterQuest/Models/ReminderAnchor.swift`
- `WaterQuest/Services/NotificationHandler.swift`
- `WaterQuest/Services/NotificationCategories.swift`

**Modified:**
- `WaterQuest/Services/NotificationScheduler.swift` — major: context parameter, new scheduling paths (celebration, workout, comeback), AI wired, streak urgency wired, dead code removed
- `WaterQuest/Services/HealthKitManager.swift` — workout observer
- `WaterQuest/Services/HydrationStore.swift` — `lastLogAt`, `logTimeHistogram`, celebration hook, badge update
- `WaterQuest/Models/UserProfile.swift` — `reminderAnchors`
- `WaterQuest/Models/PersistedState.swift` — `lastLogAt`, `lastAbsenceRecoveryAt`, `hasSeenAnchorOnboarding`
- `WaterQuest/Views/OnboardingView.swift` — optional anchor step
- `WaterQuest/Views/SettingsView.swift` — Reminder Anchors section
- `WaterQuest/App/WaterQuestApp.swift` — register categories, install delegate, badge updates on scenePhase

**Also updated:**
- `WaterQuest/Views/InsightsView.swift` — one-time anchor onboarding card (Phase 4 only)

## Error handling

- **Notification authorization denied.** All scheduling calls no-op if `authorizationStatus != .authorized`. Existing `remindersEnabled` guard remains.
- **AI failure.** Any error or >2s latency from `FoundationModels` → fallback to curated copy. Never blocks scheduling.
- **HealthKit authorization revoked.** Workout observer silently fails; `NotificationContext.recentWorkout` is nil; ladder falls through to next priority.
- **WeatherKit unavailable.** `context.weather` is nil; weather tier of copy ladder is skipped.
- **Invalid user-set anchor time** (outside awake window): ignored by scheduler; no error surfaced in UI — anchor still saves, just doesn't fire.
- **Notification tap on cold launch** (app not running). `NotificationHandler` is registered in `WaterQuestApp.init()` before any view loads, so delegate is alive when iOS dispatches the notification. `LOG_*` actions work pre-setup only if onboarding was completed; otherwise ignored.
- **Backward-compatible decoding.** `UserProfile` and `PersistedState` both add optional fields using `decodeIfPresent` — existing user data loads unchanged.

## Testing

- **Unit tests** for `messageFor(context:slot:)`: each priority tier, fallbacks, edge cases (streak 0, no weather, no workout).
- **Unit tests** for scheduler interval math: compute reminder times for given wake/sleep windows with + without anchors + with + without histogram.
- **Unit tests** for absence-recovery transition: entry older than 48h triggers comeback; fresh entry exits.
- **Integration tests** (simulator): fire an immediate notification, assert actions render via `snapshot_ui`, tap action, assert store state updated.
- **Manual QA checklist** (documented in each phase's PR):
  - Log action on locked device records entry.
  - Snooze action reschedules to +60 min.
  - Tapping notification body opens Add Intake sheet.
  - Goal-hit celebration fires once per day.
  - `.timeSensitive` escalation pierces Focus (requires physical device with Focus mode on).
  - Workout end → anchor fires 20 min later.
  - App badge matches glasses-remaining at all times.

## Rollout

- **Phase 1** introduces `NotificationContext` (minimal fields: `profile`, `entries`, `goalML`, `currentStreak`, `hasPremiumAccess`), registers notification categories, installs `NotificationHandler`, wires AI. Context is the single architectural change in Phase 1; all three callers (`WaterQuestApp`, `SettingsView`, `HydrationStore`) update atomically. Completely backward compatible at the user-data level — existing users see action buttons on notifications next time they fire.
- **Phase 2** extends `NotificationContext` with `weather` and `recentWorkout` fields (optional, default nil) and adds the celebration + contextual-copy paths.
- **Phase 3** requires workout observer + 48h absence state. Existing users will pick up their first workout anchor on the next workout after install. Absence-recovery backfills `lastLogAt` from the most recent entry on migration.
- **Phase 4** histograms self-build over time; existing users with >14 days of history get learned scheduling immediately after update. Anchor onboarding card shows once.

## Metrics (manual for now; telemetry is a later pass)

Track in-session via debug logs (behind `#if DEBUG`):
- Notifications scheduled vs. delivered vs. tapped (per category).
- Action-button usage rate vs. body-tap rate.
- AI-vs-curated copy ratio.
- Goal-hit celebrations fired per user per week.
- Absence-recovery entries (how often users re-enter from a comeback notification).

## Open questions

None — all four decisions (D1 premium AI, D2 default 250ml, D3 streak ≥ 7, D4 phased 4 PRs) are locked.
