# Sipli — Earth Week 2026 Keynote Video

An Apple Keynote–style animated presentation for Sipli's Earth Week event
(April 20–26, 2026). Built as a self-contained 1920×1080 HTML scene with
timed transitions so it can be previewed in a browser, embedded in a site,
or screen-recorded straight to MP4 for YouTube / the App Store.

All imagery is sourced from the repository:

| Asset                                | Source                                                          |
|--------------------------------------|-----------------------------------------------------------------|
| `assets/app-icon.png`                | `appstore-screenshots/public/app-icon.png`                      |
| `assets/earth.png`                   | `WaterQuest/Assets.xcassets/earth.imageset/earth.png`           |
| `assets/sipli-icon.png`              | `WaterQuest/Assets.xcassets/sipliIcon.imageset/sipliIcon.png`   |
| `assets/bottle.png`                  | `WaterQuest/Assets.xcassets/bottle.imageset/bottle.png`         |
| `assets/screenshots/iphone/*`        | `appstore-screenshots/public/screenshots/iphone/`               |
| `assets/screenshots/watch/*`         | `appstore-screenshots/public/screenshots/watch/`                |
| `assets/screenshots/ipad/*`          | `appstore-screenshots/public/screenshots/ipad/`                 |

## Running it locally

```bash
cd marketing/earth-week-keynote
python3 -m http.server 8080
# open http://localhost:8080
```

Space bar pauses, `R` restarts. The timeline loops automatically.

Append `?clean=1` to hide the progress bar and on-screen controls when
recording: `http://localhost:8080/?clean=1`.

## Scene timeline (≈ 96 s)

| # | Scene              | Dur  | Copy                                               |
|---|--------------------|------|----------------------------------------------------|
| 1 | Cold open (logo)   | 5 s  | —                                                  |
| 2 | Title              | 7 s  | "Every sip, less plastic."                         |
| 3 | Dates              | 7 s  | "April 20–26, 2026"                                |
| 4 | Ethos              | 7 s  | "Every refill is one less plastic bottle."         |
| 5 | Dashboard banner   | 10 s | iPhone hero screen + "A gentle nudge, once a day." |
| 6 | Refill Pledge      | 11 s | Rebuilt EarthDayPledgeView card                    |
| 7 | Earth progress     | 9 s  | `earth.png` hero with 72% fill                     |
| 8 | Features grid      | 12 s | Insights / Coach / Widgets                         |
| 9 | Apple Watch        | 8 s  | Three watch faces                                  |
| 10| Closing CTA        | 10 s | App Store badge + deep link                        |

## Exporting to MP4

The presentation was designed to be recorded rather than pre-rendered, so
you keep full control over resolution, bitrate and framerate.

### Option A — macOS QuickTime (fastest)

1. Open `index.html?clean=1` in Safari, press `F` for full-screen.
2. QuickTime → File → New Screen Recording → record the full screen.
3. Trim to one loop (≈ 96 s) and export at 1080p or 4K.

### Option B — Headless Chrome + ffmpeg (deterministic)

```bash
# 1. Capture a PNG every frame for 100 s at 60fps (requires Node/Puppeteer
#    — any screen-capture script works too).
# 2. Stitch frames with ffmpeg:
ffmpeg -r 60 -i frame_%05d.png \
       -c:v libx264 -pix_fmt yuv420p -crf 17 \
       sipli-earth-week-2026.mp4
```

### Option C — OBS (cross-platform)

1. Add a Browser source pointing at `file:///…/index.html?clean=1` at 1920×1080.
2. Start Recording, wait for one full loop, stop.
3. Trim and export.

## Event metadata (for reference)

- Event window: `WaterQuest/Services/EarthDayEvent.swift` — April 20, 2026
  00:00 to April 27, 2026 00:00 (local).
- Earth Day: April 22, 2026.
- App Store: https://apps.apple.com/gb/app/sipli-water-tracker/id6758851574
