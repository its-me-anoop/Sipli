# ASO Metrics — Weekly Ship Log

**Purpose:** append-only log of every App Store Connect metadata ship and its measured impact. Each entry captures what changed, when, and what the numbers did in the following 3–14 days. This is the institutional memory that lets us evaluate sprints accurately.

**Related docs:**
- Strategy plan: `~/.claude/plans/giggly-petting-mist.md`
- Incremental rollout plan: `docs/plans/2026-04-15-aso-incremental-rollout.md`
- Sprint 0 baseline: `docs/aso-baseline-2026-04-15.md`

---

## Baseline (2026-04-15)

Window: through 2026-04-13 (App Store Connect snapshot).

| Metric | Value |
| --- | --- |
| Impressions | 895 |
| Product page views | 496 |
| First-time downloads | 47 |
| Conversion (page view → install) | 9.17% |
| Impressions → page view | 55.4% |
| In-app purchases | 12 |
| Day 1 → Paid | 3.45% |
| Day 7 → Paid | 8% |
| Day 35 → Paid | 13% |
| Proceeds | $26 |
| Star rating | 0 (no ratings) |

---

## Ships

### Entry template (copy to add an entry)

```
### Sprint N — <name> — YYYY-MM-DD HH:MM <tz>

**What changed:**
- Field: <before> → <after>

**Shipped via:** metadata-only update / binary update (v3.x build y)

**Review approval:** <timestamp>

**Measurement window:** <start> → <end> (N days)

**Results:**
| Metric | Before | After | Δ |
| --- | --- | --- | --- |
| Impressions / day avg | | | |
| Conversion | | | |
| Key rank: `<keyword>` | | | |

**Verdict:** keep / revert / iterate

**Notes:**
```

---

<!-- Insert ship entries below this line, newest first. -->

### v3.0 Launch — Full listing package drafted — 2026-04-16

**What changed (drafted, not yet submitted):**
- Title: `Sipli` → `Sipli — Water Tracker`
- Subtitle: `Hydration that fits your day` → `Drink Water Reminder + Goals`
- Promotional Text: *(new)* → `Now on Apple Watch — log a sip in one tap…`
- Keywords: `refill,pledge,earth day,reusable bottle,plastic free,hydrate,water reminder,earth week,habit,drink` → `hydration,h2o,bottle,intake,log,hydrate,thirst,weather,watch,widget,health,habit,streak,coach,goal`
- Description: full rewrite — adaptive-intelligence positioning, Watch app section added, Earth Week demoted from hero
- What's New: v3.0 release notes drafted

**Shipped via:** pending — consolidated into v3.0 binary submission (not metadata-only). Paste source: `docs/app-store-metadata/en-us.md`.

**Source plan:** `~/.claude/plans/whimsical-tickling-parnas.md` (competitor-informed v3.0 rewrite)

**Review approval:** n/a yet

**Measurement window:** v3.0 go-live → +7 days

**Results:**
| Metric | Before | After | Δ |
| --- | --- | --- | --- |
| Impressions / day avg | 895 over snapshot / baseline | | |
| Page-view → install conversion | 9.17% | | |
| Key rank: `water tracker` | unknown | | |
| Key rank: `drink water reminder` | unknown | | |
| Key rank: `hydration` | unknown | | |

**Verdict:** pending

**Notes:**
- Supersedes the standalone Sprint 3+4 description rewrite (`docs/plans/2026-04-15-sprint-3-description-rewrite.md`) by consolidating title/subtitle/keywords/description/what's new into a single v3.0 package.
- Rollback trigger (copy-only): conversion drops > 1 pp sustained over 72h → revert to baseline strings in `docs/aso-baseline-2026-04-15.md` via a metadata-only update.
