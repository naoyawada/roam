# Roam Location Tracking Redesign — Design Spec

> **Date**: 2026-03-22
> **Status**: Draft
> **Goal**: Replace the unreliable BGTaskScheduler-based capture system with a CLVisit-based pipeline that delivers reliable nightly city tracking with travel day detection and confidence indicators.

---

## 1. Problem Statement

The current system uses BGTaskScheduler (2 AM) + silent push notifications + significant location monitoring to capture the user's city each night. In real-world testing, this has been unreliable — Supabase logs show push notifications firing but the app not waking or completing capture. iOS throttles background execution aggressively, and no single wake-up mechanism is dependable.

The redesign switches to CLVisit-based passive monitoring (a system-managed service that iOS wakes the app for) combined with last-known-city propagation for stationary days and multiple lightweight aggregation triggers.

### Design Principles

- **Every night gets an entry** — no gaps in the ledger
- **Every entry is accurate** — confidence levels distinguish certain from uncertain
- **Fully passive** — no user action required for daily tracking
- **Travel-aware** — multi-city days detected and displayed
- **Debuggable** — structured pipeline logging, scenario injection, full observability

---

## 2. Data Models

### 2.1 RawVisit (Local Only — Not Synced)

Stores every CLVisit event received from iOS (or injected via debug tools). Raw input to the aggregation pipeline.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Primary key |
| `latitude` | Double | Visit coordinate |
| `longitude` | Double | Visit coordinate |
| `horizontalAccuracy` | Double | From CLVisit, used for filtering |
| `arrivalDate` | Date | CLVisit arrival time |
| `departureDate` | Date | CLVisit departure time (may be `.distantFuture` for ongoing) |
| `resolvedCity` | String? | Filled by geocoding |
| `resolvedRegion` | String? | State/province |
| `resolvedCountry` | String? | Country code |
| `isCityResolved` | Bool | False until geocoding succeeds |
| `isProcessed` | Bool | True after aggregation has consumed this visit |
| `geocodeAttempts` | Int | Number of geocoding attempts (stop retrying after 5) |
| `source` | String | `"live"` \| `"debug"` \| `"fallback"` |
| `createdAt` | Date | When the record was created |

**Notes:**
- `departureDate` may be `Date.distantFuture` for ongoing visits
- Stored in local-only SwiftData container (no CloudKit)
- `horizontalAccuracy` used for filtering: reject visits > 1000m accuracy

### 2.2 DailyEntry (Synced via CloudKit)

One record per calendar day. The app's primary data — what the UI reads, what analytics query.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Primary key |
| `date` | Date | **Noon UTC** on the calendar date (e.g., 2026-03-22T12:00:00Z) |
| `primaryCity` | String | Longest-stay city for this date |
| `primaryRegion` | String | State/province |
| `primaryCountry` | String | Country code |
| `primaryLatitude` | Double | Canonical coordinates for the city |
| `primaryLongitude` | Double | Canonical coordinates for the city |
| `isTravelDay` | Bool | True if multiple cities above the 2-hour threshold |
| `citiesVisitedJSON` | String | JSON array of structured city objects, chronological order. Example: `'[{"city":"Portland","region":"OR","country":"US"},{"city":"San Francisco","region":"CA","country":"US"}]'` |
| `totalVisitHours` | Double | Total tracked hours for this day |
| `sourceRaw` | String | `"visit"` \| `"manual"` \| `"propagated"` \| `"fallback"` \| `"migrated"` \| `"debug"` |
| `confidenceRaw` | String | `"high"` \| `"medium"` \| `"low"` |
| `createdAt` | Date | When the record was created |
| `updatedAt` | Date | Last modification time |

**Date convention:** Noon UTC, consistent with the existing system. This is timezone-independent and compares correctly across devices via CloudKit.

**String-backed enums:** `sourceRaw` and `confidenceRaw` are stored as String for SwiftData predicate safety (same pattern as current `statusRaw` on NightLog). Companion Swift enums (`EntrySource`, `EntryConfidence`) with raw values provide type safety in non-predicate code. Static raw value constants (e.g., `EntryConfidence.highRaw`) are used in `#Predicate` macros.

**Confidence levels:**

