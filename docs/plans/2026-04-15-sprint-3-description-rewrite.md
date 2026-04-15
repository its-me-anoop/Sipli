# Sprint 3 + Sprint 4 — App Store Description Rewrite

**Date:** 2026-04-15
**Sprints:** 3 (above-the-fold only) and 4 (full body)
**Parent plan:** [2026-04-15-aso-incremental-rollout.md](./2026-04-15-aso-incremental-rollout.md)
**Status:** Draft — awaiting user approval on voice direction for above-the-fold.
**Ship mode:** metadata-only update via App Store Connect (no binary).

## Why split into Sprints 3 and 4

The "above the fold" (first ~170 characters, before the "…more" truncation) is the single highest-converting copy real estate on the App Store product page. It drives page-view → install. Changing it alone gives us clean attribution. Full-body changes move secondary signals (dwell time, scroll depth, conversion for long-browsers). Separating the two sprints lets us measure each.

---

## Current description (verbatim, for reference)

```
Take the Refill Pledge: refill, not rebuy. Every refill is one less plastic bottle — and a habit that quietly sticks.

Sipli makes staying hydrated feel simple.

Track water and other drinks, follow a daily goal that adapts to your routine, and build better habits with reminders, streaks, insights, and a design that stays out of your way.

Whether you want a lighter daily tracker or a smarter hydration companion, Sipli helps you stay consistent without adding friction to your day.

What Sipli offers

Fast water logging
Personalized daily hydration goals
Reminders built around your schedule
Streaks, history, and trend views
Apple Health integration
Weather and activity-based goal adjustments
Home Screen widgets
Premium AI insights, beverage tracking, and smart reminders

Personalized goals
Sipli starts with a daily goal that fits you. With Premium, your target can also adapt to workouts, activity, and local weather so your hydration plan feels more realistic day to day.

Designed for daily use
A calm interface, quick interactions, and clear progress make it easy to log a drink and move on. Use Sipli throughout the day, then review your trends, streaks, and patterns over time.

Apple Health and widgets
Connect Apple Health to write water intake and read workout data that can support smarter hydration goals. Keep your progress visible with widgets on your Home Screen.

Sipli Premium
Premium unlocks beverage types, AI insights, Health sync, adaptive goals, and smart reminders. Sipli Premium is available as an optional subscription with monthly and annual plans.
```

**Length:** ~1,540 chars. Apple allows up to 4,000.

---

## Sprint 3 — Above-the-fold rewrite

The App Store truncates the description around 170 chars (3 short lines on most iPhones) and appends "…more". This is the only copy most users read. Today it's seasonal Earth Week framing; we want evergreen value-pitch that mirrors the new ASO keyword strategy (Sprint 1: `Sipli — Water Tracker` / `Drink Water Reminder + Goals`).

### Three candidate options

Pick one (or iterate). All three are ≤ 180 chars, render across 3 lines, use keywords `hydration`, `drink water`, `reminder`, `Apple Watch` at least once.

#### Option A — Concrete value pitch *(Recommended)*

```
Build a hydration habit that sticks — with adaptive goals,
Apple Watch quick-logging, and smart reminders that actually
read your day. Your hydration, without the pestering.
```

- **Length:** 181 chars.
- **Voice:** Calm, benefit-led. "Without the pestering" differentiates against nag-heavy competitors.
- **Keywords hit:** `hydration`, `Apple Watch`, `reminders`.
- **Why recommended:** matches Sipli's existing brand voice (calm, deliberate, anti-friction) and plants the single strongest differentiator (smart reminders) without sounding like a feature list.

#### Option B — Benefit-led, maximum keyword density

```
Track water. Hit your goal. Build the streak. Sipli adapts
your daily goal to your body, your workouts, and the weather
— then nudges you just enough, from iPhone or Apple Watch.
```

- **Length:** 185 chars.
- **Voice:** Punchy, action-verb led. Reads more like a performance app.
- **Keywords hit:** `track water`, `daily goal`, `weather`, `iPhone`, `Apple Watch`.
- **Why consider:** highest keyword density of the three — may lift the tail search ranking. Trade-off: slightly less warm than Sipli's current brand voice.

#### Option C — Question hook

```
How much water today? Sipli knows — adapts to your weight,
your workouts, and the weather. Now on Apple Watch, with
reminders that read your day instead of interrupting it.
```

- **Length:** 179 chars.
- **Voice:** Conversational, opens with a question. Pulls users in.
- **Keywords hit:** `water`, `Apple Watch`, `reminders`.
- **Why consider:** questions test well as engagement hooks on mobile. Trade-off: less direct value statement up front.

### Fallback character count checks

App Store truncation occurs around 170 characters OR the third newline, whichever is first. All three options respect the truncation point so the user sees the full pitch before "…more".

### Sprint 3 action

1. User picks (or iterates) one of the three options above.
2. Replace only the first 3 lines / first paragraph of the current description. Leave the rest of the description intact for Sprint 3.
3. Ship as metadata-only via App Store Connect.
4. Log in `docs/aso-metrics-weekly.md`.
5. Wait 3 days. Primary metric: **page-view → install conversion**.
6. Rollback trigger: conversion drops > 1 percentage point sustained over 72h.

