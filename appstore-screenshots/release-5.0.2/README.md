# Sipli 5.0.2 App Store screenshots

The release series uses current app simulator captures, preserving each image's
original aspect ratio. App pixels are not recreated, stretched, recolored, or
retouched. Device frames and marketing copy are separate HTML layers. Some
compositions crop the lower portion of a screen at the artboard edge.

## Deliverables

- `iphone/`: five 1320 × 2868 PNGs for `APP_IPHONE_67` (Apple's 6.9-inch slot).
- `ipad13/`: three 2048 × 2732 PNGs for `APP_IPAD_PRO_3GEN_129`.
- `ipad11/`: three 1668 × 2388 PNGs for `APP_IPAD_PRO_3GEN_11`.
- `manifest.json`: ordered upload paths for the `en-US` localization.
- `export-checks.json`: source/rendered dimensions, artboard sizes and filenames.

All exports must be opaque 8-bit RGB PNGs without interlacing. The exporter checks
the PNG header, verifies source images loaded, and rejects distorted app images.
Apple permits these dimensions in its [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/),
checked on 11 September 2026.

## Capture provenance

All source files were captured from the current Sipli 5.0.2 app in dedicated
simulators on 11 September 2026. The fixture uses Alex, a 2,000 ml goal and zero
preunlocked badges. Intake values are deliberate example data, not customer data.

| Source | Origin |
| --- | --- |
| `iphone-full.png` | `qa-screenshots-bottle/01-full.png`, iPhone 17 Pro, iOS 26.5, 1206 × 2622 |
| `iphone-half.png` | `qa-screenshots-bottle/02-half.png`, same simulator, 1,000 ml logged |
| `iphone-tilt.png` | `qa-screenshots-bottle/04-tilt-left.png`, same simulator, injected gravity |
| `iphone-log.png` | Current app screenshot XCTest attachment `4248BF60-1AD5-41A0-ACF6-80BC551A0A98.png` |
| `iphone-diary.png` | Current app screenshot XCTest attachment `FBD906B6-7FB5-4B7D-A5EC-1DB7EBCF652D.png` |
| `ipad-full.png` | `sipli-store-ipad-full.png`, iPad Pro 13-inch, 2064 × 2752 |
| `ipad-half.png` | Current app screenshot XCTest attachment `06D02B3E-363E-4038-A194-0D6F7BA0705C.png` |
| `ipad-diary.png` | Current app screenshot XCTest attachment `62C166DA-FF48-4FAD-BE76-C9B66F80D4F9.png` |

The iPad11 marketing artboards embed the original iPad13 captures proportionally.
They do not claim a separate 11-inch device capture. The tilt image uses the
debug-only simulator gravity input through the same bottle controller; physical
device motion was **NOT RUN**. The other retained `source/` images are reference
captures and are not listed for publication.

## Design

Restrained cream, cobalt and navy, with Baskerville display type and Avenir Next
body type. These use installed macOS fonts; no font files are redistributed.
Headlines range from 133–160 px, supporting text 39–46 px. The visual rhythm moves
from a full screen to a staggered comparison, a cobalt motion slide, an offset
logging screen and a navy diary screen. No decorative glow, generated app UI,
testimonials, ratings, or health outcome claims are introduced.

Marketing text contrast was calculated from the declared OKLCH colors: minimum
5.94:1 (cobalt on mist), 6.71:1 (cream on cobalt), and 14.49:1 (cream on navy).
All marketing text pairs exceed WCAG AA's 4.5:1 threshold. Existing text inside
the authentic app captures is preserved, rather than retouched.

The release compositor is isolated from the legacy screenshot generator.

## Completed export and visual QA — 11 September 2026

All eleven PNGs were exported successfully using the installed Chromium runtime.
The exporter verified each native artboard size, opaque 8-bit RGB PNG format,
noninterlacing, decoded source images, and preserved source aspect ratios.
The release publisher's `load_plan` validation also passed all eleven PNGs,
including PNG checksums and the decoded pixel stream.

Every exported image was opened and visually inspected: five iPhone, three
iPad13 and three iPad11. The display and body fonts rendered correctly, headings
fit, no marketing text overlapped app content, and all featured bottle states,
logging controls and diary content remain visible. The iPhone Save Intake button
is fully visible. Intentional lower-edge device crops in the tilt, logging and
some iPad compositions preserve their featured content. No export correction or
rerender was required after this review.

These checks establish local artifact readiness. Provider upload, review and
public release are verified separately by the root release workflow.

## Reproduce

Set `PLAYWRIGHT_MODULE` to an installed Playwright ESM module and run the exporter
from `appstore-screenshots/`. It loads the compositor directly from disk; a server
and network access are not required:

```sh
PLAYWRIGHT_MODULE=/absolute/path/to/playwright/index.mjs node scripts/export-release.mjs
```

For interactive inspection, optionally run `node scripts/serve-release.mjs`.
The local compositor is then served at
`http://127.0.0.1:4192/release-5.0.2/?device=iphone&slide=1`.
Use `device=ipad13` or `device=ipad11` for the respective native artboards.
The exporter requires local browser-launch permission and an installed Chromium.
It creates the manifest only after all eleven PNGs pass format and aspect checks.

Review every exported image visually before using the root release workflow to
upload it. This compositor never uploads, modifies App Store Connect, or commits.
