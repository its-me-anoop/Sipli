# Phase 1 QA Summary — 2026-04-17

**Device:** iPhone 17 Pro simulator (72CEFB58-398E-4832-B3B2-EB2CF4A583F6, OS 26.4)
**Final build commit:** be59cfe

## Automated verification

- [x] Clean build on iPhone 17 Pro simulator
- [x] 18/18 unit tests passing: `test_sanity`, 4× `NotificationContextTests`, 1× `buildNotificationContext` integration, 7× `NotificationMessageTests`, 5× `NotificationCategoriesTests`
- [x] Code inspection: all planned Phase 1 files present and wired
- [x] No dead code: `minimumGapSeconds`, `quietThresholdMultiplier`, `removeAllDeliveredNotifications`, `curatedMessage`, `generateMessage` all absent from the `WaterQuest/` source tree (documentation mentions in plan are fine)

## Manual QA checklist (requires physical simulator interaction)

These verifications cannot be driven by the XcodeBuildMCP tool surface currently enabled. Run them manually before merging the phase:

1. **Install fresh build and onboard.** Fresh user, notification permission granted, smart reminders enabled (requires Premium — flip via StoreKit test config at `Products.storekit` or add a `#if DEBUG` override on `SubscriptionManager.isSubscribed`).

2. **Configure narrow awake window for fast firing.** Settings → wake time 1 hour ago, sleep time 2 hours from now. This forces `computeInterval` to return ≤ 60 minutes so the first reminder fires soon.

3. **Log 200 ml from the dashboard.** Wait for smart reminder to fire (should be within 30-60 min).

4. **Verify action buttons render on banner + lock screen.** Long-press the banner. Expect three actions: "Log 250 ml", "Log 500 ml", "Snooze 1 hr".

5. **LOG_250ML from lock screen.** Lock the device. Wait for next reminder. Tap "Log 250 ml" from the lock-screen banner. Expect: no app foreground, notification dismisses, and when you open the app the dashboard shows the 250 ml entry.

6. **LOG_500ML from lock screen.** Same flow with the 500 ml button.

7. **SNOOZE_1H behavior.** Wait for next reminder, tap "Snooze 1 hr". Expect the notification to dismiss. Open the app immediately (this triggers scheduleReminders). Then wait ~60 min — the snoozed notification should still fire (confirming Task 8's snooze-survives-foreground fix).

8. **Default tap opens Add Intake sheet.** Wait for next reminder, tap the banner BODY (not an action). Expect: app foregrounds and the Add Intake sheet is presented (via the deepLink → deepLinkForwarder → deepLinkAddIntake chain).

9. **Apple Intelligence variety (if Premium + iOS 26 + capable device).** Over several reminders, observe whether the first-fire notification of each batch carries copy distinct from subsequent ones. If you see the same 4-5 curated messages recycling, the AI path didn't fire — check logs for `"NotificationHandler: failed to schedule snooze"` or AI generation errors.

10. **Free tier (classic mode) is time-of-day aware.** Turn off Smart reminders in Settings (becomes classic mode). Observe the daily reminders — morning ones should use "first"-slot copy, midday ones "mid", evening ones "late". (Note: classic reminders use daily-repeating calendar triggers, so you see this over a day or by logging at different times.)

## Known limitations / follow-ups

- The AI generation path is not unit-tested; regressions can only be caught by manual QA.
- `NotificationHandler`'s action-handler logic is also not unit-tested — same reason.
- `deepLinkForwarder.shouldOpenAddIntake` has a subtle re-entrance window if the user taps two notifications in rapid succession before the reset fires. Low-probability; not blocking Phase 1.

## Phase 1 complete when

- All automated checks above pass (done).
- Manual checks 1-8 pass on the Phase 1 build.
- Manual checks 9-10 demonstrate expected behavior (or known limitations documented above).
