# Achievement share cards — 28 October 2026

## Change

The supplied First Brew export was inspected at its native 1080 × 1350 resolution. The previous background contained circles wider than the 360 pt canvas. Their intrinsic size expanded the ZStack's content layout, and the outer fixed frame cropped the resulting header and footer. Background decoration now paints behind an explicitly sized content canvas and is clipped independently. Daily and weekly cards use the same correction.

Achievement cards now use a centered editorial hierarchy, 28 pt text margins, a quiet inset border and Sipli signature. The hero reuses Home's actual glass bottle and liquid geometry as a static still life. First Brew uses the existing Spooky Season palette, bats and pumpkin; other achievements retain their own catalog symbols and category accents. Artwork follows the earned badge's identity, independent of the current seasonal setting. No award eligibility, stored achievements or intake data changed.

Catalog exports remain 1080 × 1350 PNGs. The renderer measures title/detail text, adjusts type and artwork within that composition, and allows unusually long future/localized copy a taller canvas instead of truncation. Static poster type is independent of the sender's Dynamic Type setting. Dates use the requested locale. Exports retain the existing light default; the renderer also supports a tested dark appearance. Native ShareLink previews now show the actual exported image.

## Verification

- `build/share-card-verified.xcresult`: 30 tests passed, zero failures: six renderer tests and 24 achievement engine tests.
- Rendered all 34 catalog achievements in both light and dark at exactly 1080 × 1350.
- Vision OCR checked header/date/title/detail/branding bounds in representative exports. Long German copy, an Arabic date and an extreme long-copy fixture were rendered; the latter expands vertically and preserves its first/last words and footer.
- Confirmed static export bytes remain identical at Accessibility 5 text size. Normal app accessibility settings remain unchanged.
- `build/achievement-share-ui-verified.xcresult`: native Trophy Room → Share First Brew → system activity sheet passed on a healthy existing simulator. No share was sent. The simulator-only UUID fixture makes First Brew the unambiguous latest achievement; production award logic is untouched.
- Generic iOS Release build succeeded with signing disabled (`build/share-release-build.log`). Debug build also succeeded.
- Inspected actual ImageRenderer PNGs for First Brew in light/dark, other seasonal/standard badges, long/localized copy, and daily/weekly cards. Header, body and branding remain within the canvas.
- Native-source design audit: zero findings. Repository-wide audit retains one unrelated preexisting native-select ownership finding in `appstore-screenshots/src/app/page.tsx:2751`; that tool was not edited.
- DESIGN.md schema lint: zero errors, one existing orphan `ink` token warning. Normalized documentation-only radius units to the schema's px notation; native runtime token values are unchanged.
- `git diff --check` passed.

## Preview files

Actual native PNGs are in ignored `build/share-card-previews/`, including `First-Brew-Light.png`, `First-Brew-Dark.png`, `Century-Stream.png`, `Cauldron-Keeper.png`, `Long-Localized-Achievement.png` and `Extra-Long-Achievement.png`. These six were saved successfully to Library for delivery. The supplied original is retained separately in `build/achievement-reference/`.

This is a branch preview. No new TestFlight upload, main merge or public release was performed. Existing TestFlight 6.2 (26) does not contain this change.
