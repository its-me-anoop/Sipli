# Sipli — iPhone Duo motion graphic

- Output: `sipli-iphone-duo-motion-4k.mp4` — 3840×2160, 60 fps, 34 s, H.264 + AAC stereo
- Screens: the 13 iPhone Duo simulator screenshots in `~/Desktop/iphone Duo Screenshots` (override with `DUO_SCREENS=…`)
- Frames (`assets/chrome/`): Apple's own iPhone Duo simulator artwork
  - Folded (cover display): DeviceKit `phone15` chrome `PhoneComposite.pdf` with its volume/power button art; screen placement from `chrome.json`
  - Unfolded (inner display): the Duo's inner-screen mask, the same rim style and button art, laid out as Device Hub shows the open Duo (hinge marks at the fold)
  - Screenshots are clipped with the Duo's own cover / inner framebuffer masks
- Music: original, synthesized in `render.swift` (no samples)

## Storyboard

| Time | Scene |
| --- | --- |
| 0–2.4 s | Sipli logo sting |
| 2.2–6 s | "Made for iPhone Duo." — folded Duo, cover screen |
| 6–11 s | "Open it up." — cover flips open to the inner display |
| 11–17 s | "Turn it sideways." → "Log a sip in a tap." — rotates to landscape, two-column Home, then the log sheet |
| 17–23 s | "Every screen, rebuilt for more room." — Home, Insights, Log on the inner display |
| 23–28.7 s | "Closed? Still all Sipli." — Today, Insights, Diary, Log on the cover screen |
| 28.6–34 s | End card: "Hydration, unfolded." |

## Rebuild

```sh
swiftc -O -swift-version 5 render.swift -o /tmp/sipli-duo-motion
/tmp/sipli-duo-motion --stills 4.5,9.5,16,20.5,26,31   # preview stills → previews/
/tmp/sipli-duo-motion                                  # full film
```
