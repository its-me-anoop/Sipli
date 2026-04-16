# App Store Metadata — Sipli 3.0 (en-US)

**Status:** Source of truth. Paste these strings verbatim into App Store Connect → App Information → Localizable Information (English (US)) for the v3.0 listing.

**Generated from:** `~/.claude/plans/whimsical-tickling-parnas.md` (competitor-informed v3.0 rewrite, approved 2026-04-16)

**Positioning anchor:** "Sipli is the hydration app that thinks for you — adapting your daily goal to your body, your workouts, today's weather, and the hour — now on Apple Watch."

**Ship mode:** part of the v3.0 binary submission (not metadata-only) — the Watch app is the freshness beat.

---

## Fields for App Store Connect

Character counts are against Apple's published limits. Copy from inside the fenced code blocks so leading/trailing whitespace and smart quotes are preserved.

### App Name (Title) — 22 / 30 chars

```
Sipli — Water Tracker
```

### Subtitle — 28 / 30 chars

```
Drink Water Reminder + Goals
```

### Promotional Text — 150 / 170 chars

> Editable anytime without Apple review. Use this field as the v3.0 launch megaphone and for future ad-hoc updates.

```
Now on Apple Watch — log a sip in one tap. Adaptive goals adjust for your weather, weight, and workouts. Smart reminders that actually read your day.
```

### Keywords (100-char field, comma-separated, no spaces) — 97 / 100 chars

> Apple treats Title, Subtitle, and Keywords as a union for search indexing. This field intentionally contains no terms that already appear in the title or subtitle — repeats waste slots.

```
hydration,h2o,bottle,intake,log,hydrate,thirst,weather,watch,widget,health,habit,streak,coach,goal
```

### Description — ~3,050 / 4,000 chars

> First 137 chars (above-the-fold) are the highest-converting real estate. Apple truncates near character 170 OR the third newline on iPhone product pages.

```
Build a hydration habit that actually sticks — adaptive goals, Apple Watch quick-logging, and reminders that think with you, not at you.


WHAT MAKES SIPLI DIFFERENT

• Adaptive daily goals that flex with your body weight, today's weather, and your workouts — not a fixed number you'll ignore by Tuesday
• Smart reminders that pause when you're ahead and nudge when you drift — no 2 a.m. buzzes, no pestering
• Now on Apple Watch — log a sip from your wrist in one tap, with a complication that keeps your ring in view all day
• 35+ beverages with science-backed hydration factors, so coffee (≈80%) doesn't count the same as water (100%)
• Private by default — no account to create, no Sipli servers for your data to live on


NEW IN 3.0: SIPLI ON APPLE WATCH

• One-tap logging from your wrist — water, coffee, tea, whatever you're drinking
• Live progress ring and streak on your watch face (circular complication)
• Watch widgets in small, medium, and large for your Smart Stack
• Full two-way sync with iPhone and Apple Health — log on either device, see it on both instantly
• Goal-met trophy on your wrist, exactly where you'll see it


TRACK EVERYTHING YOU DRINK

• 35+ beverages — water, sparkling, teas, specialty coffees, matcha, kombucha, plant milks, juices, sports drinks, and more
• Hydration factors that actually account for caffeine and alcohol — cold brew doesn't count like water, and a glass of wine doesn't get a free pass
• One-tap quick-add cups or fine-tune with a slider
• Edit, backfill, and delete past entries any time


STAY ON TRACK

• Streaks and a monthly heatmap that show where you drift
• Widgets for Home Screen and Lock Screen — plus quick-add buttons that skip opening the app
• Apple Health integration: water writes to Health, workouts read back for smarter goals
• Insights that are actually useful — 7- and 30-day trends, goal-met rate, average intake


SIPLI PREMIUM

A single subscription unlocks the features that make hydration genuinely effortless:

• All 35+ beverage types with hydration factors
• AI-generated hydration tips, written on-device with Apple Intelligence on supported iPhones
• Apple Health workout + active-energy sync for dynamic goals
• Weather-adjusted goals that rise on hot, humid days
• Workout-adjusted goals that rise after long sessions
• Smart, adaptive reminders that read your schedule and your progress

Monthly or annual subscription. The annual plan includes a one-month free trial.


PRIVATE BY DEFAULT

No account. No Sipli servers. Your hydration data lives on your device, and in your iCloud if you've turned that on. No ad tracking. No data sale. Writes to Apple Health only if you opt in.


THE REFILL PLEDGE

Every April, Sipli joins Earth Week with the Refill Pledge — a simple idea: refill, not rebuy. Track each refill and watch a quiet daily habit keep plastic bottles out of your hand.


Sipli is made by one person and improved week by week. If the app helps you build the habit, a short review is the single biggest thing you can do to support continued development — thank you.
```