| Level | Meaning | Source |
|-------|---------|--------|
| `high` | Based on CLVisit data or user-confirmed | `visit`, `manual` |
| `medium` | Propagated from last known city (no departure detected) | `propagated`, `migrated` |
| `low` | Fallback GPS or needs user attention | `fallback` |

### 2.3 CityRecord (Synced via CloudKit)

Aggregate stats per city. Includes color assignment (replaces the current CityColor model).

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Primary key |
| `cityName` | String | City name |
| `region` | String | State/province |
| `country` | String | Country code |
| `canonicalLatitude` | Double | Representative coordinate |
| `canonicalLongitude` | Double | Representative coordinate |
| `colorIndex` | Int | Stable color assignment (same concept as current CityColor) |
| `totalDays` | Int | Days where this was primary city |
| `firstVisitedDate` | Date | First appearance |
| `lastVisitedDate` | Date | Most recent appearance |
| `createdAt` | Date | Record creation |
| `updatedAt` | Date | Last modification |

**City identity:** Two visits are the same city if `cityName` + `region` + `country` match. The coordinate cache in CityResolver helps normalize geocoder inconsistencies.

**Color stability:** `colorIndex` assigned sequentially on first appearance, never changes. Migrated from existing CityColor records to preserve user's color associations.

### 2.4 PipelineEvent (Local Only)

Structured log of pipeline activity for debugging and observability.

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | Primary key |
| `timestamp` | Date | When the event occurred |
| `category` | String | Event category (see Section 7) |
| `event` | String | Human-readable event name |
| `detail` | String | Contextual info (city name, error, etc.) |
| `metadata` | String | JSON blob for structured data |
| `appState` | String | `"foreground"` \| `"background"` \| `"terminated"` |
| `rawVisitID` | UUID? | Optional link to related RawVisit |
| `dailyEntryID` | UUID? | Optional link to related DailyEntry |

Auto-pruned: events older than 7 days deleted on app launch.

### 2.5 Container Configuration

Two ModelConfigurations in one ModelContainer (same pattern as existing codebase):

- **Local**: RawVisit + PipelineEvent + UserSettings — `cloudKitDatabase: .none`
- **Synced**: DailyEntry + CityRecord — `cloudKitDatabase: .automatic`

UserSettings is preserved as-is from the current system (home city, onboarding state, notification preferences). It moves to the local configuration alongside the new local-only models.

**During migration transition:** The container also registers legacy models (NightLog, CityColor) in a third read-only configuration so the migrator can read existing data. After migration completes, legacy models remain in the schema (SwiftData does not support removing models from a live store) but are never written to. The CloudKit schema retains the old record types — this is harmless and expected.

**Deduplication:** Since CloudKit does not support unique constraints, DailyEntry may have duplicates for the same date after sync. The app uses a fetch-before-insert pattern when upserting: query for existing DailyEntry matching the noon-UTC date, update if found, insert if not. A periodic deduplication pass (adapted from the existing DeduplicationService) handles any sync-created duplicates by preferring the most recently updated entry.

---

## 3. Location Capture

### 3.1 LocationProvider Protocol

Abstracts the location source for testability.

```
protocol LocationProvider {
    func startMonitoring()
    func stopMonitoring()
    var onVisitReceived: ((VisitData) -> Void)? { get set }
}

struct VisitData {
    let coordinate: CLLocationCoordinate2D
    let arrivalDate: Date
    let departureDate: Date
    let horizontalAccuracy: Double
    let source: String  // "live" | "debug" | "fallback"
}
```

### 3.2 LiveLocationProvider

Wraps `CLLocationManager` with visit monitoring.

- `requestAlwaysAuthorization()`
- `allowsBackgroundLocationUpdates = true`
- `startMonitoringVisits()`
- Delegate method `didVisit` creates `VisitData` and fires callback
- Must handle Swift 6 concurrency: `@MainActor` isolation with `nonisolated` delegate methods trampolining via `Task { @MainActor in ... }`

Note: `pausesLocationUpdatesAutomatically` applies to continuous location updates, not visit monitoring. It is not set here since we only use `startMonitoringVisits()`.

### 3.3 MockLocationProvider

For debug tooling. `injectVisit()` and `injectScenario()` methods fire the same callback, putting synthetic visits through the full pipeline.

