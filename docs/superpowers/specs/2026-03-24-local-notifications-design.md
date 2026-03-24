# Local Push Notifications — Design Spec

**Date**: 2026-03-24
**Issue**: #46
**Branch**: `feat/local-notifications`

## Overview

Add local push notifications for milestones and travel events. Notifications fire from the existing pipeline when entries are committed — no server-side infrastructure needed. All notification types are off by default and independently togglable in Settings.

## Architecture

### NotificationService

A `@MainActor` class that owns all notification decision logic, deduplication, and scheduling.

**Initialization**: Created in `RoamApp.init()` alongside `VisitPipeline`, passed as a dependency. No singleton.

**Dependencies**: `ModelContext`, `NotificationScheduling` (protocol wrapping `UNUserNotificationCenter`).

**Entry point from pipeline**:

```swift
func handleEntryCommitted(
    entry: DailyEntry,
    previousCityKey: String?,
    isNewEntry: Bool
)
```

This method:
1. Checks `UserSettings.notificationsEnabled` — returns early if off
2. Skips entries with `source == .propagated` (no one wants "Still in Portland" daily)
3. Evaluates all 8 notification types in priority order
4. Fires only the highest-priority applicable type (avoids notification spam)
5. Records a dedup key before scheduling

### NotificationScheduling Protocol

```swift
protocol NotificationScheduling: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removeDeliveredNotifications(withIdentifiers: [String])
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}
```

`UNUserNotificationCenter` conforms via extension in production. Tests inject a `MockNotificationCenter` that captures requests.

### Deduplication

Each fired notification writes `"notif-<type>-<YYYY-MM-dd>"` to UserDefaults. Before firing, the service checks for the key's existence. Keys older than 30 days are pruned on each invocation.

### Permission Request

Lazily requested on first toggle-on in Settings, or during onboarding. Uses `requestAuthorization(options: [.alert, .sound])`.

## Notification Types

### Priority Order (highest first)

When multiple types trigger on the same entry, only the highest-priority one fires.

1. Welcome home
2. Trip summary
3. New city
4. Welcome back
5. Travel day
6. Streak milestone

Monthly recap is time-based (not entry-driven) and does not compete. New year milestone fires reactively on first entry of a calendar year and does not compete with the above.

### Type Definitions

#### 1. New City Detected

- **Trigger**: No `CityRecord` exists for this cityKey before this entry is committed
- **Copy**: "First time in Denver! Welcome."
- **Dedup key**: `notif-newCity-2026-03-24`

#### 2. Welcome Back

- **Trigger**: `CityRecord` exists for cityKey, city is not home, `previousCityKey != entry.cityKey`
- **Copy**: "Welcome back to Asheville! Your 4th visit."
- **Enrichment**: Visit count from `CityRecord`
- **Dedup key**: `notif-welcomeBack-2026-03-24`

#### 3. Welcome Home

- **Trigger**: City matches `UserSettings.homeCityKey`, user was away ≥1 day
- **Copy**: "Welcome home. 5 days away."
- **No-op**: If `homeCityKey` is nil
- **Dedup key**: `notif-welcomeHome-2026-03-24`

#### 4. Streak Milestone

- **Trigger**: Current streak in any city hits 7, 14, 30, 60, or 90 days
- **Copy**: "30 days in Portland — nice streak."
- **Enrichment**: `AnalyticsService.currentStreak()`
- **Dedup key**: `notif-streak-2026-03-24-30` (includes threshold)

#### 5. Travel Day

- **Trigger**: `entry.isTravelDay == true`
- **Copy**: "Travel day: Portland → Seattle."
- **Enrichment**: Parse `citiesVisitedJSON` for departure/arrival city names
- **Dedup key**: `notif-travelDay-2026-03-24`

#### 6. Trip Summary

- **Trigger**: Returned to home city after ≥2 days away
- **Copy**: "Back from 6 days away — your 3rd trip to Denver this year."
- **Enrichment**: `AnalyticsService.tripCount()` for trip count
- **No-op**: If `homeCityKey` is nil
- **Dedup key**: `notif-tripSummary-2026-03-24`

#### 7. Monthly Recap

- **Trigger**: `UNCalendarNotificationTrigger` — 1st of month, 9:00 AM local time, repeating
- **Copy**: "March: 4 cities, 3 travel days, 60% away."
- **Scheduling**: Scheduled/rescheduled on each foreground entry. Uses `UNCalendarNotificationTrigger` with `repeats: true`.
- **Enrichment**: Computed at schedule time for the previous month via `AnalyticsService`
- **Note**: Content is computed when the app enters foreground on or after the 1st. If the user doesn't open the app, the notification fires with the last-computed content.
- **No-op**: Home-away percentage omitted if `homeCityKey` is nil
- **Dedup key**: Not needed — managed by `UNCalendarNotificationTrigger` identifier `notif-monthlyRecap`