### What's New (v3.0 release notes) — ~780 / 4,000 chars

> First ~200 chars are visible without tapping "more" in the App Store update flow — lead with the single biggest reason to update.

```
3.0 — Sipli on your wrist.

NEW: the Apple Watch app. Log a sip in one tap from your wrist, a complication on your watch face, widgets for your Smart Stack, and a goal-met trophy exactly where you'll see it.

Also in 3.0:
• Full two-way sync between Watch, iPhone, and Apple Health — log on either device, see it on both
• Three Watch widget sizes (small / medium / large)
• Rebuilt reminder engine — pauses when you're ahead, nudges when you drift
• Smoother progress-ring and dashboard animations
• Performance pass across insights and the monthly heatmap
• Goal-completion count backfilled for long-time users, so your lifetime streak is accurate

If Sipli is helping you build the habit, a short review is the single biggest thing you can do to support continued development — thank you.

— Anoop
```

---

## Competitor reference (informed this package)

Snapshot as of April 2026. Full analysis in the approved plan.

| App | Rating / Reviews | Subtitle | Core angle |
| --- | --- | --- | --- |
| Waterllama | 4.9★ / 151K | "My hydration reminder drink it" | Cute & gamified — 140+ characters |
| WaterMinder | 4.7★ / 33K | "Water Intake & Drink Reminder" | Clean & clinical — character fills by drink color |
| Plant Nanny | 4.7★ / 105K | "Drinking & Hydration Reminder" | Game-first — grow virtual plants |
| Hydro Coach | Category top | "Drink water reminder" | Weather-only adjustment |

**Sipli's defensible gap:** adaptive goals that compound body weight + weather + HealthKit workouts + Apple Intelligence — none of the four can match the full stack. The copy above leads every section with that positioning.

---

## Voice guardrails (applied throughout)

- Warm, never infantilizing.
- Specific numbers over adjectives (`35+ beverages`, `cold brew ≈ 75%`, `2 a.m. buzzes`).
- Em-dashes and contractions allowed.
- **Banned phrases:** *game-changer*, *unlock your wellness*, *hydration journey*, *revolutionary*, *seamless*, *elevate*, *take control*.
- `Apple Watch` always with a capital W. `iPhone` always lowercase-i capital-P.
- No emoji in App Store fields.
- No "#1 rated" / "best-in-class" claims.
- Watch and iPhone framed as peers, not iPhone-plus-accessory.

---

## Factual claims verified against the codebase

| Claim | Source | Status |
| --- | --- | --- |
| "35+ beverages" | `WaterQuest/Models/FluidType.swift` (36 cases incl. `other`) | ✅ |
| Coffee ≈ 80% hydration factor | `WaterQuest/Models/FluidType.swift` hydration factors | ✅ |
| Cold brew ≈ 75% hydration factor | Same | ✅ |
| "No Sipli servers" / "device + iCloud" | `WaterQuest/Services/PersistenceService.swift` (`NSUbiquitousKeyValueStore`) | ✅ |
| Apple Watch app features | `SipliWatch/` target | ✅ (verified via feature agent sweep) |
| Widgets for Home Screen + Lock Screen | `SipliWidget/` target | ✅ |
| Apple Intelligence tips | `FoundationModels` integration on supported devices | ✅ |
| Six premium features | `WaterQuest/Services/SubscriptionManager.swift` `PremiumFeature` enum | ✅ |
| Monthly/annual subscription, 1-month free trial (annual) | `Products.storekit` | ✅ |

---

## Localization

When Sprints 8–10 ship (`docs/plans/2026-04-15-aso-incremental-rollout.md`), mirror this file's structure for each locale:

- `docs/app-store-metadata/es-mx.md` — Spanish (Mexico)
- `docs/app-store-metadata/pt-br.md` — Portuguese (Brazil)
- `docs/app-store-metadata/de-de.md` — German

Section structure stays identical across locales so a native-speaker reviewer can diff translations against English quickly.