### 3.4 Accuracy Filtering

Reject visits with `horizontalAccuracy > 1000m`. Carried forward from the current system's `LocationCaptureService.isValidReading`. Logged as a pipeline event when filtered.

### 3.5 Permission Monitoring

On each foreground event, check `CLLocationManager.authorizationStatus`. If downgraded from `.authorizedAlways`:
- Log via PipelineLogger
- Show a non-intrusive prompt explaining that background tracking requires "Always" permission
- Degrade gracefully (foreground catch-up still works with "When In Use")

---

## 4. City Resolution

### 4.1 CityResolver

Reverse geocodes RawVisit coordinates to city/region/country via `CLGeocoder`.

- `locality` is the primary field for city name
- Falls back to `subAdministrativeArea` for rural areas
- `administrativeArea` for state/province, `isoCountryCode` for country

### 4.2 Coordinate Cache

If a new coordinate is within 5.0 km of a previously resolved coordinate, reuse the cached city name. This:
- Avoids CLGeocoder rate limiting
- Normalizes geocoder inconsistencies ("New York" vs "New York City")
- Cache is in-memory, rebuilt from RawVisit data on launch

### 4.3 Retry Queue

Failed geocoding attempts (offline, rate-limited):
- `isCityResolved` stays false, `geocodeAttempts` increments
- On each pipeline run, retry unresolved visits with exponential backoff
- After 5 failed attempts, stop retrying automatically (user can trigger from debug screen)
- Unresolved visits are skipped by the aggregator and picked up when geocoding eventually succeeds

---

## 5. Daily Aggregation

### 5.1 Core Algorithm

**Timezone rule:** Calendar date boundaries use the **user's local timezone** (device setting at the time of aggregation). A visit spanning local midnight gets split at local midnight. The resulting DailyEntry's `date` is stored as noon UTC for that calendar date (e.g., March 22 local → `2026-03-22T12:00:00Z` regardless of timezone). This separates the aggregation boundary (local midnight, for correctness) from the storage format (noon UTC, for cross-device consistency).

Given all resolved RawVisits for a calendar date, produce a DailyEntry:

1. **Gather visits overlapping this calendar date** — using local timezone midnight boundaries. A visit spanning midnight gets split (hours before midnight → yesterday, hours after → today)
2. **Clamp ongoing visits** — if `departureDate == .distantFuture`, use `min(departureDate, now)` for duration calculation
3. **Calculate hours per city** for this date
4. **Filter short visits** — below 2-hour threshold (filters layovers). If ALL visits are below threshold, fall back to longest but mark confidence as `"low"` (a day of only sub-2-hour visits is uncertain)
5. **Longest stay wins** → `primaryCity`
6. **Multiple cities above threshold** → `isTravelDay = true`, store chronological list in `citiesVisitedJSON`
7. **Create/update DailyEntry** with confidence `"high"`, source `"visit"`

The aggregation is **idempotent** — running it multiple times for the same date produces the same result.

### 5.2 Last-Known-City Propagation

When the aggregator runs for a date and finds **no RawVisits**:

1. Look up the most recent DailyEntry before this date
2. Check: does any RawVisit exist after that entry's date, at a **different city** than the last known city? This indicates the user departed. (Note: CLVisit does not have an explicit "departure" event type — a departure is inferred when a visit at a new location appears.)
3. **No departure detected** (no RawVisits at a different city) → propagate that city forward. Create DailyEntry with confidence `"medium"`, source `"propagated"`
4. **Departure detected but no arrival at a new city for this date** → create DailyEntry with confidence `"low"`, source `"fallback"`, using current GPS if available or marking as needs-attention

**The absence of a departure IS the signal.** If the last known event was "arrived in Atlanta" and no visit at a different city has been seen, the user is still in Atlanta.

### 5.3 Propagated Entry Upgrades

When a late CLVisit arrives:
- Re-run aggregation for affected date(s)
- Propagated or fallback entries get replaced with visit-based entries
- Confidence upgrades to `"high"`

### 5.4 Daily Aggregation Triggers

The aggregator needs to run daily but doesn't need GPS access. Three redundant triggers:

