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
| `date` | `Date` | Calendar date (one entry per night) |
| `city` | `String?` | Nullable for unresolved entries |
| `state` | `String?` | State/province/region |
| `country` | `String?` | Country |
| `latitude` | `Double?` | Capture coordinates |
| `longitude` | `Double?` | Capture coordinates |
| `capturedAt` | `Date` | Exact timestamp of location capture |
| `horizontalAccuracy` | `Double?` | GPS accuracy in meters |
| `source` | `CaptureSource` | `.automatic` or `.manual` |
| `status` | `LogStatus` | `.confirmed`, `.unresolved`, `.manual` |

**Constraints:**
- One entry per calendar date. Duplicate dates update rather than insert.
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

### Capture Flow

1. Background task fires → request current location via Core Location
2. Validate reading:
   - Horizontal accuracy must be < 1000m
   - Speed must be < 200 km/h (filters out in-flight captures)
3. **If valid:** Reverse geocode coordinates → save `NightLog` with status `.confirmed`
4. **If invalid:** Schedule retry at 5:00 AM
5. **If retry also fails:** Save entry with status `.unresolved`, surface to user on next app open

### Edge Cases

- **In-flight / mid-travel:** Speed check (> 200 km/h) or low accuracy triggers skip + retry. If both attempts fail, entry is marked `.unresolved`.
- **No placemark returned:** Reverse geocoder returns nothing (open water, remote area) → treated as invalid, retried, then marked `.unresolved`.
- **Timezone changes:** Capture time is based on local time at the device's current timezone.

### Unresolved Resolution

When the user opens the app and unresolved entries exist:
- Show a gentle prompt: "We couldn't tell where you were on [date]. Where were you?"
- City search with autocomplete for manual entry
- Status changes to `.manual` once resolved

### Permissions Required

- **Location:** "Always" access (for background checks)
- **Background App Refresh:** Must be enabled

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
- **Color-coded days** — each city assigned a consistent color
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

- **Home city** — set manually or auto-suggested from most-frequented city
- **Check time** — primary capture time (default 2:00 AM)
- **Retry time** — fallback capture time (default 5:00 AM)
- **iCloud sync** — toggle + last sync timestamp
- **Data export** — CSV or JSON export of all history
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
- Conflict resolution: last-write-wins (sufficient for single-user app)
- Syncs across all user's Apple devices running Roam

## Non-Goals (v1)

- Android support
- Custom backend / server
- Social features / sharing
- Apple Watch app
- Widgets / Live Activities (future enhancement)
- Map view (future enhancement)
