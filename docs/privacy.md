# Privacy Policy

**Sipli**
**Last updated: February 25, 2026**

Sipli ("we", "our", or "the app") is a hydration tracking app developed by Anoop Jose. Your privacy is important to us. This policy explains what data Sipli collects, how it is used, and your choices regarding that data.

## Data We Collect

### Personal Information You Provide

During onboarding and in Settings, you may provide:

- **Name** — Used to personalize greetings within the app.
- **Body weight** — Used to calculate your recommended daily hydration goal.
- **Activity level** — Used alongside weight to refine your hydration goal.
- **Wake and sleep times** — Used to schedule reminders within your active hours.

### Hydration Data

- **Water intake entries** — Each entry includes the volume consumed, timestamp, beverage type, source (manual or HealthKit), and an optional note you provide.

### Health Data (Apple HealthKit)

If you grant permission, Sipli reads and writes the following HealthKit data:

- **Dietary water** (read and write) — Sipli writes your manually logged water intake to Apple Health and reads water entries from other apps to avoid duplicates.
- **Workouts** (read only) — Sipli reads today's workout duration to adjust your hydration goal for exercise.
- **Active energy burned** (read only) — Sipli reads today's calorie burn to further personalize your hydration goal.

HealthKit data is stored securely by Apple and is never sent to external servers by Sipli.

### Location Data

If you grant permission, Sipli accesses your approximate location (accuracy: ~1 kilometer) to retrieve local weather conditions via Apple WeatherKit. Your location is:

- Used only to fetch weather data (temperature and humidity).
- Held temporarily in memory while the app is open.
- **Never stored to disk, logged, or transmitted to any server other than Apple WeatherKit.**

### Weather Data

Temperature, humidity, and weather conditions are fetched from Apple WeatherKit and cached locally on your device to adjust your hydration goal for hot or humid conditions.

### Device Motion

Sipli uses your device's accelerometer and gyroscope to animate the liquid effect in the progress view. Motion data is used in real time for visual effects only and is **never stored or transmitted**.

### Preferences and Settings

Your app preferences (theme, notification settings, unit system, custom goal) are stored locally on your device using standard iOS storage.

## Data We Do Not Collect

- We do **not** collect analytics or usage telemetry.
- We do **not** use third-party tracking, advertising, or analytics SDKs.
- We do **not** collect device identifiers, IP addresses, or browsing data.
- We do **not** have user accounts, logins, or authentication.
- We do **not** operate any backend servers.

## How Data Is Stored

All app data is stored locally on your device in the app's sandboxed storage:

- Profile and hydration entries are saved in a JSON file within the app's Application Support directory.
- HealthKit data is managed by Apple's encrypted Health database.
- Subscription status is managed by Apple's StoreKit framework.

**No data is synced to the cloud, backed up to external servers, or shared across devices.**

## Data Sharing

Sipli does not sell, share, or transfer your personal data to third parties.

The only external data flows are:

- **Apple WeatherKit** — Your approximate location is sent to Apple's WeatherKit service to retrieve weather conditions. This is governed by [Apple's Privacy Policy](https://www.apple.com/legal/privacy/).
- **Apple StoreKit** — Subscription purchases and verification are handled entirely by Apple. Sipli does not process or store payment information.
- **Apple HealthKit** — Health data is read from and written to Apple Health with your explicit permission.

## On-Device Intelligence

Sipli may use Apple's on-device language models (Apple Intelligence) to generate personalized hydration tips and notification messages on supported devices. This processing happens entirely on your device. **No data is sent to external AI services.**

## Your Choices

You have full control over your data:

- **HealthKit** — You can enable or disable HealthKit access at any time in the app's Settings or in iOS Settings > Privacy & Security > Health.
- **Location** — You can enable or disable location access in iOS Settings > Privacy & Security > Location Services.
- **Notifications** — You can enable or disable notifications in the app's Settings or in iOS Settings > Notifications.
- **Delete entries** — You can delete individual hydration entries from the Diary or Dashboard.
- **Delete all data** — Uninstalling the app removes all locally stored data.

## Children's Privacy

Sipli is not directed at children under the age of 13. We do not knowingly collect personal information from children.

## Changes to This Policy

We may update this Privacy Policy from time to time. The "Last updated" date at the top of this page indicates when the policy was last revised. Continued use of the app after changes constitutes acceptance of the updated policy.

## Contact

If you have questions about this Privacy Policy, please contact:

**Anoop Jose**
Email: [anoop@flutterly.co.uk](mailto:anoop@flutterly.co.uk)
