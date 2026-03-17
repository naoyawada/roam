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
- After the first development build, push the auto-generated CloudKit schema from the CloudKit Dashboard development environment, then promote to production before release

### ModelContainer Architecture

In `RoamApp.swift`:

1. Read `UserDefaults` key `"iCloudSyncEnabled"` (default: `true`) at launch
2. Create a `ModelConfiguration` named `"cloud"` for `NightLog` and `CityColor`:
   - If sync enabled: set `cloudKitDatabase: .automatic`
   - If sync disabled: set `cloudKitDatabase: .none`
   - **Use the same store URL in both cases** so the local SQLite file retains all data regardless of the toggle. CloudKit sync is a layer on top of the local store — disabling it just stops mirroring, data stays local.
3. Create a separate `ModelConfiguration` named `"local"` for `UserSettings` with `cloudKitDatabase: .none`
4. Pass both configurations into a single `ModelContainer`

Each configuration must have a distinct `name` and resolve to a distinct store file. SwiftData will crash at runtime if two configurations share the same store path.

When the user is not signed into iCloud at the OS level, the CloudKit-backed configuration silently falls back to local-only storage. No error handling or sign-in prompts are needed.

Note: `@Attribute(.unique)` is not supported with CloudKit-backed stores. Duplicate prevention for `NightLog` (one per calendar night) relies on the existing application-level date check before insertion, not a database constraint.

### iCloud Sync Toggle

In `SettingsView.swift`:

- The toggle reads/writes `UserDefaults` key `"iCloudSyncEnabled"` (default: `true`)
- Remove the current binding to `UserSettings.iCloudSyncEnabled` on the SwiftData model
- Remove the `iCloudSyncEnabled` property from the `UserSettings` model entirely — `UserDefaults` is the source of truth
- When the user flips the toggle, show an alert: "iCloud sync change takes effect next time you open the app." with a single OK button. Do **not** call `exit(0)` — Apple rejects apps that programmatically terminate. The user closes and reopens the app manually.

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
- Test files that create `ModelContainer` (e.g. analytics, capture tests) — update to use two-config setup if needed

### Out of scope

- Per-model granular sync control
- Migrating existing local data into CloudKit on first enable
- Sync status indicator in the UI
- Custom conflict resolution UI
- Sign-in prompts or iCloud account detection
