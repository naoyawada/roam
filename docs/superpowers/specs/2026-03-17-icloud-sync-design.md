# iCloud Sync via CloudKit for SwiftData Models

## Problem

All NightLog, CityColor, and UserSettings data is stored on-device only. If a user loses or replaces their phone, all travel history is gone. The Settings UI exposes an iCloud toggle, but sync is not wired up.

## Approach: Two-Configuration Split

Use two `ModelConfiguration`s within a single `ModelContainer`:

- **Cloud config** — covers `NightLog` and `CityColor`. CloudKit-backed when sync is enabled, local-only when disabled.
- **Local config** — covers `UserSettings`. Always local-only, never syncs.

The sync preference is stored in `UserDefaults` (not SwiftData) to avoid circular sync issues.

## Design

### Entitlements & Project Config

- `Roam.entitlements`: add `com.apple.developer.icloud-services` (CloudKit) and `com.apple.developer.icloud-containers` set to `iCloud.com.naoyawada.roam`
- `project.yml`: add iCloud + CloudKit capability under the Roam target
- CloudKit container `iCloud.com.naoyawada.roam` must be registered in the Apple Developer portal manually

### ModelContainer Architecture

In `RoamApp.swift`:

1. Read `UserDefaults` key `"iCloudSyncEnabled"` (default: `true`) at launch
2. If `true`: create a `ModelConfiguration` with `cloudKitDatabase: .automatic` for `NightLog` and `CityColor`
3. If `false`: create a plain local `ModelConfiguration` for `NightLog` and `CityColor`
4. Always create a separate local-only `ModelConfiguration` for `UserSettings`
5. Pass both configurations into a single `ModelContainer`

When the user is not signed into iCloud at the OS level, the CloudKit-backed configuration silently falls back to local-only storage. No error handling or sign-in prompts are needed.

### iCloud Sync Toggle

In `SettingsView.swift`:

- The toggle reads/writes `UserDefaults` key `"iCloudSyncEnabled"` (default: `true`)
- Remove the current binding to `UserSettings.iCloudSyncEnabled` on the SwiftData model
- Remove the `iCloudSyncEnabled` property from the `UserSettings` model entirely — `UserDefaults` is the source of truth
- When the user flips the toggle, show an alert: "Changing iCloud sync requires restarting the app. Restart now?"
  - Confirm: call `exit(0)`. iOS relaunches the app on next tap, picking up the new container configuration.
  - Cancel: revert the toggle to its previous value.

### UserSettings Stays Local

`UserSettings` always uses a local-only `ModelConfiguration`, regardless of the sync toggle. This prevents:

- Capture schedule times syncing across devices (each device should have its own schedule)
- The sync toggle itself syncing (which would create a feedback loop)
- Home city preference overwriting per-device settings

### Conflict Resolution

Rely on CloudKit's default last-writer-wins at the property level. No custom logic.

Rationale:

- `NightLog` is keyed by normalized date (one per night). Captures happen automatically at 2 AM — simultaneous edits across devices are extremely unlikely.
- `CityColor` is append-mostly (assigned once per city, never changed). Conflicts are near-impossible.
- If a conflict does occur, the most recent write per property wins, which is a reasonable outcome for this data.

## Scope

### In scope

- `Roam/Roam.entitlements` — add CloudKit and iCloud container keys
- `project.yml` — add iCloud + CloudKit capability
- `Roam/RoamApp.swift` — two-config ModelContainer based on UserDefaults preference
- `Roam/Views/Settings/SettingsView.swift` — toggle writes to UserDefaults, restart alert
- `Roam/Models/UserSettings.swift` — remove `iCloudSyncEnabled` property

### Out of scope

- Per-model granular sync control
- Migrating existing local data into CloudKit on first enable
- Sync status indicator in the UI
- Custom conflict resolution UI
- Sign-in prompts or iCloud account detection
