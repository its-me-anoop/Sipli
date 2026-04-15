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
