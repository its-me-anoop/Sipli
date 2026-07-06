# Sipli v5.0 — Design Spec

**Date:** 2026-07-06
**Baseline:** v4.1 (build 11)
**Target:** v5.0 (build 12)

## Why v5.0

Competitive research (WaterMinder, Waterllama, Plant Nanny, Hydro Coach, HidrateSpark, Suu,
Streaks, Duolingo mechanics) shows the market split into three tiers: legacy utility apps,
single-player character apps, and a new social-competitive wave. **No hydration app combines
Duolingo-grade layered mechanics (tiered badges + quests + streak economy) with Apple-ecosystem
depth (Siri, widgets, share surfaces).** Sipli already has the streak-freeze economy, a seasonal
Match Day event, App Intents, and a Control Widget — but no achievement presentation layer, no
share/export code at all, and no mid-term (weekly) retention layer. v5.0 closes exactly those gaps.

Guiding principles carried over from research:

- **Never paywall data correction or basic logging** — the most-repeated competitor complaint.
  All v5.0 engagement features (achievements, quests, share cards) ship **free**.
- **Gamification without guilt** (Gentler Streak) — missed days get supportive copy, not shame.
- **One evolving mascot, not a menagerie** — deepen Sipli's droplet rather than chase
  Waterllama's 140-character moat.
- **No backend, no accounts** — everything local + existing iCloud file sync.

## Feature set

### 1. Achievements ("Trophy Room")

- `Achievement` model: stable string `id`, title, subtitle, category, SF Symbol, optional
  `isSecret`. Catalog is code-defined (`AchievementCatalog`), ~28 badges across categories:
  - **Consistency** — streak milestones (3, 7, 14, 30, 60, 100 days), perfect week.
  - **Volume** — lifetime effective liters (10, 50, 100, 250, 500 L), single-day 150% goal.
  - **Explorer** — distinct fluid types logged (3, 8, 15), first non-water log.
  - **Dedication** — lifetime goal days (7, 30, 100), early bird (<7am log), night owl,
    weekend perfect, freeze banked ×3.
  - **Season** — Golden Bottle (existing ≥12 Match Day wins), first Match Day win.
  - **Secret** (hidden until unlocked) — midnight log, 30-day streak with zero freezes,
    logged via Siri, logged via widget/control, undo master.
- `AchievementEngine`: pure, stateless evaluation `(PersistedState, context) -> Set<id>`;
  unit-testable without UI. Event flags that can't be derived from entries (Siri log, widget log,
  undo) are recorded as counters in `PersistedState`.
- Persistence: `unlockedAchievements: [String: Date]` added to `PersistedState` with
  `decodeIfPresent` so v4.1 states migrate cleanly. Unlocks are retro-evaluated on first v5.0
  launch (long-time users get their earned badges immediately — a delight moment).
- Unlock UX: droplet-confetti overlay + haptic + numericText transitions; queued so multiple
  unlocks present one at a time. Honors `accessibilityReduceMotion`.
- Trophy Room: pushed from Dashboard streak chip and Settings. Layout varies by category
  (hero row for rarest earned badge, sections with distinct treatments — deliberately not a
  uniform icon-card grid). Secret badges render as silhouettes until earned.

### 2. Shareable cards

- `ShareCardView`: branded 1080×1350 (4:5, feed-friendly) SwiftUI composition — progress ring /
  streak flame / mascot / date / subtle wave background. Three variants:
  - **Daily recap** (Dashboard) — today's ml, %, streak.
  - **Weekly recap** (Insights) — 7-day bars, goal-hit count, best day.
  - **Achievement** (unlock overlay + Trophy Room) — badge art + earned date.
- `ShareCardRenderer`: `ImageRenderer` at 3× scale → `UIImage`, exposed through `ShareLink`
  with `SharePreview`. Pure SwiftUI, no backend. Rendering is snapshot-tested at the
  model level (view builds without crash; data formatting unit-tested).

### 3. Weekly quests

