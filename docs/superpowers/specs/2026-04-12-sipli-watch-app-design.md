# Sipli Watch App — Design Spec

**Date:** 2026-04-12
**Status:** Draft
**Target:** watchOS 11+ (Apple Watch Series 6+)

## Overview

A companion watchOS app for Sipli (WaterQuest) that provides glanceable hydration progress, quick intake logging from the wrist, complications/interactive widgets, and haptic reminders. The Watch app works independently for core features and syncs with the iPhone for advanced features.

## Architecture

### Target & Shared Code

- **New Xcode target:** `SipliWatch` (watchOS 11 standalone app)
- **Shared framework/target:** `SipliShared` — extracted code used by iPhone, Watch, and Widget
  - Models: `HydrationEntry`, `UserProfile`, `FluidType`, `GoalBreakdown`, `PersistedState`, `UnitSystem`
  - Services: `PersistenceService`, `GoalCalculator`, `Formatters`, `DateExtensions`
- iPhone-only (not shared): `WeatherClient`, `LocationManager`, `SubscriptionManager`, `HealthKitManager` (Watch gets its own lighter version), `MotionManager`, `HydrationAIService`

### Data Sync

```
iPhone App ──write──▶ App Group JSON ◀──read/write── Watch App
                          │
                     iCloud KVStore
                     (cross-device)
                          │
                      SipliWidget ──read──▶
```

- Both apps read/write to the same App Group container (`group.com.waterquest.hydration`)
- iCloud `NSUbiquitousKeyValueStore` handles cross-device sync (existing mechanism)
- Conflict resolution: timestamp-based, newest wins (existing `PersistenceService` logic)
- Watch writes are immediately persisted locally and propagate to iPhone via iCloud within seconds

### Watch-Side State Management

- `WatchHydrationStore` — `ObservableObject` scoped to Watch needs:
  - Today's `[HydrationEntry]`
  - `UserProfile` (read from synced state)
  - `GoalBreakdown` (read from synced state, computed on iPhone)
  - Premium status (read from synced state)
- Reads/writes via the shared `PersistenceService`
- No Combine pipelines for weather/location/subscription — those stay on iPhone

### What Stays iPhone-Only

| Feature | Reason |
|---------|--------|
| WeatherKit / Location | Watch reads the computed weather-adjusted goal from synced `GoalBreakdown` |
| SubscriptionManager | Watch reads premium status from synced `PersistedState` |
| Onboarding | Setup happens on iPhone; Watch requires iPhone setup first |
| Insights / Analytics | Too complex for small screen; iPhone-only feature |
| AI Coaching | iPhone-only feature |
| Motion animations | iPhone-specific visual feature |

## Screens

### 1. Dashboard (Home)

The primary screen shown when the app launches or a complication is tapped.

- **Circular progress ring** — large, center of screen, shows hydration % with current/goal volume text (e.g., "68% · 1.6L / 2.4L")
- **Stats pills** — below the ring, two compact pills: drink count ("💧 6 drinks") and remaining ("🎯 800ml left")
- **"+ Add Water" button** — prominent primary action button below stats
- **Scroll down** — reveals Today's Log inline (screen 4)

### 2. Quick Add

Reached by tapping "+ Add Water" from Dashboard.

- **Amount picker** — Digital Crown scrolls through preset amounts: 150ml, 200ml, 250ml (default), 330ml, 500ml, 750ml
- **"Log Water" button** — logs the selected amount as water with haptic `.success` confirmation, returns to Dashboard
- **"More beverages →" link** — navigates to Fluid Type Picker (screen 3)
- Amounts displayed in user's preferred unit system (ml or fl oz)

### 3. Fluid Type Picker

Reached by tapping "More beverages" from Quick Add.

- **Scrollable list** of user's top 6 most-used fluid types, derived from iPhone entry history
- Each row: fluid icon + display name
- Tapping a fluid type selects it and returns to Quick Add with that type pre-selected
- Default favorites if no history: Water, Coffee, Tea, Sparkling Water, Juice, Milk

### 4. Today's Log

Shown inline below the Dashboard when scrolling down.

