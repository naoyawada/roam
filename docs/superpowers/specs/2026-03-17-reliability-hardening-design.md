# Roam Reliability Hardening — Design Spec

**Date:** 2026-03-17
**Status:** Draft
**Depends on:** Fixes shipped in `8c31a36` (logging, auth checks, backfill fix, scenePhase rescheduling)

## Overview

The nightly background capture is the core function of Roam. A single missed night is a gap in the user's travel history that can never be recovered automatically. This design adds redundant capture layers so that no single iOS limitation can cause a missed log.

## Problem

`BGAppRefreshTask` is best-effort. iOS can delay, skip, or cancel scheduled tasks due to battery state, Low Power Mode, app usage patterns, or user force-quit. The existing system has a single capture path (BGTask at 2 AM) with a single retry (BGTask at 5 AM). If both fail, the only fallback is creating an `.unresolved` entry on next app open via backfill — but that entry has no city data.

## Design: Three-Layer Capture Strategy

Three independent capture paths, any one of which can succeed. Each uses the existing `LocationCaptureService.captureNight()` flow — no new capture logic.

### Layer 1: BGAppRefreshTask (existing, hardened)

Already in place after today's fixes. Fires around 2 AM, retries at 5 AM.

- Logs all scheduling and execution via `os.Logger`
- Checks `.authorizedAlways` before attempting capture
- Reschedules on every foreground return via `scenePhase` observer
- No changes needed in this design

### Layer 2: Significant Location Monitoring (new)

A passive, always-on fallback that survives force-quit and device reboot.

**Service:** `SignificantLocationService` in `Roam/Services/`

**Behavior:**
1. Call `CLLocationManager.startMonitoringSignificantLocationChanges()` at app launch in `RoamApp.init()`
2. When iOS delivers a location update (cell tower change):
   a. Check the current hour in the device's local timezone
   b. If outside the **12:00 AM – 5:59 AM** window → ignore (do nothing)
   c. Compute the normalized night date via `DateNormalization.normalizedNightDate(from: .now)`
   d. Query SwiftData for an existing NightLog with that date
   e. If a confirmed or manual entry already exists → ignore
   f. If no entry exists (or only an unresolved entry) → run `LocationCaptureService.captureNight()`
   g. On success: save confirmed entry (or update existing unresolved entry)
   h. On failure: log the error, do nothing (let BGTask or foreground catch handle it)

**Key properties:**
- `startMonitoringSignificantLocationChanges()` persists across force-quit and reboot — iOS relaunches the app in the background
- Near-zero battery impact (piggybacks on cellular radio, no GPS until we call `captureNight()`)
- Requires `.authorizedAlways` (already requested during onboarding)
- Does NOT replace BGTask — it's a safety net for when BGTask doesn't fire
- All activity logged via `os.Logger` (subsystem: `com.naoyawada.roam`, category: `SignificantLocation`)

**Initialization:**
- `SignificantLocationService` is created and started in `RoamApp.init()`, stored as a property on `RoamApp`
- Needs the `ModelContainer` passed in for SwiftData queries
- Must call `startMonitoringSignificantLocationChanges()` every app launch (iOS docs: "If you start this service and your app is subsequently terminated, the system automatically relaunches the app into the background if a new event arrives.")

**When the app is relaunched by significant location change:**
- `RoamApp.init()` runs → registers BGTask handlers, starts significant location monitoring
- The pending location update is delivered to the delegate
- The delegate checks the time window and captures if needed
- The app returns to the background

### Layer 3: Foreground Catch (new)

When the user opens the app, attempt a live capture if last night is missing.

**Location:** `ContentView.onAppear`, before the existing backfill call.

**Behavior:**
1. Compute the normalized night date for `.now`
2. Query for an existing NightLog with that date
3. If a confirmed or manual entry exists → skip (already captured)
4. If no entry or only an unresolved entry exists:
   a. Check that authorization is `.authorizedAlways`
   b. Attempt `LocationCaptureService.captureNight()`
   c. On success: save confirmed entry (or update unresolved)
   d. On failure: fall through to existing backfill (creates unresolved entry)

**Key properties:**
- Only runs when the user actively opens the app — not intrusive
- If BGTask or significant location monitoring already captured, this is a no-op
- Uses the same `LocationCaptureService` instance already held as `@StateObject` in `ContentView`
- Logged via `os.Logger`

### Safety Net: Backfill (existing)

Already in place. Creates `.unresolved` entries for any nights with no log at all. This is the last resort — the entry will have no city data and the user will need to resolve it manually.

Fixed today: uses `calendarTodayNoonUTC()` instead of `normalizedNightDate()` to avoid skipping last night during the 12-6 AM window.

## Passive Diagnostic in Settings

A read-only "Capture Status" section in `SettingsView` showing:

- **Last capture:** date, time, and city of the most recent confirmed or manual NightLog
- **Next scheduled:** time of next BGTask primary capture (from UserSettings check times)

**Implementation:** A simple SwiftData query in `SettingsView` — most recent NightLog sorted by `capturedAt` descending, filtered to confirmed/manual status. No new model or service needed.

## Capture Priority and Conflict Resolution

Multiple layers may attempt to capture the same night. The existing duplicate-prevention logic handles this:

- Before saving, check if a NightLog exists for the normalized date
- If a **confirmed** or **manual** entry exists → do not overwrite (first successful capture wins)
- If an **unresolved** entry exists → update it with the captured city data and set status to confirmed
- If no entry exists → create a new confirmed entry

This means:
- If BGTask captures at 2 AM, the significant location and foreground catch are no-ops
- If BGTask fails and significant location captures at 3 AM, the foreground catch is a no-op
- If both fail, the foreground catch attempts a live capture on app open
- If all three fail, backfill creates an unresolved entry

## Files Changed

| File | Change |
|------|--------|
| **New:** `Roam/Services/SignificantLocationService.swift` | New service wrapping significant location monitoring |
| `Roam/RoamApp.swift` | Initialize and store `SignificantLocationService`, pass `ModelContainer` |
| `Roam/ContentView.swift` | Add foreground catch attempt before backfill in `onAppear` |
| `Roam/Views/Settings/SettingsView.swift` | Add "Capture Status" section |

## Testing Strategy

- **Unit tests:** `SignificantLocationService` time-window logic (should only capture during 12-6 AM) — test with injected dates
- **Unit tests:** Foreground catch duplicate-prevention (don't overwrite confirmed entries)
- **Manual QA:** Force-quit app, wait overnight, confirm log appears via significant location monitoring
- **Manual QA:** Verify Settings shows correct last capture info

## Summary Table

| Layer | Mechanism | When it fires | Survives force-quit? | Battery impact |
|-------|-----------|--------------|---------------------|----------------|
| 1 | BGAppRefreshTask | ~2 AM (scheduled) | No | Negligible |
| 2 | Significant location monitoring | Cell tower change, 12-6 AM | Yes | Near-zero |
| 3 | Foreground catch | App open | N/A | None |
| Safety net | Backfill | App open | N/A | None |
| Visibility | Settings diagnostic | User checks | N/A | None |