- Mid-term retention layer between daily streak and seasonal Match Day.
- `WeeklyQuest` definitions rotate deterministically from ISO week number (same for everyone,
  no server): e.g. "Hit your goal 5 of 7 days", "Log 4 different drinks", "3 logs before noon",
  "Two perfect weekend days". Three active per week.
- `QuestProgress` computed purely from entries + goal history via `QuestCalculator` — nothing
  new persisted, fully unit-testable, immune to sync conflicts.
- Dashboard gets a compact quest card (progress ticks, week countdown). Completing all three in
  a week feeds the "perfect week" achievement.

### 4. Siri / App Intents expansion

New intents wired through the existing `HydrationIntentCore` plumbing, all with voice-aware
dialogs like the current set:

- `GetStreakIntent` — "What's my streak in Sipli"
- `GetRemainingIntent` — "How much more water do I need in Sipli"
- `RepeatLastDrinkIntent` — "Log my usual in Sipli" (repeats last drink's type+amount)
- `OpenTrophyRoomIntent` — "Show my achievements in Sipli"

Parameterized phrases on `LogWaterIntent` (`\(\.$amountInMilliliters)`) where supported.
All logging intents mark the `loggedViaSiri` counter (feeds the secret badge) and donate.

### 5. Animation & liveliness pass

All motion `transform`/`opacity` only, ease-out springs from `Theme`, and every effect gated on
`accessibilityReduceMotion`:

- **Droplet splash** burst at the bottle when a drink is logged (Canvas particles, one-shot).
- **Goal confetti** the moment the daily goal is crossed (once per day).
- **numericText content transitions** on all changing totals/percentages.
- **Symbol effects**: bounce on quick-log taps, wiggle on the streak flame at milestones.
- **Staggered card entrance** on Dashboard first appearance.
- **Mascot evolution**: droplet gains aura/sparkle/crown tiers at streak 7/30/100 —
  procedural (no new assets), subtle by design.

### 6. UI updates (redesign where appropriate)

- Dashboard: streak chip becomes a tappable entry to Trophy Room; quest card added below the
  bottle; share button in the toolbar. No layout overhaul — the bottle stays the hero.
- Insights: weekly recap share button; digest card unchanged.
- Diary: supportive empty/missed-day copy (teach, don't shame).
- Settings: Trophy Room link; everything else untouched.

### Explicitly deferred (not v5.0)

- Live Activities / Dynamic Island — real differentiator but new extension surface + plist
  changes carry release risk (see the Invalid Binary saga); revisit for 5.1.
- Friend duels via CKShare — stretch; needs its own spec.
- Localization, leagues/leaderboards, character collections — out of scope by principle.

## Architecture notes

- New logic lives in pure services (`AchievementEngine`, `QuestCalculator`) mirroring
  `StreakCalculator` — deterministic, no side effects, unit-tested first.
- `HydrationStore` evaluates achievements after each state mutation and publishes
  `newlyUnlockedAchievements` for the overlay queue; store stays the single source of truth.
- `PersistedState` gains `unlockedAchievements: [String: Date]` and an `EngagementCounters`
  struct (siriLogs, widgetLogs, undoCount) — all `decodeIfPresent` with defaults for
  backward-compatible migration; existing tests extended to cover old-payload decoding.
- Widget/watch targets: no functional changes required; rebuild + retest only.

## Testing

- Unit: `AchievementEngineTests` (each category + secrets + retro-evaluation + migration),
  `QuestCalculatorTests` (rotation determinism, progress edge cases, week boundaries),
  new intent tests in the existing `SipliAppIntentsTests` pattern, share-card data formatting.
- Full suite on iPhone 17 Pro (CC) simulator; all targets must build (app, widget, watch,
  watch widgets).
- Manual/simulator verification of unlock overlay, share sheet, Trophy Room, animations.
- Multi-agent adversarial review of the full diff before release.

## Release

- `MARKETING_VERSION = 5.0`, `CURRENT_PROJECT_VERSION = 12`, uniform across all targets.
- Commit + push per change set (standing preference). Release itself ships via the existing
  GitHub Actions path when Anoop triggers it.
