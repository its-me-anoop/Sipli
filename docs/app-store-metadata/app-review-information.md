# App Review Information — Sipli 3.0

**Purpose:** reviewer-facing copy for App Store Connect → App Information → App Review Information (and the version-specific review info panel on v3.0). Not user-facing.

**Why it matters:** every non-obvious permission prompt, unusual flow, or capability the reviewer can't immediately explain is a rejection risk. A short, specific Notes section pays for itself within one review cycle.

**Ship target:** paste into App Store Connect before submitting the v3.0 binary for review.

---

## Paste-ready fields

### Sign-In Required

**Toggle: OFF.** Sipli has no account system. After a 7-step onboarding flow (name, weight, activity level, schedule, permissions), the full app is usable immediately. There is no login screen, no backend, and no reviewer account to provide.

### Demo Account

Not applicable. Leave both username and password blank.

### Contact Information

Fill these four fields in App Store Connect — they are not in this doc because they are personal:

| Field | Value |
| --- | --- |
| First name | *(your first name)* |
| Last name | *(your last name)* |
| Phone number | *(a number Apple can reach you on during review)* |
| Email | *(an inbox you check daily during the review window)* |

If Apple has a follow-up question and can't reach you quickly, review can stall 48+ hours. Recommend a personal mobile number over a landline.

### Notes — 2,600 / 4,000 chars (paste verbatim)

```
Sipli is a hydration tracker with an Apple Watch companion app, Home Screen and Lock Screen widgets, and dynamic daily goals. There is no account — the app works fully after onboarding.

WHAT'S NEW IN 3.0
• New Apple Watch app: quick-logging from the wrist, complication, three Watch widget sizes, goal-met trophy
• Two-way sync between iPhone, Watch, and Apple Health
• Rebuilt reminder engine (pauses when ahead, nudges when behind)

PERMISSIONS — all optional, all triggered by user action

• Notifications: prompted during onboarding if the user enables reminders. Used for water-reminder push notifications only. Respects wake/sleep hours; never fires after the user has hit their daily goal.

• HealthKit: opt-in from onboarding or Settings → Permissions. Reads workouts and active energy (to raise the daily goal on active days). Writes water intake to the Dietary Water category. Permission is declined gracefully — the app works without it.

• Location (When In Use): opt-in from Settings → Daily Goal → Weather adjustment. Used exclusively by WeatherKit to fetch local temperature/humidity for adaptive goals. Never stored, never transmitted off-device.

• Apple Intelligence (FoundationModels): generates hydration tips and reminder copy on supported iPhones. Falls back to curated static messages on unsupported devices. All inference is on-device or via Apple's Private Cloud Compute — no third-party endpoints.

IN-APP PURCHASES
Sipli Premium ($2.99/month or $19.99/year with a 1-month free trial) unlocks all beverage types, AI tips, HealthKit sync, Weather-adjusted goals, Workout-adjusted goals, and Smart reminders. The free tier is fully functional for basic water tracking.

FLOWS TO TEST
1. Onboarding: 7 steps. Name → weight → activity → goal → schedule → reminders → done.
2. Log water: tap the + button on the dashboard, pick a beverage, adjust the slider, confirm.
3. Adaptive goals: enable Weather and HealthKit in Settings to see the base goal adjust.
4. Widgets: small/medium/large on Home Screen; circular/rectangular/inline on Lock Screen.
5. Watch app: pair a Watch with the test device and log a sip from either side — both sync.
6. Review prompt: Apple's .requestReview fires after the 3rd lifetime goal completion. Users can also tap Settings → About → Rate Sipli to open the App Store review sheet directly.

PRIVACY
No account. No Sipli servers. No third-party analytics SDKs. Data lives on-device and in the user's iCloud (via NSUbiquitousKeyValueStore), not ours. No ad tracking.

NON-OBVIOUS DETAILS
• Coffee, tea, and other caffeinated drinks count with scientifically-grounded hydration factors (e.g. coffee ≈ 80%, cold brew ≈ 75%, water = 100%). Citations are visible in-app at Settings → Daily Goal → Goal methodology sources (National Academies, CDC, ACSM). The app explicitly states it does not provide medical advice.
• An alternate "Earth Day" app icon toggle appears in Settings → Appearance only during Earth Week (April 20–26). Outside that window the toggle is intentionally hidden.
• The deep link scheme sipli:// opens the in-app Earth Week pledge card. Purely local; no external submission.

Thanks for the review — happy to answer anything on the contact email above.
```

### Attachment recommendation

Optional but strongly recommended for the v3.0 review:

- **A 30–60 second screen recording** of the core flow: onboarding → log a sip → dashboard with progress ring → toggle a premium feature → (if a physical Watch is in the test bench) log from Watch. Export as H.264 MP4, ≤ 50 MB.
- Helps the reviewer short-circuit questions about Watch pairing, HealthKit prompts, and the subscription paywall.

---

## What each Notes section is pre-empting (for maintainer reference, not for the reviewer)

| Section | Rejection risk it addresses |
| --- | --- |
| "No account" intro | Reviewer spending time looking for a sign-in screen |
| Permissions walkthrough | 5.1.1 rejection (purpose strings / unexpected prompts) |
| HealthKit read + write explanation | 2.5.1 / health-data guideline rejection |
| Apple Intelligence footprint | Questions about third-party AI use / data transmission |
| IAP block | 3.1.1 rejection for unclear subscription disclosure |
| Flows to test | Reviewer using only a single path and missing features |
| "Privacy" paragraph | 5.1.1(v) / data-collection accuracy questions |
| "Coffee counts" citation pointer | 1.4 health-claim rejection — directs to in-app citations |
| Earth Day icon seasonal toggle | "Why doesn't this toggle appear?" follow-up |
| Deep link explanation | 2.3 metadata rejection for undocumented URL scheme |

---

## Maintenance

- Update the "What's New in 3.0" bullets each major version.
- Update the IAP prices if they change (App Store Connect products vs. this file are the source — this file reflects them).
- If a new permission or capability is added in a future release (e.g., CloudKit, Siri Shortcuts, Background Modes), add a bullet before submission or Apple's reviewer will flag it.
- Keep the Notes under 4,000 chars — current draft is ~2,600, leaving ~1,400 chars of headroom.
