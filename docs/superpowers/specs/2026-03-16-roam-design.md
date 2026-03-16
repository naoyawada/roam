# Roam — Design Spec

**Date:** 2026-03-16
**Status:** Approved

## Overview

Roam is an iOS app that tracks which city you spend each night in, tallying days per city per year with rich analytics. It uses background location capture to automatically log your city each night, syncs via iCloud, and surfaces insights about your travel patterns.

## Platform & Stack

- **Platform:** iOS only (iPhone)
- **Minimum deployment target:** iOS 26
- **Language:** Swift
- **UI:** SwiftUI (Liquid Glass design language)
- **Persistence:** SwiftData with iCloud sync
- **Location:** Core Location (background)
- **Background tasks:** BGTaskScheduler
- **Charts:** Swift Charts
- **Distribution:** Personal use initially, built well enough to share later

## Data Model

### NightLog (primary entity)

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | Primary key |
| `date` | `Date` | Calendar date of the night (see Date Normalization below) |
| `city` | `String?` | Nullable for unresolved entries |
| `state` | `String?` | State/province/region |
| `country` | `String?` | Country |
| `latitude` | `Double?` | Capture coordinates |
| `longitude` | `Double?` | Capture coordinates |
| `capturedAt` | `Date` | Exact timestamp of location capture |
| `horizontalAccuracy` | `Double?` | GPS accuracy in meters |
| `source` | `CaptureSource` | `.automatic` or `.manual` |
| `status` | `LogStatus` | `.confirmed`, `.unresolved`, `.manual` |

**Date Normalization:**
A "night" is defined as the calendar date the evening belongs to. A capture at 2:00 AM on March 17 logs as **March 16** (the night of the 16th). Specifically: if the capture time is before 6:00 AM local time, subtract one calendar day. The `date` field is stored as noon UTC of the normalized calendar date to avoid DST and timezone edge cases. This normalized date is the uniqueness key — one entry per normalized date.

**Timezone handling:** The normalization uses the device's local timezone at the moment of capture. If a user flies from Tokyo to LA and the retry fires at 5 AM LA time, the night is attributed to the calendar date that was "last evening" in LA local time. In rare cross-date-line scenarios, the first successful capture wins; the retry will not overwrite a confirmed entry.

**Constraints:**
- One entry per normalized calendar date. Duplicate dates update only if the existing entry is `.unresolved`; a `.confirmed` entry is never overwritten by an automatic capture.
- City/state/country are nullable to support unresolved entries.

**Derived data (computed, not stored):**
- Year/month groupings via `date`
- Streak calculations (consecutive nights in one city)
- Home vs. away ratio (based on most-frequented city or user-set home)

## Location Capture System

### Background Task Schedule

- **Primary check:** 2:00 AM local time (configurable in settings)
- **Retry check:** 5:00 AM local time (configurable in settings)
- Uses `BGTaskScheduler` with `BGAppRefreshTask`

**BGTaskScheduler limitations:** iOS does not guarantee background task execution at the exact requested time. Tasks may be delayed by hours or skipped entirely (Low Power Mode, low app usage). To mitigate:
- On each foreground launch, check for any missed nights (dates with no entry). For each missed night, if a "Always" location authorization is available, attempt a retroactive capture. If the gap is too old for a meaningful location reading (> 24 hours), create an `.unresolved` entry for each missed night.
- This foreground backfill is the safety net. Background capture is best-effort.

### Capture Flow

1. Background task fires → request current location via Core Location
2. Validate reading:
   - Horizontal accuracy must be < 1000m
   - Speed must be < 55.6 m/s (~200 km/h) — filters out in-flight captures. `CLLocation.speed` reports in m/s.
3. **If valid:** Reverse geocode coordinates → save `NightLog` with status `.confirmed`
4. **If invalid:** Schedule retry at 5:00 AM
5. **If retry also fails:** Save entry with status `.unresolved`, surface to user on next app open

### Edge Cases

- **In-flight / mid-travel:** Speed check (> 200 km/h) or low accuracy triggers skip + retry. If both attempts fail, entry is marked `.unresolved`.
- **No placemark returned:** Reverse geocoder returns nothing (open water, remote area) → treated as invalid, retried, then marked `.unresolved`.
- **Timezone changes:** See Date Normalization in Data Model. The device's local timezone at capture time determines which calendar night the entry belongs to.

