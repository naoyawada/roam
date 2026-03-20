# Import Pipeline Fix — Design Spec

**Issue:** [#27 — Fix import pipeline: merge, dedup, and export bugs causing data loss](https://github.com/naoyawada/roam/issues/27)
**Date:** 2026-03-19

## Problem

After a fresh install with iCloud sync enabled, importing a previously exported JSON file silently discards confirmed city data for recent dates. Three bugs compound:

1. **Import skips instead of merging** — if an unresolved entry already exists for a date (from iCloud sync), import skips it entirely instead of updating with confirmed city data
2. **Import doesn't track within-file duplicates** — `existingDates` is built once and never updated, so duplicate entries in the file both get inserted
3. **Export doesn't deduplicate** — exports all NightLog records including duplicates from iCloud sync bug (#20)

## Approach: Upsert on Import + Mutable Dedup + Export Dedup

Single-pass upsert with a mutable tracking dictionary. Export deduplicates via a shared utility. Priority logic reuses `DeduplicationService.statusPriority` to avoid divergent "best entry" rules.

## Changes

### 1. Import Upsert + Within-File Dedup (Bugs 1 & 2)

**File:** `Roam/Services/DataImportService.swift`

Replace `existingDates: Set<DateComponents>` with `existingEntries: [DateComponents: NightLog]` — a dictionary keyed by date components, mapping to the actual NightLog object. This enables both duplicate detection and in-place updates.

The import loop becomes a 3-way branch:

| Condition | Action | Count |
|-----------|--------|-------|
| Date not seen yet | Insert new NightLog (`.manual` / `.confirmed`), add to `existingEntries` | `imported` |
| Date exists, existing is unresolved, incoming has city data (`city != nil`) | Update existing NightLog in place (city, state, country, lat/lon, accuracy, status → `.confirmed`, source → `.manual`, capturedAt → imported value or `.now`) | `updated` |
| Date exists, existing is confirmed or manual (or incoming has no city) | Skip | `skipped` |

`ImportResult` gains a new field:

```swift
struct ImportResult {
    let imported: Int
    let updated: Int
    let skipped: Int
    let malformed: Int
}
```

Within-file dedup is solved automatically — after inserting or updating, the date is in `existingEntries`, so the second occurrence for the same date is skipped. First entry wins for within-file duplicates.

**Implementation note:** NightLog is a reference type (`@Model class`). On the update path, the existing object is mutated in place, so the dictionary reference remains valid. The `id` (UUID) of the original entry is preserved, which is important for CloudKit record identity.

### 2. Export Dedup (Bug 3)

**File:** `Roam/Services/DataExportService.swift`

Add a static `deduplicatedLogs(_:)` method to `DataExportService`:

- Group logs by normalized date (year/month/day components in UTC)
- For each group, pick the "best" entry using `DeduplicationService.statusPriority` (confirmed > manual > unresolved), with `capturedAt` as tiebreaker — the same rule used by `DeduplicationService.deduplicateNightLogs`
- Return sorted by date

**File:** `Roam/Views/Settings/DataExportView.swift`

Update `filteredLogs` to call `DataExportService.deduplicatedLogs(logs)` after year-filtering. The dedup logic lives in the service layer for testability; the view just calls it.

The "Export N entries" button label will automatically show the correct deduplicated count.

**File:** `Roam/Services/DeduplicationService.swift`

Make `statusPriority` internal (remove `private`) so it can be reused by `DataExportService`.

### 3. UI Summary Update

**File:** `Roam/Views/Settings/DataImportView.swift`

Update `importSummary()` to include the `updated` count:

- Format: `"12 entries imported, 5 updated, 3 skipped (duplicates)"`
- Only show "updated" part when `updated > 0`
- Malformed row reporting unchanged

### 4. Tests

**New tests in `RoamTests/DataImportServiceTests.swift`:**

- Import with existing unresolved entry → entry is updated to confirmed with city data, counted as `updated`
- Import with existing confirmed entry → entry is not overwritten, counted as `skipped`
- Import file with two rows for same date → exactly one entry in DB (first entry wins)
- Import file with two rows for same date with different cities → first city is kept
- Import where incoming has no city data and existing is unresolved → skip
- Update path preserves the original entry's `id` (UUID)

**New tests in `RoamTests/DataExportTests.swift`:**

- Export with duplicate NightLog entries for same date → output contains one entry per date
- Best entry is kept (confirmed-with-city preferred over unresolved)

No changes to existing tests — behavior for fresh imports with no duplicates is unchanged.

## Scope

### In scope
- `Roam/Services/DataImportService.swift` — upsert logic and mutable date tracking
- `Roam/Services/DataExportService.swift` — add `deduplicatedLogs()` static method
- `Roam/Services/DeduplicationService.swift` — make `statusPriority` internal
- `Roam/Views/Settings/DataExportView.swift` — call dedup in `filteredLogs`
- `Roam/Views/Settings/DataImportView.swift` — summary string update
- `RoamTests/` — new test cases

### Out of scope
- Retroactive dedup of existing database entries (that is #20)
- Changes to JSON/CSV export schema
- UI changes beyond the import summary text
- CityColor assignment for newly imported cities (handled by existing launch-time `assignMissingColors()`)

## Done When
- Importing an entry for a date with an existing unresolved entry updates it with confirmed city data
- Importing a file with two entries for the same date inserts exactly one entry
- Exporting deduplicates by date, keeping the best entry per date
- Import summary accurately reports imported, updated, and skipped counts
- Full repro scenario produces a fully-resolved Timeline with no unexpected gaps
- Unit tests cover all new behavior
