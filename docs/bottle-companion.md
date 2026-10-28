# Bottle Companion

Optional tracking for one real water bottle on this device, separate from the daily-goal bottle. Open the Home card to set a capacity between 100 and 5,000 mL. Capacity supports exact entry as well as the slider; quantities display in the profile’s units. Waterline estimates can use the accessible slider or Empty/Half/Full buttons.

- Drank: a lower remaining checkpoint logs only the difference as ordinary water intake, with an estimated-quantity note. Repeating the same checkpoint does nothing; higher checkpoints require Top up or adjustment.
- Top up: match the new level after refilling. No drink is logged.
- Discard / shared: set the remaining contents without logging consumption.
- Finished: log only the contents still remaining, once.
- Undo: restore the previous bottle level and remove only that action’s linked drink ID. Undoing a refill or adjustment changes no intake. Undo remains available after relaunch and midnight; it never subtracts a quantity from a new day.
- Stop tracking: clears the local bottle and its undo after native confirmation, retaining drinks already logged.

The local defaults record contains the bottle, a single undo receipt, and any pending drink receipt. A pending drink has a stable UUID so recovery does not insert the same entry twice. Bottle actions reload shared hydration entries first, then use the existing persistence, notification, goal, Watch and widget update paths. HealthKit uses existing permissions and entry identifiers. The Home daily-goal bottle, ordinary logging and Siri behavior stay independent. Avoid logging a drink from the same bottle through both flows.

The companion uses the existing DashboardCard, bottle renderer, semantic colors and native Form/Picker/sheet controls. Its Home entry inherits FoldAwareSplit; the native sheet owns its viewport, matching existing Log Intake design guidance. No new permissions, subscription gate or cloud service is introduced.

Unit coverage is in BottleCompanionTests; native integration screenshots/rotation are exercised by BottleFlowTests.testBottleCompanionFlow. Debug simulator UI runs use a UUID-named data file and defaults suite to preserve existing app records.
