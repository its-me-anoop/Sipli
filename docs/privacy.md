# Privacy Policy

**Sipli**
**Last updated: March 12, 2026**

Sipli ("we", "our", or "the app") is a hydration tracking app developed by Anoop Jose. This policy explains what information Sipli processes, where it is stored, and the choices you have when using the app.

## Data We Collect

### Personal Information You Provide

During onboarding and in Settings, you may provide:

- **Name** — Used to personalize greetings within the app.
- **Body weight** — Used to calculate your recommended daily hydration goal.
- **Activity level** — Used alongside weight to refine your hydration goal.
- **Wake and sleep times** — Used to schedule reminders within your active hours.

### Hydration Data

- **Water intake entries** — Each entry includes the volume consumed, timestamp, beverage type, source (manual or HealthKit), and an optional note you provide.
- **App preferences** — Settings such as theme, unit system, custom goal, reminder schedule, and premium upsell state are stored so the app can keep your experience consistent.

### Health Data (Apple HealthKit)

If you grant permission, Sipli reads and writes the following HealthKit data:

- **Dietary water** (read and write) — Sipli writes your manually logged water intake to Apple Health and reads water entries from other apps to avoid duplicates.
- **Workouts** (read only) — Sipli reads today's workout duration to adjust your hydration goal for exercise.
- **Active energy burned** (read only) — Sipli reads today's calorie burn to further personalize your hydration goal.

HealthKit data is stored securely by Apple and is never sent to external servers by Sipli.

### Location Data

If you grant permission, Sipli uses location to retrieve local weather conditions via Apple WeatherKit. Sipli requests nearby, city-level weather using approximately 1 kilometer accuracy. Depending on your iPhone settings, Apple may still provide approximate or precise location data to the app. Your location is:

- Used only to fetch weather data (temperature and humidity).
- Held temporarily in memory while the app is open.
- **Not stored in Sipli's local app data, not logged, and not sent to any service other than Apple's location and weather services needed to return weather data.**

### Weather Data

Temperature, humidity, and weather conditions are fetched from Apple WeatherKit and cached locally on your device to adjust your hydration goal for hot or humid conditions.

### Device Motion

Sipli uses your device's accelerometer and gyroscope to animate the liquid effect in the progress view. Motion data is used in real time for visual effects only and is **never stored or transmitted**.

### Widgets and Apple-Managed Sync

Sipli stores app state in a local container that can also be read by the Sipli widget extension so your widgets can show current progress.

Sipli also uses Apple's iCloud key-value store to keep your app state in sync between your own devices when the same Apple Account is signed in and iCloud sync is available. This synced state may include:

- profile and settings
- hydration entries
- recent weather and workout summaries
- premium access state and premium upsell state

We do **not** operate or access this infrastructure ourselves. Sync and backup availability are controlled by Apple and your device/account settings.

## Data We Do Not Collect

- We do **not** collect analytics or usage telemetry.
- We do **not** use third-party tracking, advertising, or analytics SDKs.
- We do **not** operate advertising, profiling, or cross-app tracking systems.
- We do **not** have user accounts, logins, or authentication.
- We do **not** operate any backend servers.

## How Data Is Stored

Sipli stores data locally on your device and, when available, in Apple-managed sync services:

- Profile, hydration entries, recent weather/workout summaries, and app settings are saved in a JSON file in the app's shared container.
- HealthKit data is managed by Apple's encrypted Health database.
- Subscription status is managed by Apple's StoreKit framework.
- Widget content is read from the app's shared container by the Sipli widget extension.
- If you use the same Apple Account across devices and Apple sync services are available, app state may also be stored in Apple's iCloud key-value store and may be included in Apple-managed device backups.

Sipli does **not** send your app data to developer-operated servers.

## Data Sharing

Sipli does not sell, share, or transfer your personal data to third parties.

The only external data flows are:

- **Apple WeatherKit and Core Location** — Your device location is used with Apple's services to retrieve local weather conditions. This is governed by [Apple's Privacy Policy](https://www.apple.com/legal/privacy/).
- **Apple StoreKit** — Subscription purchases and verification are handled entirely by Apple. Sipli does not process or store payment information.
- **Apple HealthKit** — Health data is read from and written to Apple Health with your explicit permission.
- **Apple iCloud key-value store / Apple backups** — If available on your devices, Apple may sync or back up Sipli state on your behalf.

## On-Device Intelligence

On supported devices and operating system versions, Sipli may use Apple's on-device language models (Apple Intelligence / Foundation Models) to generate personalized hydration tips and reminder copy. This processing happens entirely on your device. If on-device AI is unavailable, Sipli falls back to built-in static messages. **Sipli does not send your data to external AI services.**

## Your Choices

You have full control over your data:

- **HealthKit** — You can enable or disable HealthKit access at any time in the app's Settings or in iOS Settings > Privacy & Security > Health.
- **Location** — You can enable or disable location access in iOS Settings > Privacy & Security > Location Services.
- **Notifications** — You can enable or disable notifications in the app's Settings or in iOS Settings > Notifications.
- **Widgets** — You can add or remove Sipli widgets from your Home Screen at any time.
- **Delete entries** — You can delete individual hydration entries from the Diary or Dashboard.
- **Delete all data** — Uninstalling the app removes Sipli's local app and widget data from that device. Copies retained by Apple in iCloud sync or Apple-managed backups are governed by your Apple Account settings.

## Children's Privacy

Sipli is not directed at children under the age of 13. We do not knowingly collect personal information from children.

## Changes to This Policy

We may update this Privacy Policy from time to time. The "Last updated" date at the top of this page indicates when the policy was last revised. Continued use of the app after changes constitutes acceptance of the updated policy.

## Contact

If you have questions about this Privacy Policy, please contact:

**Anoop Jose**
Email: [anoop@flutterly.co.uk](mailto:anoop@flutterly.co.uk)
