# NightLog Deduplication Design

## Problem

After rebuilding the app, CloudKit sync creates exact duplicates of every NightLog entry. Every count is exactly 2x the correct value (77 → 154 days). The longest streak also breaks because interleaved duplicates disrupt the consecutive-day chain.

Root cause: `NightLog` uses a random `UUID` as its `id` with no uniqueness constraint on `date`. SwiftData + CloudKit treats each UUID as a distinct record, so duplicate entries survive sync merges. The `#Unique` macro is not compatible with CloudKit-backed stores.

## Solution

Add a `DeduplicationService` that runs on every app launch, groups NightLogs by their normalized `date`, and deletes duplicates — keeping the best entry per the priority rule.

## Priority Rule

When multiple NightLogs share the same `date`, keep one using this priority:

1. **Status:** `.confirmed` > `.manual` > `.unresolved`
2. **Tiebreaker:** most recent `capturedAt`

## Components

### `DeduplicationService` (new)

Stateless enum with one `@MainActor` static method:

```swift
static func deduplicateNightLogs(context: ModelContext)
```

Logic:
1. Fetch all NightLogs from the context
2. Group by `date`
3. For each group with > 1 entry, sort by priority rule, keep the first, delete the rest
4. Save if any deletions were made
5. Log the count of deleted duplicates

### Call site: `ContentView.task`

Insert after `backfillMissedNights` and before `assignMissingColors`:

```swift
.task {
    await attemptForegroundCapture()
    BackfillService.backfillMissedNights(context: context)
    DeduplicationService.deduplicateNightLogs(context: context)
    assignMissingColors()
}
```

## Testing

Unit tests using SwiftData in-memory containers:
- Two confirmed entries for same date → keeps most recent `capturedAt`, deletes other
- Confirmed + unresolved for same date → keeps confirmed
- Manual + unresolved for same date → keeps manual
- No duplicates → no deletions, no save
- Multiple dates with mixed duplicates → correct winner per date

## Out of Scope

- Preventing CloudKit from creating duplicates (Apple framework behavior)
- Adding `#Unique` constraints (incompatible with CloudKit stores)
- Query-level deduplication in `AnalyticsService`
- CityColor deduplication (not observed as a problem)
