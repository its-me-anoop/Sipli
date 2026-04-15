# ASO Baseline — 2026-04-15

**Purpose:** freeze current state of the App Store listing and performance metrics so every subsequent sprint can be measured against it.

**Public listing snapshot taken:** 2026-04-15 (via App Store US storefront)
**Metrics snapshot:** App Store Connect reporting through 2026-04-13 (user-provided screenshot)

---

## Current metadata (public)

| Field | Value | Length | Analysis |
| --- | --- | --- | --- |
| Title | `Sipli` | 5 chars | **25 chars unused** — major keyword opportunity missed |
| Subtitle | `Hydration that fits your day` | 28 chars | Uses space, but only `hydration` is a keyword. `water tracker`, `reminder`, `drink` all missed. |
| Developer | `Anoop Jose` | — | — |
| Category | Health & Fitness | — | Correct |
| Age rating | 13+ | — | Correct |
| Price | Free w/ IAP | — | — |
| IAP | Annual $19.99, Monthly $2.99 | — | Annual includes 1-month free trial per `Products.storekit`. No lifetime tier. |
| Star rating | 0 stars / 0 ratings | — | **Critical** — no social proof anywhere in the funnel |

## Current description (verbatim, full text)

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

### Description — above-the-fold assessment

The first 3 lines (what users see before "…more"):

> "Take the Refill Pledge: refill, not rebuy. Every refill is one less plastic bottle — and a habit that quietly sticks. Sipli makes staying hydrated feel simple."

**Issues:**
- Leads with a **seasonal** campaign (Earth Week) that's only meaningful Apr 20–26. For ~50 weeks of the year, this is the wrong opening.
- No mention of the app's core job-to-be-done.
- No mention of **Apple Watch** (the product's newest and most differentiated feature, shipped 2026-04-12).
- No keyword density — not a single high-volume search term in the hero copy.

## Current "What's New" (version 2.3)

> For Earth Week: The Refill Pledge. A small promise for Apr 20–26 — refill, not rebuy. We added a personalized pledge card you can share, a new "Why Reusable Bottles" screen, and Earth Day visuals on your dashboard. Refill, not rebuy. One habit at a time.

**Note:** as of 2026-04-15 the public store is still showing **v2.3** release notes. User confirmed the v3.0 Watch-app build is **not yet submitted** — still building locally. This is actually useful for sequencing: we can ship Sprint 1 as a metadata-only update on the live v2.3 listing *today*, and ship v3.0 when it's ready without bundling the two.

## Current keyword field

Captured from App Store Connect on 2026-04-15 (user-provided):

```
refill,pledge,earth day,reusable bottle,plastic free,hydrate,water reminder,earth week,habit,drink
```

**Length:** 98 / 100 chars.

### Token-by-token analysis

| Token | Chars | Category | Value |
| --- | --- | --- | --- |
| `refill` | 6 | Seasonal / Earth Week | Low — niche term |
| `pledge` | 6 | Seasonal / Earth Week | Very low — brand voice, not search voice |
| `earth day` | 9 (phrase) | Seasonal | High for 1 week/year, zero for 51 |
| `reusable bottle` | 15 (phrase) | Seasonal | Medium for 1 week, low rest of year |
| `plastic free` | 12 (phrase) | Seasonal | Medium for 1 week, low rest of year |
| `hydrate` | 7 | Evergreen | Medium — direct intent |
| `water reminder` | 14 (phrase) | Evergreen | **High** — direct search term |
| `earth week` | 10 (phrase) | Seasonal | Same as earth day |
| `habit` | 5 | Evergreen | Medium — broader |
| `drink` | 5 | Evergreen | Medium — broad |

**Total spend on seasonal terms:** ~58 of 98 chars (59%) — effectively 59% of the keyword budget is vacant except for one week in April.

**Duplicate-with-subtitle risk:** `hydrate` overlaps with subtitle `Hydration` (shared stem). Not a fatal duplicate, but inefficient.

**Missing high-volume evergreen tokens:** `h2o`, `bottle`, `intake`, `thirst`, `goal`, `watch`, `widget`, `health`, `streak`, `log`.

## Current screenshots

**Not audited yet.** The WebFetch did not return image URLs for the individual screenshots. Two options for auditing:
1. Take a screen capture of the public App Store listing page on iPhone or Mac (App Store app → search "Sipli" → scroll to screenshots).
2. Export current screenshots from App Store Connect → App Store tab → Media Manager → download each size.

**Action required from user:** share the current screenshot set, OR confirm we can work from the public App Store listing images alone.

---

## Performance baseline (App Store Connect, through 2026-04-13)

| Metric | Value |
| --- | --- |
| Impressions | 895 |
| Product page views | 496 |
| First-time downloads | 47 |
| Redownloads | 13 |
| Conversion rate (page view → install) | 9.17% |
| Updates | 45 |
| Proceeds | $26 |
| Paying users (daily average) | — (none reported) |
| In-app purchases | 12 |
| Day 1 download → paid | 3.45% |
| Day 7 download → paid | 8% |
| Day 35 download → paid | 13% |

Period covered in the snapshot: window ending 2026-04-13.

---

## Top baseline findings (what's broken)

Ranked by leverage — fix the earliest ones first.

1. **Title wastes 25 characters.** Currently just `Sipli`. Allowed: 30 chars. Adding ` — Water Tracker` (16 chars, total 22) hits the single highest-volume keyword in the category without obscuring the brand.
2. **Subtitle has no high-volume keywords.** `Hydration that fits your day` is brand voice without keyword discipline. Missing: `drink`, `water`, `tracker`, `reminder` (all high volume).
3. **Zero ratings = zero social proof.** 47 installs and 0 ratings. Confirmed via grep: the codebase has **no** call to `SKStoreReviewController.requestReview` or the SwiftUI `.reviewRequest` environment modifier. Users are literally never asked. This is a ~30-line fix that compounds everywhere (listing CTR, paywall conversion, retention).
4. **Above-the-fold description is seasonal.** Earth Week pledge is beautiful but it's only relevant 1 week a year. The evergreen value pitch should lead, with the pledge as a secondary paragraph.
5. **Watch app is invisible in the copy.** Shipped 2026-04-12, nowhere to be seen on the public listing. Biggest freshness lever.
6. **No release notes for v3.0 visible.** Either the build isn't submitted yet, isn't approved, or we need to force a re-push. Confirm status.

---

## Sprint 0 completion checklist

- [x] Public listing captured verbatim
- [x] Current metrics documented
- [x] Top findings identified
- [x] v3.0 status confirmed (not yet submitted — Sprint 1 can ship independently)
- [x] Keyword field captured from App Store Connect
- [ ] Current screenshots captured (will pull from public App Store visual, not blocking Sprint 1)

**Sprint 1 (title + subtitle rewrite) is unblocked and ready to ship as a metadata-only update.**
**Sprint 2 (keyword field rewrite) is unblocked — proposed replacement documented in `2026-04-15-aso-incremental-rollout.md`.**

---

## Open questions for the user

1. **Keyword field:** what's the current 100-char keyword field in App Store Connect? (Copy it verbatim — don't paraphrase.)
2. **v3.0 submission status:** is the Watch-app build in review, approved-pending-release, or not yet submitted? The public listing still shows v2.3.
3. **Screenshots:** want me to pull the current screenshots from the public store URL, or would you prefer to share the export set from ASC?
4. **Review prompt:** confirmed absent (grep returned zero matches). Recommendation: add `.reviewRequest` (SwiftUI) triggered after the user hits their daily goal for the 3rd time, OR after 7 days of consistent logging — moments when users feel positive and are likely to leave a good rating.
