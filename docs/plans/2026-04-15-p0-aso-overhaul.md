# P0 — ASO Overhaul Implementation Plan

**Date:** 2026-04-15
**Priority:** P0 (highest leverage, lowest code effort)
**Owner surface:** App Store Connect + screenshot assets. **No Swift code changes.**
**Parent strategy:** `~/.claude/plans/giggly-petting-mist.md`

## Problem

Sipli's App Store listing received **895 impressions** in the reporting period through 2026-04-13 — effectively invisible. Competitors rank on high-volume search terms ("water tracker", "drink water reminder", "hydration"); Sipli does not. The click-through-to-install path converts at 9.17%, which is serviceable — so discoverability is the binding constraint. Every other improvement compounds on this fix.

## Success Criteria

- **Impressions:** 895 → 2,500+ within 60 days of metadata update
- **Page-view → install conversion:** 9.17% → 13%+ within 30 days of new screenshots
- **Proceeds:** $26 / period → $75+ / period once impressions grow (no paid acquisition assumed)

---

## Step 1 — Keyword & Competitor Audit

**Goal:** build a ranked keyword list grounded in what's actually searched, not intuition.

### Actions

1. Sign up for a free tier of an ASO tool. Candidates (pick one):
   - [aso.dev](https://aso.dev/) — recommended, Apple-focused, free tier covers single-app keyword tracking
   - [ASOMobile free tools](https://asomobile.net/en/free-tools/) — Keyword Monitor + Keyword Suggest
   - [App Radar](https://appradar.com/) — 14-day trial
2. Enter `id6758851574` (Sipli) and pull the current keyword-rank report.
3. Look up **Waterllama** (`id1454778585`) and **WaterMinder** (`id653031147`) as benchmarks. Export the top 30 keywords each ranks for in the top 10.
4. Build a spreadsheet with columns: `keyword | estimated search volume | Waterllama rank | WaterMinder rank | Sipli rank | difficulty`.
5. Sort by **(volume × our-potential-to-rank)**. Top 10 becomes the target set.

### Expected target keywords (hypothesis, validate with tool)

Based on category norms:

| Keyword | Expected volume | Why Sipli can rank |
| --- | --- | --- |
| `water reminder` | High | Core intent match |
| `drink water reminder` | High | Exact match to use case |
| `water tracker` | High | Core intent match |
| `hydration tracker` | Medium-high | Competitor-friendly |
| `water intake` | Medium | Precise long-tail |
| `drink water` | Very high but competitive | Only tier-1 apps rank |
| `water log` | Low-medium | Under-served long-tail |
| `hydration reminder` | Medium | Smart reminder story fits |
| `apple watch water` | Low-medium | Our Watch app just shipped |
| `h2o tracker` | Low but easy | Non-alphabetical bonus |
| `bottle tracker` | Low | Fits our Earth Day angle |
| `hydration goal` | Low-medium | Unique positioning |

### Deliverable

A committed `docs/aso-keyword-audit-2026-04.md` table with the final target keywords, our current rank for each, and target ranks.

---

## Step 2 — App Store Metadata Rewrite

**Goal:** rewrite the title/subtitle/keyword field + description to hit the target keywords while keeping Sipli brand identity.

### Current state (hypothesis — verify in App Store Connect)

- **Title:** "Sipli" (8 chars of 30 available — under-utilised)
- **Subtitle:** likely a generic tagline
- **Keyword field (100 chars):** unknown

### Proposed rewrite

**Title (30 chars):** `Sipli — Water Tracker`
- Keeps the brand first (so the app still says "Sipli" when the storefront displays just the name portion).
- Adds the strongest category phrase after an em-dash — matches on "water tracker" and "water".
- Length: 22 chars, 8 spare for future.

**Subtitle (30 chars):** `Drink Water Reminder + Goals`
- Hits "drink water reminder" (highest-intent phrase), and "goals" which trails into goal-based search.
- Length: 28 chars.

**Keyword field (100 chars, comma-separated, no spaces):**
```
hydration,drink,h2o,bottle,intake,log,hydrate,thirst,reminder,goal,watch,widget,health,habit,streak
```
- 98 chars. Excludes words already in title/subtitle (don't waste the field on duplicates — Apple matches across all fields).
- Omits: `water`, `tracker`, `reminder`, `goals` (already in title/subtitle).
- Includes: one-letter/short high-value tokens (`h2o`), differentiators (`streak`, `habit`), device affinity (`watch`, `widget`).

### Description rewrite (above-the-fold = first 3 lines)

**Current problem:** descriptions usually lead with a feature list, which reads as "yet another water app."

**Proposed first 3 lines (visible in App Store preview before "more"):**

```
Build a hydration habit that sticks — with adaptive goals,
Apple Watch quick-logging, and smart reminders that actually
read your day. Your hydration, without the pestering.
```

Full description structure (below-the-fold):

```
WHY SIPLI
• Adaptive goals that flex with your workouts, the weather, and your weight
• Smart reminders that pause when you've hit your streak, push when you haven't
• Now on Apple Watch — log a sip in a single tap from your wrist

TRACK EVERYTHING YOU DRINK
• 60+ beverages with hydration factors [NOTE: update to actual count post-P5]
• Coffee, tea, matcha, kombucha, sports drinks, plant milks
• Apple Health integration — your water intake lives where the rest of your health does

STAY ON TRACK
• Quests and streaks that reward consistency
• Widgets for home screen and lock screen
• Live Activity / StandBy view for today's progress
• Earth-friendly: track reusable-bottle savings

PREMIUM (monthly or annual)
• Beverage tracking
• AI hydration insights
• HealthKit sync
• Weather-adjusted goals
• Workout-adjusted goals
• Smart reminders

100% private. No ad tracking. No data sale. Your hydration is yours.
```

### Apple rules to respect

- Title + subtitle + keyword field are indexed but **do not repeat terms across fields** — Apple treats them as a union, so repeated terms waste slots.
- Description is **not indexed** but drives conversion.
- `Apple Watch` uses a capital W — technically the trademark rule, matters for review.

### Deliverable

Final strings committed to `docs/app-store-metadata/en-us.md`. Apply in App Store Connect → App Information → "Localizable Information (English (US))" and "Version Information".

**Status (2026-04-16):** delivered as part of the consolidated v3.0 launch package. See `docs/app-store-metadata/en-us.md` for the paste-ready strings and `~/.claude/plans/whimsical-tickling-parnas.md` for the competitor-informed rationale that drove each field.

---

## Step 3 — Screenshot Redesign

**Goal:** screenshots drive conversion. The current assets almost certainly under-sell. Lead with the story, not the feature.

### Current assets

Existing folder: `appstore-screenshots/` (Next.js + React, with `src/`, `next.config.ts`, `package.json`). This is the programmatic generator — use it rather than hand-designing in Figma.

### Storyboard — 7 screenshots, iPhone 6.9"

Each screenshot = **big headline caption** + **device frame with a specific UI state** + **subtle gradient background**. Waterllama's pattern. 6.9" dimensions: 1290×2796.

| # | Headline | What's shown | Why it converts |
| --- | --- | --- | --- |
| 1 | **"Hydration, on autopilot."** | Dashboard with animated progress ring at ~75%, mascot smiling, streak "14 days" prominent | Hero — sets the brand, shows progress, anchors on the streak (gamification hook) |
| 2 | **"Now on Apple Watch."** | Split composition: iPhone dashboard + Watch face with complication showing hydration ring. Watch quick-add sheet in mid-animation | Watch app just shipped (v3.0) — lead with it, it's the freshest differentiator |
| 3 | **"Reminders that read your day."** | Lock screen mockup with Sipli notification: "You've been in a meeting for 2h — 250ml would help." | Smart reminders are the biggest premium feature. Show the intelligence, not the feature toggle |
| 4 | **"Quests, streaks, and wins."** | Dashboard with quest card "Drink 250ml before 9am — Complete!" + XP bar + badge | **Gated on P2 Phase A shipping**. Until then: replace with streak + heatmap screenshot |
| 5 | **"60+ beverages, not just water."** | Add Intake sheet showing fluid picker: matcha, kombucha, coffee, LMNT, plant milk, beer | **Gated on P5 shipping**. Until then: show current 30+ picker but lead caption with "All the drinks, tracked." |
| 6 | **"Widgets everywhere."** | Home screen with small+medium widgets. Lock screen with widget. StandBy mode | Device affinity — pitches to people searching "widget water" |
| 7 | **"Try Premium free for 1 month."** | Paywall view with monthly + annual (free trial) tiers | Price transparency = trust. Removes purchase friction. Will be re-shot when the lifetime tier lands in the final step (P1) |

### Copy rules

- Headlines: **≤ 5 words**, sentence case, ends with a period for tone (Apple's pattern).
- Caption font weight: bold. Contrast against mascot/lagoon palette.
- No emoji in headlines (tests poorly).
- No "#1 rated" type claims (App Store review can reject).

### Device sizes

Upload screenshots for:
- iPhone 6.9" (1290×2796) — current hero
- iPhone 6.5" (1284×2778) — Apple still requires
- iPad 13" — only if we want iPad surfacing (Sipli is iPhone-first; optional)
- Apple Watch — 410×502 — **new requirement for this release since we have a Watch app**

### Actions

1. Extend `appstore-screenshots/src/` to add 7 new pages corresponding to the storyboard above.
2. Each page should render at the target device resolution so we can export via Playwright or [html-to-image](https://www.npmjs.com/package/html-to-image).
3. Reference the existing `app-store-screenshots` skill (`~/.claude/.../app-store-screenshots`) for the scaffolding pattern.
4. Mock UI states in code — do not screenshot the running app (pixel-perfect control matters).
5. Export PNGs at exact App Store Connect dimensions. No compression artifacts.
6. Upload via App Store Connect → App Store tab → Media Manager.

### Deliverable

PNG files exported to `appstore-screenshots/exports/2026-04/` and uploaded to App Store Connect.

---

## Step 4 — Localization (Round 1)

**Goal:** roughly double the search surface by localizing to three high-volume locales.

### Target locales

1. **Spanish (Mexico) — `es-MX`** — largest Spanish-speaking storefront, hydration culture is strong
2. **Portuguese (Brazil) — `pt-BR`** — huge iOS base, low competitor coverage
3. **German — `de-DE`** — high ARPU, competitive but worth it

### Action per locale

For each locale, translate the same assets rewritten in Step 2:
- Title (max 30 chars)
- Subtitle (max 30 chars)
- Keyword field (100 chars — locale-specific, don't translate keywords verbatim; research local search terms)
- Description (full)
- Screenshots with translated captions (regenerate via `appstore-screenshots/`)

### Translation approach

Option A — **Human translators via Gengo / Rev** ($~0.07/word, ~300 words = ~$20/locale = $60 total)
Option B — **LLM draft, human polish** — draft with Claude, have a native speaker skim for idiom. Cheaper, lower quality ceiling.
Option C — **Pure LLM** — works for MVP but misses local search-term idiom (e.g. `tomar agua` vs `beber agua` in Spanish — measurable volume difference).

**Recommendation:** Option B. LLM draft for cost, native speaker pass to avoid idiom mistakes.

### Deliverable

`docs/app-store-metadata/es-mx.md`, `pt-br.md`, `de-de.md`. Upload to App Store Connect.

---

## Step 5 — In-App Events

**Goal:** App Store in-app-event cards are indexed separately and show up in user-targeted "What's New" surfaces. Apple privileges apps that use them.

### Current state

Earth Day pledge is already implemented (`WaterQuest/Views/EarthDayPledgeView.swift`). Likely already set up as an in-app event for April.

### Actions

1. **Formalize the recurring motion.** Calendar out 4 events per year:
   - Earth Week (April — already shipping)
   - Hydration Awareness Month (June — seasonal fit)
   - Back-to-School hydration (August/September)
   - New Year Reset (January)
2. For each event, produce:
   - In-app event card art (1920×1080 and 1080×1920)
   - Event name, short and long descriptions
   - Start/end dates set ≥ 14 days in the future so Apple approves
3. File them in App Store Connect → "In-App Events" section.

### Deliverable

Event calendar doc `docs/app-store-events-2026.md` + assets in `appstore-screenshots/events/`.

---

## Step 6 — Monitoring

**Goal:** close the loop. Nothing from Step 1-5 is evaluable without the baseline + tracking.

### Actions

1. **Baseline screenshot** — today's App Store Connect metrics (impressions, page views, conversion, etc.) saved to `docs/aso-baseline-2026-04-13.png`.
2. **Weekly check** — every Monday for 8 weeks, log:
   - Impressions
   - Page view → install conversion
   - Top 5 ranking keywords
   - Day 1 → Paid conversion
3. **A/B test** via App Store Connect Product Page Optimization (PPO) — Apple lets you test up to 3 variants of screenshots/icon/preview. After the first screenshot ship, run a PPO test with one alt caption variant to learn.

### Deliverable

Weekly metrics log at `docs/aso-metrics-weekly.md` (append-only).

---

## Execution Order & Timeline

| Week | Step | Output |
| --- | --- | --- |
| 1 | Step 1 (audit) + Step 2 (metadata rewrite) | Keywords spreadsheet committed; en-US metadata live in ASC |
| 2 | Step 3 (screenshots) | New screenshots live in ASC |
| 3 | Step 4 (localize es-MX, pt-BR, de-DE) | Three new locales live |
| 4 | Step 5 (in-app events formalization) + Step 6 (monitoring) | Event calendar + weekly log started |

---

## Risks & Mitigations

| Risk | Mitigation |
| --- | --- |
| Apple review rejects metadata (e.g. trademark term, misleading copy) | Submit as a **metadata-only update** first (no binary change) — review is faster (~24h) and a rejection doesn't pull the build |
| New screenshots convert *worse* than current | Use PPO A/B test, don't wholesale ship until data confirms lift |
| Keyword audit reveals we rank well already (unlikely) | Pivot to P4 paywall polish earlier |
| Localization introduces typos that hurt local conversion | Native speaker review pass before publish |

---

## Verification

Run this plan's success check weekly for 8 weeks. Done = **impressions ≥ 2,500** AND **conversion ≥ 12%**.

If both hit by week 4, reallocate remaining Track A capacity to Track B (quest system).
If neither hits by week 6, re-audit: likely the keyword hypothesis was wrong or the screenshots are not matching searcher intent. Revisit Step 1 with paid ASO tool.
