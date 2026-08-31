# App Store Metadata — Sipli 5.0 (en-US)

**Status:** Source of truth for the next listing update. Paste these strings into App Store Connect, or publish via `scripts/asc_publish.py` (which reads What's New from `docs/release-notes-5.0.md` and the long description from `docs/appstore-description.txt`). Do not treat this file as already live — the store description still said "NEW IN 4.1: THE FOOTBALL SUMMER UPDATE" after 5.0 shipped.

**Positioning anchor:** "Sipli is the hydration app that thinks for you — adapting your daily goal to your body, your workouts, today's weather, and the hour — now with a Trophy Room, weekly quests, and share cards. Private by default: on-device and iCloud, no Sipli servers."

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

### Promotional Text — 119 / 170 chars

> Editable anytime without Apple review.

```
Trophy Room is here — 31 badges, weekly quests, and share cards. Still private: on-device and iCloud, no Sipli servers.
```

### Keywords (100-char field, comma-separated, no spaces) — 97 / 100 chars

> Apple treats Title, Subtitle, and Keywords as a union for search indexing. This field intentionally contains no terms that already appear in the title or subtitle — repeats waste slots.

```
hydration,h2o,bottle,intake,log,hydrate,thirst,weather,watch,widget,health,habit,streak,coach,goal
```

### Description

> Source file for publish: `docs/appstore-description.txt`. First ~170 chars (above-the-fold) stay the habit-stick intro.

```
Build a hydration habit that actually sticks — adaptive goals, Apple Watch quick-logging, and reminders that think with you, not at you.


WHAT MAKES SIPLI DIFFERENT

• Adaptive daily goals that flex with your body weight, today's weather, and your workouts — not a fixed number you'll ignore by Tuesday
• Smart reminders that pause when you're ahead and nudge when you drift — no 2 a.m. buzzes, no pestering
• Log anywhere — one tap on Apple Watch, a word to Siri, quick-add buttons on widgets, or straight from Control Center
• 35+ beverages with science-backed hydration factors, so coffee (≈80%) doesn't count the same as water (100%)
• Private by default — no account to create, no Sipli servers for your data to live on


NEW IN 5.0: TROPHY ROOM

• Earn 31 badges across Consistency, Volume, Explorer, Dedication and Season — plus a few secret ones to discover
• Celebrations when you unlock a badge or hit your daily goal
• Share cards for daily, weekly and badge recaps, posted from the share button
• Weekly quests — three fresh challenges every week between streaks
• Your droplet grows with your streak — aura, sparkles and a crown as you keep going
• Ask Siri more: "What's my streak", "How much more water do I need", "Log my usual" and "Show my achievements"
• Streaks now count past 90 days, so the 100-day Century Stream badge is within reach


TRACK EVERYTHING YOU DRINK

• 35+ beverages — water, sparkling, teas, specialty coffees, matcha, kombucha, plant milks, juices, sports drinks, and more
• Hydration factors that actually account for caffeine and alcohol — cold brew doesn't count like water, and a glass of wine doesn't get a free pass
• One-tap quick-add cups, learned presets of your usual drinks, or fine-tune with a slider
• Edit, backfill, and delete past entries any time


STAY ON TRACK

• Streaks, streak freezes, and a monthly heatmap that show where you drift
• Widgets for Home Screen and Lock Screen — plus quick-add buttons that skip opening the app
• Apple Health integration: water writes to Health, workouts read back for smarter goals
• Insights that are actually useful — 7- and 30-day trends, goal-met rate, average intake, and a weekly digest written on-device
• Seasonal Match Day challenges when they're on — your day as a match


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


SUBSCRIPTION DETAILS

Sipli Premium is an auto-renewable subscription (monthly or annual). Payment is charged to your Apple Account at confirmation of purchase, and the subscription renews automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel your subscription anytime in your Apple Account settings.

Terms of Use: https://its-me-anoop.github.io/Sipli/terms
Privacy Policy: https://its-me-anoop.github.io/Sipli/privacy
```

### What's New (v5.0 release notes)

> Source file for publish: `docs/release-notes-5.0.md`. First ~200 chars are visible without tapping "more".

```
• Trophy Room: earn 31 badges across Consistency, Volume, Explorer, Dedication and Season — plus a few secret ones to discover.
• Celebrations: unlocking a badge or hitting your goal now bursts into a shower of droplets.
• Share cards: post beautiful daily, weekly and badge cards straight to Messages or social from the share button.
• Weekly quests: three fresh challenges every week keep things interesting between streaks.
• Your droplet grows with you — keep your streak alive to earn its aura, sparkles and crown.
• Ask Siri more: "What's my streak", "How much more water do I need", "Log my usual" and "Show my achievements" in Sipli.
• Streaks now count past 90 days, so the 100-day Century Stream badge is within reach.
• Gentler diary: quiet days get a kind word, not a guilt trip.
• Subtle animation polish throughout — every effect respects Reduce Motion.
```

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
| 31 badges | `AchievementCatalog.all` | ✅ |
| "No Sipli servers" / "device + iCloud" | `WaterQuest/Services/PersistenceService.swift` (`NSUbiquitousKeyValueStore`) | ✅ |
| Apple Watch app features | `SipliWatch/` target | ✅ |
| Widgets for Home Screen + Lock Screen | `SipliWidget/` target | ✅ |
| Apple Intelligence tips | `FoundationModels` integration on supported devices | ✅ |
| Monthly/annual subscription, 1-month free trial (annual) | `Products.storekit` | ✅ |

---

## Localization

When additional locales ship, mirror this file's structure:

- `docs/app-store-metadata/es-mx.md` — Spanish (Mexico)
- `docs/app-store-metadata/pt-br.md` — Portuguese (Brazil)
- `docs/app-store-metadata/de-de.md` — German
