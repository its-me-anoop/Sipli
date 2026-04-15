# Incremental ASO Rollout — One Small Ship at a Time

**Date:** 2026-04-15
**Parent plan:** [2026-04-15-p0-aso-overhaul.md](./2026-04-15-p0-aso-overhaul.md)
**Principle:** *No drastic change, ever.* Each sprint ships one isolated thing, waits long enough to measure it, then decides: keep, roll back, or iterate.

## Why incremental

The original P0 plan bundled the metadata rewrite, screenshot redesign, and localization into one sprint. That's efficient but high-risk: if conversion *drops* after the update, we can't tell which change caused it. Shipping one variable at a time makes every change attributable, reversible, and psychologically safer — both for us and for any returning users who glance at the listing.

## Ship cadence rules

1. **One variable per sprint.** Subtitle or keyword field, not both.
2. **Wait ≥ 72 hours** between ships so App Store indexing and analytics stabilize.
3. **Measure before moving on.** Each sprint has a defined success metric and a "rollback if" condition.
4. **Metadata-only updates** for copy changes — no binary submission, Apple review is typically < 24h.
5. **Use App Store Connect PPO** (Product Page Optimization) to A/B test screenshots. Up to 3 variants, 50/50 traffic split.
6. **Document every ship.** Append to `docs/aso-metrics-weekly.md` with before/after numbers so we build institutional memory.

---

## Sprint map (ASO copy + screenshots)

