# Sipli — More room for your daily ritual

A new promotional film, made independently of the earlier video draft.

- Final: `sipli-iphone-duo-4x1.mp4`
- Canvas: **3840 × 960 (4:1 landscape)**
- Runtime: **26 seconds**, 30 fps
- Picture: H.264; sound: stereo AAC
- Screens: fresh iPhone Duo iOS 27.2 simulator recordings of Sipli Home and Insights, using fictional demo data.
- Hardware: actual Device Hub frame pixels from `assets/frame-open-source.png`, isolated into `assets/native-duo-frame.png` and composited around the recordings. The landscape shell is the same native frame rotated; it is not an invented device drawing.
- Sound: original synthesized ambient cue, created by `soundtrack.py`; no third-party samples or music.

## Edit

| Time | Content |
| --- | --- |
| 0–5 s | “Small sips. Bigger possibilities.” Portrait Duo and live bottle. |
| 5–12 s | “Your daily goal. In full view.” Native landscape layout. |
| 12–20 s | “See the pattern. Build the habit.” Recorded Insights interaction. |
| 20–26 s | Sipli end card with both orientations. |

## Rebuild on macOS

From this directory, with Xcode's Swift tools installed:

```sh
swift render.swift --preview
swiftc -O render.swift -o /tmp/sipli-duo-film
/tmp/sipli-duo-film
python3 soundtrack.py
swift mux.swift
```

`render.swift` reads the source recordings and preserves their preferred orientation. The original simulator app data was backed up before the demo capture and restored afterwards.

## Checks

The four scene previews were visually inspected for device-frame alignment, orientation, text fit and margins. The final export is checked for 3840 × 960 dimensions, 26-second runtime, video/audio tracks, frame count and audio headroom. These are media-delivery checks, not a blanket compatibility certification of every app screen or fold pose.
