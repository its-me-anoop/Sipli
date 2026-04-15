# Sprint 5 — Hero Screenshot (#1) Design

**Date:** 2026-04-15
**Sprint:** 5 (runs in parallel with Sprints 1–4 for design; ships via PPO A/B after Sprints 1–4 land)
**Parent plan:** [2026-04-15-aso-incremental-rollout.md](./2026-04-15-aso-incremental-rollout.md)
**Status:** Design draft — no code changes yet. Awaiting user approval on copy direction.

## Why re-design the hero

The current `Slide1()` (in `appstore-screenshots/src/app/page.tsx:1103`) renders:

- Label: `SMART HYDRATION`
- Headline: `Stay Hydrated, Effortlessly`
- Phone mockup: `home-dark.png`
- Background: dark ocean gradient with lagoon/mint/lavender blobs

Problems:

1. **Headline is generic.** "Stay hydrated, effortlessly" is what every water app says. It doesn't differentiate Sipli and doesn't plant any searchable keywords.
2. **Label is brand voice, not keyword voice.** `SMART HYDRATION` reads nice but doesn't hit a single search term.
3. **Watch app is missing.** Slide8 still lists Apple Watch as "Coming Soon" — the whole listing is behind reality.

## Design principles

Keep what works, change what doesn't.

| Keep | Change |
| --- | --- |
| Dark ocean gradient background | Headline copy |
| Blob composition | Label copy (plant keywords) |
| App icon at top | Phone alone → phone + Watch (where supply allows) |
| Phone mockup with glassmorphism | Add a small "NEW" affordance for the Watch app |
| Brand palette | Nothing |

## Proposed copy

**Label (small uppercase, top):** `WATER TRACKER · DRINK REMINDER`
- 30 chars. Hits two high-volume keywords in the first line of the hero.
- Mid-dot separator instead of comma — cleaner typography, Apple-styled.

**Headline (big, center):** `Hydration,\non autopilot.`
- 22 chars, two lines.
- "On autopilot" is the value pitch: Sipli is the hydration app that thinks for you (smart reminders, weather-adjusted goals, workout-aware). It reframes "tracker" as "autopilot" — an elevation, not a demotion.
- Period at end (Apple's convention for hero captions; feels resolved).
- Don't lowercase for style — sentence case is Apple's pattern.

**Optional affordance near phone:** small pill or badge that reads `NEW · APPLE WATCH` in a sun/coral accent color. Only if we add a Watch element to the composition.

## Visual composition

Two candidate compositions — user to pick:

### Candidate A — Copy-only change (safest)

Keep the existing layout identical to Slide1. Change only the text. This is the minimum-risk variant — if it converts worse than the existing, we know the headline was the variable.

### Candidate B — Copy + Watch addition (higher upside, higher effort)

Same structure as A, but add an Apple Watch rendering floating in front-right of the iPhone at ~40% scale, slightly rotated, with a "NEW" pill. This leans into v3.0's freshness and the keyword "apple watch" in the listing.

**Blocking issue for Candidate B:** we don't have a Watch app screenshot source image yet in `public/screenshots/`. We'd need to:
1. Run the Watch app in the Xcode simulator.
2. Capture a screenshot of the dashboard at 410×502 (Series 10 / Ultra 2).
3. Save as `public/screenshots/watch-dashboard.png`.
4. Add a `<Watch>` mockup component analogous to `<Phone>` (see page.tsx:115).

**Recommendation:** ship Candidate A first (Sprint 5a). Build the Watch asset in parallel; if Candidate A wins the PPO test against the current Slide1, promote to production and then A/B test Candidate B against Candidate A in Sprint 5b.

## Proposed JSX for Candidate A

To be pasted into `appstore-screenshots/src/app/page.tsx` next to `Slide1()`:

```tsx
/**
 * Candidate hero for Sprint 5 PPO A/B test vs. Slide1.
 * Copy-only change — same composition, new label + headline.
 * Not wired to IPHONE_SCREENSHOTS yet; exported only when the
 * user approves the copy direction.
 */
function Slide1HeroV2() {
  return (
    <DarkOceanBg
      blobs={
        <>
          <Blob color={BRAND.lagoon} size={600} x={-200} y={200} blur={160} opacity={0.3} />
          <Blob color={BRAND.mint} size={500} x={700} y={1400} blur={140} opacity={0.2} />
          <Blob color={BRAND.lavender} size={400} x={900} y={400} blur={130} opacity={0.15} />
        </>
      }
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          height: "100%",
          paddingTop: H * 0.06,
        }}
      >
        <div
          style={{
            width: W * 0.22,
            aspectRatio: "1 / 1",
            borderRadius: W * 0.05,
            overflow: "hidden",
            boxShadow: "0 20px 60px rgba(28,120,245,0.3)",
            marginBottom: W * 0.035,
            flexShrink: 0,
          }}
        >
          <img
            src="/app-icon.png"
            alt="Sipli"
            style={{ width: "100%", height: "100%", display: "block", objectFit: "contain" }}
          />
        </div>
        <div style={{ marginTop: W * 0.01 }}>
          <CaptionBlock
            canvasW={W}
            label="Water Tracker · Drink Reminder"
            headline={<>Hydration,<br />on autopilot.</>}
          />
        </div>
        <div
          style={{
            flex: 1,
            display: "flex",
            alignItems: "flex-end",
            justifyContent: "center",
            width: "100%",
          }}
        >
          <Phone
            src="/screenshots/home-dark.png"
            alt="Sipli home screen"
            style={{ width: "82%", transform: "translateY(12%)" }}
          />
        </div>
      </div>
    </DarkOceanBg>
  );
}
```

**Note on the `CaptionBlock` component** (defined at page.tsx:253): it auto-uppercases the label via CSS `text-transform: uppercase`, so `"Water Tracker · Drink Reminder"` will render as `WATER TRACKER · DRINK REMINDER`. The mid-dot character is a Unicode middle dot (U+00B7), not a bullet — safer across fonts.

## A/B test mechanics (when we ship)

1. In App Store Connect → Product Page Optimization, create a new test.
2. Variant A = current Slide1. Control group = 50%.
3. Variant B = new Slide1HeroV2. Treatment group = 50%.
4. Test duration: 7 days minimum.
5. Primary metric: **page-view → install conversion**. Secondary: impressions (should be unchanged).
6. If Variant B wins by ≥ 0.8 percentage points of conversion with statistical significance (ASC panel flags this), promote. If it loses or ties, keep current.

## Related stale asset to clean up

While we're here, `Slide8` (the "And So Much More" recap at page.tsx:1240) still lists `"Apple Watch App"` in the **Coming Soon** array:

```tsx
const comingSoon = ["Apple Watch App", "Shortcuts"];
```

Since v3.0 ships the Watch app, this line is stale and will read as misleading the moment v3.0 is live. Remove `"Apple Watch App"` from `comingSoon` and add it to the `features` array. This is a one-line change that should ship alongside the v3.0 binary — not a separate sprint.

## Decision points for the user

1. **Approve the copy?** (`Label: WATER TRACKER · DRINK REMINDER` / `Headline: Hydration, on autopilot.`) — or iterate.
2. **Candidate A only, or queue Candidate B with Watch asset?**
3. **Ship Slide8 cleanup alongside v3.0 release?**

When the answers are in, the code change for Candidate A is about 40 lines and fits in a single commit.