| Trigger | Mechanism | When |
|---------|-----------|------|
| **App foreground** | Check for un-aggregated dates since last entry | Every app open |
| **BGTaskScheduler** | Lightweight task — just runs the aggregator | Scheduled daily (~3 AM) |
| **Silent push** | Existing Supabase infra kicks the pipeline | Fallback, as-is |

None of these need location permission. They invoke the aggregator, which processes RawVisits or propagates the last known city.

---

## 6. Pipeline Orchestration

### 6.1 VisitPipeline

Central coordinator service. All location events and triggers flow through here.

**When a CLVisit arrives:**
```
VisitPipeline.handleVisit(visitData)
  → Filter by accuracy (reject > 1000m)
  → Save as RawVisit
  → CityResolver.resolve() (or queue if offline)
  → DailyAggregator.aggregate() for affected date(s)
  → Upsert DailyEntry + update CityRecord
  → Log pipeline events
```

**When a trigger fires (BGTask / push / foreground) with no new visit:**
```
VisitPipeline.runCatchup()
  → Retry unresolved geocoding
  → Find dates with no DailyEntry since last entry
  → For each: check for unprocessed RawVisits → aggregate
  → For each with no visits: propagate last known city
  → Log pipeline events
```

### 6.2 Late Visit Handling

When a CLVisit arrives with timestamps in the past:
1. Save RawVisit as normal
2. Determine which calendar date(s) it affects
3. Re-run aggregation for those dates
4. Existing DailyEntry gets replaced if visit-based entry wins
5. Log `entry_updated` event

### 6.3 CityRecord Updates

After upserting a DailyEntry:
- Find or create CityRecord for the primary city
- Update `totalDays`, `lastVisitedDate`
- If new city, assign next `colorIndex` in sequence
- **When a DailyEntry's primary city changes** (manual edit, re-aggregation replacing a propagated entry): decrement the old city's `totalDays` and update its `lastVisitedDate`, then increment the new city's stats
- CityRecord stats are denormalized for fast UI access. If stats drift (e.g., due to CloudKit sync conflicts), a full recomputation from DailyEntry data can be triggered from the debug screen

---

## 7. Pipeline Event Logging

### 7.1 PipelineLogger

An `@ModelActor` that owns its own ModelContext (Swift 6 concurrency safe). All pipeline components call into it via async methods.

Created once at app launch with the app's `ModelContainer`, and shared across all pipeline components via dependency injection (not a global singleton). The VisitPipeline holds a reference to it and passes it to CityResolver, DailyAggregator, etc.

Also writes to `os.Logger` for Xcode console and Console.app access.

### 7.2 Event Categories

```
CATEGORY: visit_delivery
├── visit_received           — CLVisit delivered by iOS
├── visit_received_background — CLVisit delivered while app was in background
├── visit_received_terminated — CLVisit delivered after app relaunch
├── visit_ongoing            — Visit has distantFuture departure
├── visit_departure_updated  — Previously ongoing visit now has real departure
├── visit_accuracy_rejected  — Visit filtered for poor accuracy
└── debug_visit_injected     — Visit injected via debug tools

CATEGORY: geocoding
├── geocode_started          — Reverse geocoding request sent
├── geocode_success          — City resolved (detail = "Portland, OR, US")
├── geocode_failed           — Geocoding failed (detail = error message)
├── geocode_queued           — Device offline, deferred
├── geocode_retry_success    — Previously queued geocode succeeded
├── geocode_cache_hit        — Resolved via coordinate cache
└── geocode_abandoned        — Max attempts reached

CATEGORY: aggregation
├── aggregation_started      — Running aggregation for a date
├── visit_filtered           — Visit below duration threshold
├── primary_city_resolved    — Winner determined
├── travel_day_detected      — Multiple cities above threshold
├── city_propagated          — Last known city carried forward
├── entry_created            — New DailyEntry created
├── entry_updated            — Existing DailyEntry updated (late visit)
└── aggregation_skipped      — No resolved visits available

CATEGORY: trigger
├── trigger_foreground       — App foregrounded, running catch-up
├── trigger_bgtask           — BGTaskScheduler fired
├── trigger_push             — Silent push received
└── trigger_manual           — User triggered from debug screen

CATEGORY: lifecycle
├── app_foregrounded         — App came to foreground
├── app_backgrounded         — App entered background
├── permission_changed       — Location authorization changed
├── monitoring_started       — CLVisit monitoring started
├── monitoring_stopped       — CLVisit monitoring stopped
└── migration_complete       — Legacy data migration finished

CATEGORY: debug
├── scenario_loaded          — Debug scenario injected
├── data_wiped               — All data cleared
├── provider_toggled         — Switched live/mock
└── reaggregation_triggered  — Manual re-aggregation from debug screen
```

