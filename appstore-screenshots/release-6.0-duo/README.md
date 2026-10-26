# Sipli 6.0 — iPhone Duo App Store screenshots

Two portrait sets for App Store Connect's iPhone Duo slots, checked against
Apple's [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
on 26 October 2026: outer display 1398 × 2034, inner display 2007 × 2853.
Duo screenshots are optional today (required from April 2027 for apps built with
the iOS 27.1 SDK or later). Submitting them adds the "optimized for iPhone Duo" badge.

- `outer/`: five 1398 × 2034 PNGs (outer display)
- `inner/`: five 2007 × 2853 PNGs (inner display)
- All are opaque 8-bit RGB PNGs (no alpha), as App Store Connect requires.

| # | Outer display | Inner display |
| --- | --- | --- |
| 1 | See what's *left to drink.* (Today) | Made for *iPhone Duo.* (Home) |
| 2 | Every drink, *logged in a tap.* (Log) | Turn it *sideways.* (landscape Home) |
| 3 | Watch your *habit grow.* (Insights) | Every drink, *logged in a tap.* (Log) |
| 4 | Your days, *in a diary.* (Diary) | See the *bigger picture.* (Insights) |
| 5 | A gentle *nudge to sip.* (Coach) | Folded *or open.* (both displays) |

## Sources and frames

`source/` holds the iPhone Duo simulator captures (iOS 27.2, 26 October 2026),
renamed by screen. App pixels are drawn at native aspect ratio (the renderer
asserts this) and are only clipped by the Duo's own screen masks: nothing is
retouched. Unused references: `outer-home-landscape`, `inner-home-landscape-2`
and `inner-log-landscape`.

Frames in `assets/chrome/` are Apple's iPhone Duo simulator artwork: DeviceKit
`phone15` `PhoneComposite.pdf` and button art for the folded Duo, plus the Duo's
cover and inner framebuffer masks. The open-Duo shell is built from the inner mask
with the same rim style and button art, matching how Device Hub draws it.

Design follows release-5.0.2: paper, mist, cobalt and navy, with Baskerville
display and Avenir Next body type (installed macOS fonts).

## Rebuild

From this folder:

```sh
swift render.swift
```

## Not done

## Upload

`manifest.json` lists all ten under one `APP_IPHONE_DUO` set (inner first, then
outer), which `scripts/asc_publish.py` now accepts. Only that set is replaced;
existing iPhone and iPad sets are left alone. Because the folder name differs
from the default, point the release workflow at it:

```sh
PUBLISH_VERSION=6.0 PUBLISH_SCREENSHOTS=appstore-screenshots/release-6.0-duo/manifest.json python3 scripts/asc_publish.py prepare
```

`APP_IPHONE_DUO` is missing from Apple's published API spec. Community tools report
that the live API accepts it, and that outer-display uploads work. Inner-display
uploads haven't been confirmed. Run `prepare` (never `publish`) first and check
the set in App Store Connect.

## Not done

- `docs/release-notes-6.0.md` doesn't exist yet; the release workflow needs it.
- The captures use an empty day (0 ml, 100 % left) and the name "Anoop". Earlier
  releases used the "Alex" fixture with logged water.
