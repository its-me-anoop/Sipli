# Thirsty.ai

A playful, gamified iOS hydration tracker with smart goals that adapt to weather and workouts.

## Features
- Smart hydration goal based on weight, activity, weather, and workouts.
- Quests, streaks, coins, and XP to keep hydration fun.
- HealthKit integration (write water, read workouts).
- Local notification reminders.
- Onboarding flow and settings.

## Getting Started
1. Open `WaterQuest.xcodeproj` in Xcode.
2. Select a signing team for the `Thirsty.ai` target.
3. Build and run on the iOS simulator or a device.

## Required Capabilities
Enable these in Xcode (Signing & Capabilities):
- HealthKit
- WeatherKit (optional but recommended)

## Notes
- Weather-based goals require location permission.
- Notifications are scheduled between your wake and sleep times.
- You can override weather values in Settings if WeatherKit is unavailable.
