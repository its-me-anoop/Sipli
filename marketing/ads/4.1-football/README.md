# Sipli 4.1 — Football-summer ad set

Five ad creatives for the 4.1 release, themed around the Match Day
football-summer challenge (3 Jul – 2 Aug 2026). App Store link:
https://apps.apple.com/us/app/sipli-water-tracker/id6758851574

| File | Size | Angle |
| --- | --- | --- |
| `01-match-day-hero-1080x1080.png` | 1080×1080 (feed square) | Match Day launch hero — "It's Match Day." |
| `02-goal-scoreboard-1080x1080.png` | 1080×1080 (feed square) | GOAL! scoreboard — You 3–0 Thirst, real in-app commentary line |
| `03-streak-freeze-extra-time-1080x1080.png` | 1080×1080 (feed square) | Streak Freeze as a fourth-official "+1" extra-time board |
| `04-golden-bottle-story-1080x1920.png` | 1080×1920 (story/reel) | Win 12 match days → Golden Bottle badge |
| `05-quick-log-landscape-1200x628.png` | 1200×628 (landscape/link card) | Control Center one-tap + Quick Log presets |

## Copy rules

Same constraint as the in-app Match Day feature (`WaterQuest/Models/MatchDay.swift`):
strictly generic football language. Never reference FIFA, "World Cup",
tournament years, host nations, or official slogans — protected marks
(App Review guideline 5.2.1).

## Regenerating

Sources are plain self-contained HTML in `src/` (brand palette from
`marketing/html5-banners`: navy `#0A3D91`, blue `#1C78F5`, teal `#30C2A3`).
Render with headless Chromium at the exact viewport size, e.g.:

```sh
chromium --headless --no-sandbox --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1080,1080 \
  --screenshot=01-match-day-hero-1080x1080.png \
  src/01-match-day-hero-1080x1080.html
```

Fonts fall back to Liberation Sans (Arial metrics) when SF Pro isn't
installed; rendering on macOS picks up the SF stack automatically.