---

## 8. Debug Tooling

### 8.1 Debug Screen Features

Accessible from Settings. Consolidates all debug/testing functionality:

- **Quick Inject** — Tap a preset city to inject a RawVisit. Goes through the full pipeline.
- **Scenario Player** — Preset multi-day scenarios:
  - Normal Week (7 days at home)
  - **Stationary Week** (single arrival, no visits for 6 days — tests propagation)
  - Trip with Layover (Portland → Denver 90min → SF)
  - Red-Eye Flight (SF 11 PM → NYC 7 AM)
  - Day Trip (Portland base, 4hrs at coast)
  - Data Gap (3 days empty — tests catch-up)
  - Date Line Crossing (Tokyo → Honolulu — user crosses date line and "gains" hours, arriving same calendar date they departed; tests that the aggregator correctly handles two cities on the same local calendar date despite timezone shift)
- **Pipeline Inspector** — View RawVisits, DailyEntries, CityRecords with status indicators
- **Log Viewer** — Chronological PipelineEvent feed with category filters, app-state indicators, expandable metadata, JSON export
- **Data Controls** — Wipe all, wipe local only, export JSON, re-aggregate date range
- **Provider Toggle** — Switch live/mock at runtime
- **Mock Geocoder Toggle** — Use deterministic results for preset coordinates (avoids rate limiting during debug)

### 8.2 Preset Cities

Portland, San Francisco, New York, Los Angeles, Denver, Chicago, Tokyo, London, Sydney — with hardcoded coordinates for mock geocoding.

---

## 9. Legacy Migration

### 9.1 Strategy

Run once on first launch of the new version.

1. Read all existing NightLog entries from SwiftData
2. Create DailyEntry for each:
   - `date` carries over as-is (already noon UTC)
   - `city`/`state`/`country` → `primaryCity`/`primaryRegion`/`primaryCountry`
   - Coordinates from NightLog where present; known city coordinate lookup as fallback
   - `source` = `"migrated"`, `confidence` = `"medium"`
3. Infer travel days: if city on day N differs from city on day N-1, mark day N as travel day with both cities in `citiesVisitedJSON`
4. Build CityRecord entries from aggregated data
5. Transfer `colorIndex` from existing CityColor records to corresponding CityRecords (preserving color continuity)
6. New cities after migration continue the sequence from highest existing index
7. Mark complete via UserDefaults flag
8. Log via PipelineLogger

### 9.2 Safety

- Old NightLog data is never deleted — remains as read-only source of truth
- If migration fails partway, UserDefaults flag isn't set, retries on next launch
- Both old and new models registered in the SwiftData container during transition
- After migration, UI exclusively queries new models

### 9.3 Travel Day Inference

The general rule: if the city on day N differs from the city on day N-1, mark day N as a travel day. This is applied algorithmically to all entries — no city-specific logic.

In the existing data, this would flag transitions like Atlanta ↔ Asheville (multiple round trips) and Atlanta ↔ San Francisco (one round trip) as examples.

On flagged travel days, `citiesVisitedJSON` contains both cities as structured objects. `primaryCity` is the arrival city (where the user ended up).

---

## 10. UI Changes

### 10.1 Confidence Display

| Confidence | Visual Treatment |
|-----------|-----------------|
| `high` | Normal display — solid color dot/cell |
| `medium` | Subtle indicator — slightly dimmed or small mark (these are "pretty sure") |
| `low` | Clear "needs attention" indicator — prompts user to confirm or correct |

### 10.2 Confidence Banner

Replaces the current unresolved banner:
- If any recent entries are `low` confidence: "Some recent nights need your attention"
- Tapping opens list of `low` confidence entries for user to confirm or correct
- `medium` entries don't trigger the banner — reliable enough to be silent