### Unresolved Resolution

When the user opens the app and unresolved entries exist:
- Show a gentle prompt: "We couldn't tell where you were on [date]. Where were you?"
- City search with autocomplete via `MKLocalSearchCompleter` (MapKit) — provides city-level results without a custom dataset
- Status changes to `.manual` once resolved

### Permissions Required

- **Location:** "Always" access (for background checks)
- **Background App Refresh:** Must be enabled

### First Launch / Onboarding

iOS requires a two-step flow for "Always" location:
1. Request "While Using" permission first with a clear explanation of why Roam needs location
2. After the user grants "While Using," request upgrade to "Always" with an explanation that background capture needs it
3. If the user denies "Always," the app still works but only captures when opened manually. Show a persistent but dismissible banner explaining limited functionality.

### Display Format

City display follows locale conventions:
- **US:** "City, ST" (e.g., "Austin, TX")
- **International:** "City, Country" (e.g., "Tokyo, Japan")
- Determined by whether `country` matches the device's region setting

## App Structure & Navigation

Three-tab layout with a settings gear icon.

### Tab 1: Dashboard (Home)

The default landing screen. Shows:

- **Current city banner** — city name + current streak ("Day 12 in Austin")
- **Year summary bar** — horizontal stacked bar showing proportional time in each city
- **Top cities list** — ranked by nights, showing count and percentage
- **Quick stats row** — 3 cards: cities visited, longest streak, home ratio

### Tab 2: Timeline

Calendar view of your nights:

- **Monthly calendar grid** — swipe to navigate months
- **Color-coded days** — each city assigned a persistent color from a fixed palette (assigned in order of first appearance, stored as a city-to-color-index mapping in SwiftData). Once a city gets a color, it never changes.
- **Unresolved indicator** — dashed yellow border on unresolved nights
- **Future days** — grayed out
- **Tap-to-detail** — tapping a day shows: city, capture time, accuracy, and an edit option

### Tab 3: Insights

Rich analytics screen:

- **Year picker** — chip-style selector for 2026, 2025, All Time, etc.
- **Monthly breakdown chart** — stacked bar chart (Swift Charts) showing city mix per month
- **Highlights grid** — 2x2 cards:
  - Most visited city
  - Longest streak
  - New cities this year
  - Home vs. away ratio
- **Year-over-year comparison** — table comparing total cities, nights away, avg trip length across years

### Settings (gear icon)

- **Home city** — manual selection only (via city search). On first launch, suggested based on the city with the most nights after 30 days of data. No automatic changes after initial setup.
- **Check time** — primary capture time (default 2:00 AM)
- **Retry time** — fallback capture time (default 5:00 AM)
- **iCloud sync** — toggle + last sync timestamp
- **Data export** — CSV or JSON export. Exports all fields from NightLog (date, city, state, country, coordinates, source, status). Scope: all-time by default, with optional year filter.
- **Notifications** — toggle for unresolved night prompts
- **About / Privacy** — explanation of location data usage

## Analytics Computed

All analytics are computed on-device from SwiftData queries:

- **Days per city per year** — core metric
- **Percentage breakdown** — days in city / total days logged
- **Current streak** — consecutive nights in same city
- **Longest streak** — all-time or per-year
- **Home vs. away ratio** — nights in home city vs. all other cities
- **New cities** — cities appearing for the first time in the selected year
- **Monthly breakdown** — city distribution per month
- **Average trip length** — mean consecutive nights away from home city
- **Year-over-year comparisons** — side-by-side stats across years
- **Travel patterns** — frequency of travel, busiest travel months

## iCloud Sync

- SwiftData with CloudKit integration (`ModelConfiguration` with CloudKit container)
- Automatic background sync — no user action required
- Conflict resolution: last-write-wins (sufficient for single-user app). If two devices both capture the same night, the later write overwrites — this is acceptable since both readings represent valid locations for the same person.
- Syncs across all user's Apple devices running Roam. In practice, users should only have background capture active on their primary iPhone.

## Non-Goals (v1)

- Android support
- Custom backend / server
- Social features / sharing
- Apple Watch app
- Widgets / Live Activities (future enhancement)
- Map view (future enhancement)