#### 8. New Year Milestone

- **Trigger**: First entry committed where the calendar year differs from the most recent prior entry's year
- **Copy**: "First city of 2026: Tokyo. Happy new year."
- **Dedup key**: `notif-newYear-2026`

## Notification Copy

- **Tone**: Warm and celebratory — not minimal, not gimmicky
- **City names**: Always formatted via `CityDisplayFormatter.format()` for locale awareness
- **Thread identifiers**: Each type uses its own `threadIdentifier` so iOS groups them in Notification Center

## UserSettings Extensions

New fields added to the `UserSettings` `@Model` (all default `true`):

```swift
var notifyNewCity: Bool = true
var notifyWelcomeBack: Bool = true
var notifyWelcomeHome: Bool = true
var notifyStreakMilestone: Bool = true
var notifyTravelDay: Bool = true
var notifyTripSummary: Bool = true
var notifyMonthlyRecap: Bool = true
var notifyNewYear: Bool = true
```

All sub-toggles are gated behind the existing `notificationsEnabled` master toggle.

## Settings UI

New "Notifications" section in `SettingsView`, placed between "Appearance" and "Tracking Status":

- **Master toggle**: "Notifications" — bound to `settings.notificationsEnabled`
  - First toggle-on triggers `UNUserNotificationCenter.requestAuthorization()`
  - If system permission was denied, shows caption: "Notifications are disabled in System Settings" with a button to open Settings
- **Sub-toggles** (visible when master is on):
  - New City
  - Welcome Back
  - Welcome Home
  - Streak Milestones
  - Travel Day
  - Trip Summary
  - Monthly Recap
  - New Year

Sub-toggles are dimmed (`.disabled(true)`) when the master toggle is off.

## Pipeline Integration

### VisitPipeline Changes

Two call sites, both after `upsertEntry()`:

1. **`aggregateDates()`**: Capture the previous city key before upsert. After upsert, call:
   ```swift
   notificationService.handleEntryCommitted(
       entry: entry,
       previousCityKey: oldCityKey,
       isNewEntry: wasInsert
   )
   ```

2. **`runCatchup()`**: Same call after each entry upsert in the catchup loop.

### Monthly Recap Scheduling

Called on each app foreground via `NotificationService.scheduleMonthlyRecap()`:
- Computes previous month's stats via `AnalyticsService`
- Schedules/replaces a `UNCalendarNotificationTrigger` with identifier `notif-monthlyRecap`

## Testing

### NotificationServiceTests.swift

All tests use in-memory SwiftData containers and `MockNotificationCenter`.

| Test | Verifies |
|------|----------|
| `testNewCityNotification` | Fires when no CityRecord exists for the city |
| `testWelcomeBackNotification` | Fires when CityRecord exists, city != home, city changed |
| `testWelcomeHomeNotification` | Fires when city matches homeCityKey after ≥1 day away |
| `testStreakMilestoneNotification` | Fires at 7, 14, 30, 60, 90 day thresholds |
| `testTravelDayNotification` | Fires when `isTravelDay == true` |
| `testTripSummaryNotification` | Fires on return home after ≥2 days away |
| `testMonthlyRecapScheduling` | Verifies `UNCalendarNotificationTrigger` is configured correctly |
| `testNewYearNotification` | Fires on first entry of a new calendar year |
| `testDeduplication` | Same event twice → only one request scheduled |
| `testPriorityOrder` | Multiple triggers → only highest-priority fires |
| `testNoOpWithoutHomeCity` | Welcome home, trip summary no-op when `homeCityKey` is nil |
| `testToggleRespected` | Disabled toggle suppresses that notification type |
| `testPropagatedEntriesSkipped` | Entries with `source == .propagated` don't fire notifications |

### No changes to existing tests

NotificationService is purely additive. Pipeline behavior is unchanged.

## File Inventory

| File | Action |
|------|--------|
| `Roam/Services/NotificationService.swift` | **New** — all notification logic |
| `Roam/Services/NotificationScheduling.swift` | **New** — protocol + UNUserNotificationCenter extension |
| `Roam/Models/UserSettings.swift` | **Modify** — add 8 toggle fields |
| `Roam/Services/VisitPipeline.swift` | **Modify** — add NotificationService dependency + 2 call sites |
| `Roam/Views/Settings/SettingsView.swift` | **Modify** — add Notifications section |
| `Roam/RoamApp.swift` | **Modify** — initialize NotificationService, schedule monthly recap on foreground |
| `RoamTests/NotificationServiceTests.swift` | **New** — all notification tests |
| `project.yml` | **Modify** — add new files to sources |

## Out of Scope

- Server-side or APNs push delivery
- Rich media attachments or custom notification UI
- Notification history / inbox inside the app
- Digest mode / frequency picker (can add later)