### 10.3 Travel Day Display

- Calendar cells for `isTravelDay` entries show a badge or secondary city label
- Day detail sheet shows chronological city list ("Portland → San Francisco")
- Timeline can filter to show only travel days

### 10.4 Manual Editing

Any DailyEntry can be edited:
- Change primary city (via existing city search)
- Toggle travel day on/off
- Edit cities visited list
- Edited entries get source `"manual"`, confidence `"high"`

---

## 11. Scope Summary

### Keep As-Is
- `ColorPalette`, `RoamTheme`, `HapticService`
- `FlowLayout`, `GrainBackground`, `AnimatingNumber`
- `CitySearchView`, `OnboardingView` (update copy)
- `project.yml`
- Noon-UTC date convention
- Visual design, typography, color palette

### Keep With Adaptation
- Dashboard, Timeline, Insights views — swap NightLog → DailyEntry queries
- `AnalyticsService` — rewrite queries, preserve method signatures
- `CityDisplayFormatter` — adapt field names
- `DeduplicationService` — adapt for DailyEntry (deduplicate by noon-UTC date, prefer most recently updated entry; no LogStatus priority since that concept is replaced by confidence)
- `DataExportService` / `DataImportService` — new models
- `ContentView` — keep tabs, replace capture with catch-up
- `AppDelegate` — keep push as trigger, remove capture logic

### Drop
- `NightLog`, `CityColor`, `LogStatus`, `CaptureSource` models
- `LocationCaptureService`, `BackgroundTaskService`, `SignificantLocationService`
- `BackfillService`, `UnresolvedFilter`, `CaptureResultSaver`
- `UnresolvedBanner`, `UnresolvedResolutionView`
- `DateNormalization` (keep noon-UTC helper, drop before-6-AM rollback)
- `HeartbeatService` (keep Supabase push scheduling, drop telemetry)

### New
- `RawVisit`, `DailyEntry`, `CityRecord`, `PipelineEvent` models
- `VisitPipeline` orchestrator
- `LocationProvider` protocol + `LiveLocationProvider` + `MockLocationProvider`
- `CityResolver` with coordinate cache and retry queue
- `DailyAggregator` with threshold filtering, midnight splitting, propagation
- `PipelineLogger` as `@ModelActor`
- `LegacyMigrator`
- Debug screen views (5-6 files)
- Confidence banner + manual editing UI
- Unit tests for aggregator, propagation, migration, city resolver

---

## 12. Testing Strategy

### Unit Tests
- `DailyAggregatorTests` — aggregation with various visit configurations, midnight splitting, threshold filtering, travel day detection
- `CityPropagationTests` — last-known-city propagation, departure detection, entry upgrades on late visits
- `CityResolverTests` — mock geocoder responses, cache hits, retry behavior
- `ForegroundCatchupTests` — gap detection, trigger behavior
- `LegacyMigratorTests` — migration output verification, travel day inference, color preservation

All use in-memory SwiftData containers (`ModelConfiguration(isStoredInMemoryOnly: true)`).

### Integration Tests (Debug Tooling)
- Scenario player validates full pipeline end-to-end
- Stationary Week scenario specifically validates propagation
- Pipeline Inspector verifies data flow at each stage
- Log Viewer confirms event sequence matches expected patterns

### Soak Testing
- Run both old and new systems in parallel on a real device for field validation
- PipelineLogger provides the evidence for whether CLVisit delivery is working overnight
- Compare new DailyEntry output against old NightLog capture for the same dates

---

## 13. Xcode Configuration

### Info.plist Keys
- `NSLocationAlwaysAndWhenInUseUsageDescription` — "Roam uses your location to automatically log which city you spend each day in. Location is checked passively and resolved to city-level only."
- `NSLocationWhenInUseUsageDescription` — "Roam uses your location to log which city you're in today."

### Capabilities
- **Background Modes**: "Location updates" + "Remote notifications" (for CloudKit sync and push triggers)
- **CloudKit**: Enabled, linked to iCloud container
- **Push Notifications**: Enabled (for CloudKit sync + Supabase push triggers)

### CLLocationManager
- `requestAlwaysAuthorization()`
- `allowsBackgroundLocationUpdates = true`
- `startMonitoringVisits()`