| # | Sprint | What ships | Wait | Primary metric | Rollback trigger |
| --- | --- | --- | --- | --- | --- |
| 0 | **Baseline audit** | Nothing — snapshot current state | — | — | — |
| 1 | **Title + Subtitle rewrite** | Title (uses the 25 unused chars) and new subtitle | 3 days | Impressions + `water tracker` rank | Impressions drop > 15% |
| 1.5 | **In-app review prompt** *(code change)* | `.reviewRequest` triggered on 3rd goal completion | 14 days | Rating count + star average | — (only upside) |
| 2 | **Keyword field rewrite** | 100-char keyword field only | 3 days | Impressions + keyword rank on 5 targets | Impressions drop > 15% |
| 3 | **Description — first 3 lines** | Above-the-fold copy only | 3 days | Page-view → install conversion | Conversion drops > 1 pp |
| 4 | **Description — full body** | Rest of description | 3 days | Conversion (should hold) | Conversion drops > 1 pp |
| 5 | **Hero screenshot (#1) via PPO A/B** | New screenshot 1, 50/50 test vs old | 7 days (PPO needs enough traffic) | Conversion of variant vs baseline | Variant loses by > 1 pp |
| 6 | **Screenshot #2 (Watch) via PPO** | New screenshot 2 | 7 days | Conversion of variant | Variant loses |
| 7 | **Screenshots #3–#7 rolled one at a time** | Each remaining screenshot | 5 days each | Conversion | Variant loses |
| 8 | **Locale #1 — es-MX** | Spanish (Mexico) metadata + screenshots | 7 days | Local impressions + conversion | Impressions stay near 0 (i.e. keyword choice wrong) |
| 9 | **Locale #2 — pt-BR** | Portuguese (Brazil) | 7 days | Same as #8 | Same |
| 10 | **Locale #3 — de-DE** | German | 7 days | Same | Same |

**Revised Sprint 1 scope:** originally "subtitle only." Upgraded to "title + subtitle" after baseline audit revealed the title is using only 5 of its 30 allowed characters — leaving 25 chars of keyword space unused. Title + subtitle are both indexed high-weight fields and it's wasteful to ship them separately when the title change has the bigger upside. Both still ship as one metadata-only update.

**Sprint 1.5 rationale:** the codebase has no in-app review prompt. Adding it is the single cheapest lever for generating social proof (which currently stands at 0 ratings). This runs *in parallel* with Sprints 2–4 — it's a code change that ships in the next app version, not a metadata change.

**Total timeline:** ~8–10 weeks end to end. Compare to the original "Week 1–4" aggressive plan — this is slower but *every sprint teaches us something*, and no single change can tank the listing.

---

## Sprint detail

### Sprint 0 — Baseline audit (TODAY)

**Purpose:** freeze a snapshot of current state so we can measure every later change against it.

**Actions:**
1. Pull the public App Store listing via WebFetch (title, subtitle, first lines of description).
2. Ask user to share the current keyword field from App Store Connect → App Information → Keywords (this is not public).
3. Record current App Store Connect metrics (already captured in original screenshot: 895 impressions, 9.17% conversion, $26 proceeds, 47 installs through 2026-04-13).
4. Save the raw state in `docs/aso-baseline-2026-04-15.md`.

**Deliverable:** `docs/aso-baseline-2026-04-15.md` with before-state captured.

**Success:** file committed with all four inputs.

---

### Sprint 1 — Title + Subtitle rewrite

**Proposed changes:**

| Field | Before (confirmed in Sprint 0) | After (proposed) | Chars used / allowed |
| --- | --- | --- | --- |
| Title | `Sipli` | `Sipli — Water Tracker` | 22 / 30 |
| Subtitle | `Hydration that fits your day` | `Drink Water Reminder + Goals` | 28 / 30 |

**Why this first:** title + subtitle are the two highest-weight indexed fields. The title audit in Sprint 0 revealed we're using only 5 of 30 characters — 25 chars of keyword real estate sitting idle. Adding ` — Water Tracker` to the title plants the single highest-volume category keyword without burying the brand (brand stays first, readers still see "Sipli" in search results and on home-screen). The new subtitle swaps vague brand voice (`Hydration that fits your day`) for three high-volume search phrases — `drink water`, `water reminder`, `goals` — in one 28-char line.

**Why title + subtitle together and not separate sprints:** normally we'd ship one variable at a time, but the title change is too big to leave on the table for another week, and both ship in the same metadata-only update anyway (one submission, one review). Keeping them in one sprint keeps the cadence small without wasting a submission cycle.

**Actions:**
1. In App Store Connect → App Information → Localizable Information (EN-US), edit both "Name" and "Subtitle". Submit metadata-only update (no binary).
2. Log ship datetime in `docs/aso-metrics-weekly.md`.
3. Wait 3 days.
4. Pull metrics: impressions, keyword ranks for `water tracker`, `drink water reminder`, `hydration`.

**Rollback:** if impressions drop > 15% sustained over 72h, revert.

**Pre-ship confirmation note:** the brand display in the home screen changes from `Sipli` to `Sipli — Water Tracker`. Apple usually truncates long names on the home screen, so the visible label will still be `Sipli`. Worth a sanity-check on a test device before submitting.

---

### Sprint 1.5 — In-app review prompt (runs in parallel with Sprints 2–4)

**Discovery from baseline audit:** the codebase has zero calls to `SKStoreReviewController.requestReview` or the SwiftUI `.reviewRequest` environment modifier. 47 users have installed the app and none have been asked to rate. That's our 0-star situation, and it's fixable in about 30 lines.

**Proposed change:** prompt for a review at a high-satisfaction moment — when the user completes their daily goal for the **3rd time** — using SwiftUI's `.reviewRequest` environment modifier (iOS 16+). Apple's system handles the throttling (max 3 prompts per user per year), so we don't need rate-limiting logic.

**Why this moment:** hitting a goal releases a small dopamine hit. Tap-through-to-rate rates are 3–5× higher in positive moments than in negative ones. Alternatives considered: on 7-day streak (too late — most users drop off before 7 days), after opening the share card (too infrequent), after first goal (too early — user hasn't experienced enough value). The 3rd goal completion balances "user has seen the product work" against "not yet in the churn zone."

**Files to touch:**
- `WaterQuest/Views/DashboardView.swift` — add `@Environment(\.requestReview)` and call it from the goal-completion handler
- `WaterQuest/Models/UserProfile.swift` — persist `goalCompletionCount: Int` so we know when to fire
- `WaterQuest/Services/HydrationStore.swift` — increment the counter when `progress ≥ 1.0` first passes the threshold on a given day

**Actions:**
1. Implement in one small commit.
2. Ship in the next binary update (either the pending v3.0 or a v3.0.1 patch).
3. Wait 14 days (review prompts are infrequent by design).
4. Check ratings count + star average in App Store Connect.

**Rollback:** unlikely to be needed — review prompts have no negative outcome except for users who leave 1-star reviews. If that happens at > 30% rate, the product has a UX problem the prompt surfaced — which is a *good* signal, not a reason to remove the prompt.

---

---

### Sprint 2 — Keyword field rewrite

**Proposed change:** replace the 100-char keyword field with:
```
hydration,drink,h2o,bottle,intake,log,hydrate,thirst,reminder,goal,watch,widget,health,habit,streak
```
(98 chars, no duplicates with the new title/subtitle from Sprint 1)

**Why after title+subtitle:** Sprint 1 proved (or disproved) whether our top-volume keywords (`water tracker`, `drink water reminder`) lift impressions. Sprint 2 now tests the *long-tail* — whether we've picked the right 15 supporting keywords. Isolated from Sprint 1, the attribution is clean.

**Note:** because Sprint 1 now puts `water` and `tracker` in the title, and `drink`, `water`, `reminder`, `goals` in the subtitle, this keyword list already omits them (Apple's indexer treats the three fields as a union; repeating a word wastes slots).

**Actions:** same flow as Sprint 1 — ASC edit → metadata-only submit → wait 3 days → measure.

**Rollback:** if impressions drop > 15% or our top-3 target keywords fall > 10 positions, revert.

**Final keyword hypothesis to validate before shipping Sprint 2:** we need to know what the *current* keyword field is so we can diff against the proposed one. Without the baseline, we can't tell whether any given keyword was already in play. See Open Questions in `docs/aso-baseline-2026-04-15.md` — user needs to share the current keyword field from App Store Connect before this sprint is safe to ship.

---

### Sprint 3 — Description, above-the-fold only

**Proposed change:** rewrite just the first three lines of the description (what appears above the "…more" toggle on the App Store product page).

**Before:** (Sprint 0 will capture)
**After:**
```
Build a hydration habit that sticks — with adaptive goals,
Apple Watch quick-logging, and smart reminders that actually
read your day. Your hydration, without the pestering.
```

**Why limit to 3 lines:** this is the only description real estate that most users read. Changing this alone is the cleanest test of "does our value pitch convert better than the old one?" Rest of description is still there, just visible after the toggle.

**Actions:** same flow. Wait 3 days. Measure page-view → install conversion.

**Rollback:** if conversion drops > 1 percentage point vs. baseline.

---

### Sprint 4 — Description, full body

**Proposed change:** rewrite the rest of the description using the structure in `2026-04-15-p0-aso-overhaul.md` Step 2. No new above-the-fold changes (Sprint 3 owns that).

**Why after Sprint 3:** we've proven the value pitch works. Now we can confidently rewrite the rest without risking the proven hero copy.

**Actions:** same flow. Wait 3 days. Conversion should hold.

---

### Sprint 5 — Hero screenshot (#1) via PPO A/B

**Proposed change:** replace screenshot #1 with new hero: animated progress ring + mascot + streak prominent, caption "Hydration, on autopilot."

**Why PPO, not a straight replace:** screenshots drive conversion 2–3× more than copy. A bad hero shot is the highest-cost mistake we can make. PPO lets us ship the new one to 50% of traffic and the old one to 50%, so if the new one is worse, we've only hurt half our traffic and we have data to decide.

**Actions:**
1. In `appstore-screenshots/src/`, add a new page rendering the hero composition.
2. Export PNG at 1290×2796 (6.9") and 1284×2778 (6.5").
3. Create a PPO treatment in App Store Connect → Product Page Optimization. Variant A = new hero; Control = existing hero. 50/50 split.
4. Wait 7 days (PPO needs statistically meaningful traffic).
5. Read PPO results panel in ASC.

**Rollback:** if variant conversion is statistically worse (ASC marks this in the panel), end test, keep control, iterate on the design.

**Promote:** if variant wins, set it as the default and end the test.

---

### Sprint 6 — Screenshot #2 (Watch) via PPO

**Proposed change:** replace screenshot #2 with new Watch-app hero, caption "Now on Apple Watch."

**Why this one next:** Watch is our freshest and most differentiated feature. Waterllama doesn't lead with Watch; we can.

**Actions:** same flow as Sprint 5.

---

### Sprint 7 — Remaining screenshots (#3–#7), one at a time

For each of screenshots 3, 4, 5, 6, 7:
1. Build the new variant in `appstore-screenshots/`.
2. Ship via PPO vs. existing.
3. Wait 5 days (shorter than hero because these carry less conversion weight).
4. Promote or iterate.

Screenshot 4 (quests) and screenshot 5 (60+ beverages) depend on the underlying features shipping first — if they aren't ready, use placeholder captions that truthfully describe the *current* state.

---

### Sprints 8–10 — Localization, one locale at a time

For each of es-MX, pt-BR, de-DE:
1. Translate metadata (title, subtitle, keywords, description) using LLM draft + native speaker pass.
2. Regenerate screenshots with translated captions.
3. Ship to that locale only via ASC.
4. Wait 7 days.
5. Measure local impressions + conversion.

**Don't roll all three at once.** Start with es-MX because the Spanish market is largest. If it wins, pt-BR and de-DE become obvious. If it flops, we re-audit our keyword research before investing in the others.

---

## What this buys us

- **Attributability:** when a metric moves, we know which change moved it.
- **Safety:** any single bad ship costs us ≤ 3–7 days; total downside is small.
- **Compounding learning:** each sprint teaches us something that improves the next one. The keyword audit data from Sprint 2 informs the description voice in Sprint 3, informs screenshot captions in Sprint 5, informs locale-specific keywords in Sprint 8.
- **Calm operations:** a metadata-only update every few days reads as steady improvement, not a frantic rewrite.

## Broader principle (for Tracks beyond ASO)

The same "little by little" rule applies when Track B (in-app changes) starts:

- Feature-flag every new UI behind a toggle before wiring it to all users.
- Roll new in-app UI to *new* users first (onboarding cohort), not existing ones.
- When changing existing UI, add the new thing alongside the old one for a release cycle before deleting the old.
- Earn trust by making changes users don't notice — until they do, and smile.

That section gets its own plan doc when we start Track B. For now the focus is App Store listing.

---

## Next action

Start Sprint 0 — audit the current public listing and request the keyword field from the user (since it's only visible inside App Store Connect).
