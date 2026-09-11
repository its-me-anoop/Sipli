# Home bottle verification

Use a dedicated simulator named **Sipli Bottle QA**, without an Apple Account.
The fixture helper replaces that simulator's Sipli records, requires its exact
UUID and name, and stops the app before writing. It targets unsigned simulator
builds, which store `WaterQuestState.json` in Application Support. Run commands
from the repository root; replace the UUID with your dedicated device's value.

```sh
QA_DEVICE=0B946872-E801-4ED2-B3E1-F1FC11316D77
xcrun simctl bootstatus "$QA_DEVICE" -b
xcodebuild -project WaterQuest.xcodeproj -scheme WaterQuest \
  -configuration Debug -destination "platform=iOS Simulator,id=$QA_DEVICE" \
  -derivedDataPath /private/tmp/sipli-bottle-build \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES build
xcrun simctl install "$QA_DEVICE" \
  /private/tmp/sipli-bottle-build/Build/Products/Debug-iphonesimulator/Sipli.app
python3 scripts/seed-bottle-qa.py --device "$QA_DEVICE" --suppress-achievements
xcodebuild -project WaterQuest.xcodeproj -scheme WaterQuestBottleUI \
  -configuration Debug -destination "platform=iOS Simulator,id=$QA_DEVICE" \
  -derivedDataPath /private/tmp/sipli-bottle-build -parallel-testing-enabled NO \
  -only-testing:WaterQuestBottleUITests/BottleFlowTests/testRemainingWaterBottleFlow \
  -resultBundlePath /private/tmp/sipli-bottle-ui.xcresult \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES test
```

Use a new result-bundle path for each run, and reseed before repeating the UI
flow. The fixture is Alex with a 2,000 ml goal, empty logs, and Health, weather,
and reminders disabled. `--suppress-achievements` preunlocks catalog badges only
to prevent unrelated overlays during UI automation. Omit it for handoff images.

The UI workflow logs drinks, edits amounts up/down, deletes entries, relaunches,
and checks full, partial, goal, and overgoal values. Named screenshot attachments
include opposite injected gravity directions and reduced motion. This UI
workflow passed on the dedicated iOS 26.5 simulator.

With Xcode 27, the existing unit-test bundle links `AppIntentsTesting` and needs
an iOS 27 runtime to load, even when selecting only bottle tests. Use a separate
compatible simulator for the full unit suite. The device below is **Sipli Bottle
Unit QA 27**; it is not a fixture-helper target. Bottle unit coverage includes
draining/refilling, rapid changes, sensor mapping, volume conservation,
settling, and animation lifecycle. The full-suite command is:

```sh
UNIT_DEVICE=1D20B50C-89D3-4B79-813C-F1074DCCFEC9
UNIT_RESULT="/private/tmp/sipli-bottle-full-unit-$(uuidgen).xcresult"
xcrun simctl bootstatus "$UNIT_DEVICE" -b
xcodebuild -project WaterQuest.xcodeproj -scheme WaterQuest \
  -configuration Debug -destination "platform=iOS Simulator,id=$UNIT_DEVICE" \
  -derivedDataPath /private/tmp/sipli-bottle-build -parallel-testing-enabled NO \
  -resultBundlePath "$UNIT_RESULT" \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES test
```

For clean screenshots, seed a desired intake (default 0; maximum 10,000 ml),
launch, let the bottle settle, and capture the simulator:

```sh
python3 scripts/seed-bottle-qa.py --device "$QA_DEVICE" --intake-ml 1000
xcrun simctl launch "$QA_DEVICE" com.waterquest.hydration -hasOnboarded YES
xcrun simctl io "$QA_DEVICE" screenshot /private/tmp/sipli-half.png
```

Debug simulator launches accept `SIPLI_BOTTLE_GRAVITY_X/Y` and
`SIPLI_BOTTLE_REDUCE_MOTION=1`. Set `SIMCTL_CHILD_` before these names when using
`simctl launch`; the UI test sets them directly through `launchEnvironment`.
These exercise the renderer with injected inputs. **Physical-device motion
sensing is not verified by simulator results.**