- **Chronological list** of today's entries (newest first)
- Each row: fluid icon, name, volume, and timestamp (e.g., "💧 Water · 250ml · 9:15am")
- **Swipe to delete** individual entries
- Empty state: "No drinks logged yet today"

### Navigation Flow

```
Dashboard → tap "Add Water" → Quick Add → tap "Log" → Dashboard (with haptic ✓)
Dashboard → tap "Add Water" → Quick Add → "More beverages" → Fluid Picker → select → Quick Add → "Log"
Dashboard → scroll down → Today's Log
Complication tap → Dashboard
Interactive Widget tap → logs 250ml water instantly (haptic ✓, no app launch)
```

Maximum depth: 3 taps for non-water beverages. 1 tap for water via widget.

## Complications

### Circular Complication

- Displays a progress ring showing hydration %
- Center text: current volume / goal (e.g., "1.6 / 2.4L")
- Tapping opens the Watch app to Dashboard
- Supports: `accessoryCircular` widget family (watchOS 10+ WidgetKit)

### Corner Gauge Complication

- Small arc gauge with % fill
- Minimal text: just the percentage
- Supports: `accessoryCorner` widget family (watchOS 10+ WidgetKit)

## Interactive Widget (WidgetKit)

- **Quick Add Widget** — shows current hydration progress bar + "💧 +250ml" button
- Tapping the button logs 250ml water via `AppIntent` (same pattern as iPhone's `QuickAddWaterIntent`)
- No app launch required — the intent writes directly to the shared App Group
- Haptic `.success` confirmation on tap
- Widget refreshes timeline after logging to show updated progress

## Haptic Feedback

| Event | Haptic Type | Feel |
|-------|-------------|------|
| Intake logged | `.success` | Short double-tap confirmation |
| Daily goal reached | `.notification` | Celebratory pattern |
| Reminder nudge | `.directionUp` | Gentle wrist tap |

## Reminders

### Sync Mechanism

- iPhone's `NotificationScheduler` remains the source of truth for reminder configuration
- Reminder preferences (intervals, waking hours, enabled/disabled) sync to Watch via `UserProfile` in the shared `PersistedState`
- watchOS routes notifications to the wrist automatically when Watch is worn (built-in Apple behavior)

### Watch-Specific Behavior

- Notification includes inline **"Log 250ml"** action button — user can log without opening the app
- If daily goal is already met, remaining reminders for that day are suppressed (Watch checks locally)
- Reminders respect configured wake/sleep hours from `UserProfile.wakeMinutes` / `UserProfile.sleepMinutes`

### What We Don't Build

- No separate reminder settings UI on Watch — all configuration on iPhone
- No smart reminders logic on Watch — iPhone computes the schedule, Watch receives it

## HealthKit Integration

### Watch-Side Writes

- Watch writes hydration entries to HealthKit directly using a lightweight `WatchHealthKitManager`
- Entries appear in Apple Health immediately, no iPhone sync dependency
- New `HydrationEntry.source` case: `.watchManual` to distinguish Watch-logged entries

### Deduplication

- Apple syncs HealthKit across paired devices automatically
- Both iPhone and Watch share the same app bundle ID family
- `PersistenceService` deduplicates by entry UUID — entries synced via both iCloud and HealthKit won't double-count

### iPhone-Only HealthKit

- Workout reading (exercise minutes for goal adjustment) stays on iPhone
- Watch receives the computed `GoalBreakdown` with workout adjustments already applied
- HealthKit authorization: if not already granted, Watch prompts user to open iPhone Settings

## Design System

- Reuse Sipli's existing `Theme.swift` color palette: `lagoon` primary, `coral`/`mint`/`sun` accents
- watchOS-appropriate typography (system fonts with Dynamic Type)
- Progress ring matches iPhone's `ProgressRing` component style
- Dark background by default (standard watchOS)
- Animations: keep minimal — `quickSpring` for transitions, no complex fluid animations on Watch

## Out of Scope (v1)

- Workout tracking / workout app integration
- Water temperature logging
- Social / sharing features
- Siri Shortcuts on Watch (can be added later)
- Multiple watch face complication themes
- Historical data browsing (past days) — iPhone only