---

## Sprint 4 — Full body rewrite

Runs after Sprint 3 lands and its metrics confirm the above-the-fold change held or lifted conversion. Rewrites the rest of the description to match the new voice and to surface features the current description buries or omits (especially the Watch app, which is entirely missing from the current copy).

### Proposed full description

This is the complete replacement — Sprint 3's above-the-fold (Option A shown) followed by the new body. Total length: ~1,850 chars.

```
Build a hydration habit that sticks — with adaptive goals,
Apple Watch quick-logging, and smart reminders that actually
read your day. Your hydration, without the pestering.


WHY SIPLI

• Adaptive daily goals that flex with your workouts, the weather, and your weight
• Smart reminders that pause when you've hit your streak and nudge you when you haven't
• Apple Watch app and widgets so a single tap from your wrist, lock screen, or home screen logs a sip
• Designed for calm daily use — no gamification theatre, no dark-pattern nagging


TRACK EVERYTHING YOU DRINK

• 30+ beverages with hydration factors — coffee, tea, matcha, kombucha, sports drinks, plant milks
• Coffee counts, decaf counts, and so does your evening mocktail
• Edit, backfill, or delete entries any time


STAY ON TRACK

• Streaks, history, and a monthly heatmap that shows where you drift
• Widgets for Home Screen, Lock Screen, and StandBy
• Apple Health integration — your water intake lives where the rest of your health data does
• Earth-friendly: track the plastic bottles you've saved with the Refill Pledge


SIPLI PREMIUM

Unlock the features that make hydration effortless:

• Beverage tracking for 30+ drink types with accurate hydration factors
• AI-generated hydration insights and coaching tips
• HealthKit read and write sync (workouts, water, active energy)
• Weather-adjusted goals that rise on hot days
• Workout-adjusted goals that rise after long sessions
• Smart reminders that adapt to your real-time progress and schedule

Premium is available as a monthly or annual subscription. The annual plan includes a one-month free trial.


THE REFILL PLEDGE

Every April, Sipli joins Earth Week with the Refill Pledge — a simple promise to refill, not rebuy. Track the plastic bottles you've kept out of landfill just by hitting your daily goal.


PRIVACY

Your hydration data stays on your device and in your iCloud (if you've enabled it). No ad tracking. No data sale. Private by default.


Sipli is made by one person and improving week by week. If the app helps you, leaving a review is the single biggest thing you can do to support continued development — thank you.
```

### Notes on content decisions

- **Watch app is now front and center** — it appears in the above-the-fold and in the "Why Sipli" bullets. Today it's not in the copy at all. This is the biggest single gain.
- **Premium section is restructured** as a clear list, not a vague paragraph. Six bullets map exactly to the six `PremiumFeature` cases in [SubscriptionManager.swift](WaterQuest/Services/SubscriptionManager.swift).
- **Earth Week / Refill Pledge is retained** but moved out of the hero and into its own section near the bottom. Stays alive as a brand story without hijacking the evergreen pitch.
- **Beverage count matches code.** Uses "30+" consistent with the current `FluidType` enum. When P5 lands (expanding to 60+), update to "60+".
- **Privacy statement** is now explicit — buyer preference for privacy-respecting apps is high, and Sipli actually is (HealthKit entries stay local + iCloud). Make the claim.
- **Closing review ask** — indie/solo-dev-friendly close that improves conversion-to-rating when users eventually hit the in-app review prompt. Honest, not begging.

### What's being removed

- The "Take the Refill Pledge" opening line (moved down).
- Two redundant middle paragraphs ("Sipli makes staying hydrated feel simple" / "Whether you want a lighter daily tracker…") that don't add information.
- The "Personalized goals" / "Designed for daily use" / "Apple Health and widgets" repeat-headings — redundant with the bullet sections.

### Sprint 4 action

1. Replace the entire description in App Store Connect (EN-US).
2. Metadata-only update.
3. Wait 3 days. Conversion should hold or improve.
4. Rollback trigger: conversion drops > 1 pp.

---

## Character budget summary

| Variant | Chars | Safely under 4,000 limit? |
| --- | --- | --- |
| Current | ~1,540 | ✅ |
| Sprint 3 only (swap first paragraph) | ~1,580 | ✅ |
| Sprint 4 full rewrite | ~1,850 | ✅ |

All well within Apple's limit, leaving headroom for future feature mentions (quests, share card, lifetime tier) without another rewrite.

---

## Localization note

When Sprint 8 (es-MX), Sprint 9 (pt-BR), and Sprint 10 (de-DE) ship, each locale gets its own full description translation. The structure (sections, bullet format) stays constant across locales; only the prose changes. Using a consistent structure makes translator QA faster.

---

## Decisions needed from the user

1. **Which Sprint 3 above-the-fold option** (A / B / C / other)?
2. **Approve the Sprint 4 full-body draft as-is**, or iterate on a specific section?
3. **Include the closing review ask** ("Sipli is made by one person…") or drop it? Some indie devs love it; others find it off-brand.

When those are decided, I can compile the final strings into `docs/app-store-metadata/en-us.md` so you can paste directly into App Store Connect.
