# Sipli

A private, on-device iOS hydration tracker (bundle `com.waterquest.hydration`, App Store id `6758851574`). Adaptive daily goals, Apple Watch quick-logging, widgets, Siri, and a Trophy Room of badges — with no Sipli servers and no accounts.

## Features

- Adaptive daily goal from weight, activity, weather (WeatherKit), and workouts (HealthKit).
- 35+ beverages with hydration factors; one-tap logging on iPhone, Watch, widgets, Control Center, and Siri.
- Streaks with optional streak freezes, weekly quests, and a Trophy Room of 31 badges.
- Share cards for daily, weekly, and badge recaps (rendered on-device).
- Smart reminders that stay inside your wake/sleep window and ease off when you are ahead.
- Privacy by default: local JSON in the app group + optional iCloud key-value sync. No analytics, no accounts, no developer backend.

## Getting Started

1. Open `WaterQuest.xcodeproj` in Xcode.
2. Select a signing team for the `Sipli` (WaterQuest), `SipliWatch`, and `SipliWidget` targets.
3. Build and run on the iOS Simulator or a device.

## Required Capabilities

Enable these in Xcode (Signing & Capabilities):

- HealthKit
- App Groups (`group.com.waterquest.hydration`)
- WeatherKit (optional but recommended)

## Notes

- Weather-based goals require location permission.
- Notifications are scheduled between your wake and sleep times.
- `project.yml` is a historical XcodeGen artifact — do not regenerate from it. The live project is `WaterQuest.xcodeproj`.
- App Store listing copy lives in `docs/app-store-metadata/en-us.md` and `docs/appstore-description.txt`. What's New is `docs/release-notes-5.0.md`.
