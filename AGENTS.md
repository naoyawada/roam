# Roam

An iOS app that automatically tracks which city you spend each night in. CLVisit-based passive monitoring with last-known-city propagation, confidence levels, travel day detection, and iCloud sync.

## Project memory

There are two memory tiers; both are worth a look at session start.

1. **`MEMORY.md` in this repo** (if present) — versioned gotchas and rules that travel with
   the code. Anyone may add to it; keep entries short and commit them with the change.
2. **`~/agent-memory/roam/MEMORY.md`** — Naoya's personal, cross-agent working memory
   (a private git repo outside this one). It is a short index that points at topic files
   worth opening for the task at hand. Claude Code writes there automatically. **Other agents
   (Codex included) may write too.** When you learn something durable — a gotcha, a decision,
   a rule Naoya stated, the state of an in-flight project — record it before you finish:
   - Create `~/agent-memory/roam/<type>-<slug>.md` where `<type>` is `feedback`,
     `project`, or `reference`, with YAML frontmatter `name`, `description` (one line), and
     `metadata: {type: <type>, source: <agent>, date: <YYYY-MM-DD>}`, then a short body: the fact,
     **Why**, **How to apply**.
   - Add one line to `MEMORY.md` for a new topic file: `- [Title](file.md) — hook`, at the
     end, with the hook at most 200 characters (details belong in the topic file). When a
     topic changes, reread its current index line and update only that line's hook in place;
     keep its title, link and position. Never regenerate the index from a cached copy, and
     never remove another entry, with one exception: keep the index under 200 lines and
     25,000 bytes, and when it nears either cap, ask Naoya first (it restructures the index),
     then move a group of related entries, unchanged, into a topic file that lists them and
     leave one entry pointing to that file in their place, so every topic stays reachable
     from `MEMORY.md`.
   - Update an existing topic file in place when the fact changes; don't fork it.
   - No secrets, ever: store the name of the 1Password item or env var, not the value.
   Commits are automatic (a hook commits and pushes the memory repo); don't run git there.

## Stack

- **Swift 6**, **SwiftUI**, **SwiftData** (with CloudKit sync)
- **Core Location** — CLVisit monitoring for passive location tracking
- **BGTaskScheduler** — lightweight daily trigger for pipeline catch-up
- **CLGeocoder** for reverse geocoding (coordinate cache to avoid rate limits)
- **Swift Charts** for visualizations
- **MapKit** (`MKLocalSearchCompleter`) for city search
- **XcodeGen** for project generation (`project.yml` → `Roam.xcodeproj`)
- Minimum deployment: **iOS 26**

## Project Structure

```
Roam/
  Models/       — SwiftData @Model classes and enums (DailyEntry, RawVisit, CityRecord, PipelineEvent, UserSettings; legacy: NightLog, CityColor)
  Services/     — Pipeline services (VisitPipeline, DailyAggregator, CityResolver, PipelineLogger, LocationProvider, LegacyMigrator, AnalyticsService, CityDisplayFormatter)
  Views/        — SwiftUI views organized by tab (Dashboard/, Timeline/, Insights/, Settings/, Onboarding/, Shared/)
  Utilities/    — ColorPalette, RoamTheme, HapticService
RoamTests/      — Unit tests (DailyAggregator, CityPropagation, CityResolver, VisitPipeline, LegacyMigrator, Analytics, Deduplication, Export/Import)
```

## Key Concepts

- **DailyEntry**: One entry per calendar day. The `date` field is stored as noon UTC. Primary data record — what the UI reads, what analytics query.
- **RawVisit**: Every CLVisit event received from iOS, stored locally (not synced). Raw input to the aggregation pipeline.
- **CityRecord**: Per-city aggregate stats with `colorIndex` for stable color assignment. Synced via CloudKit.
- **PipelineEvent**: Structured log of pipeline activity for debugging. Local only, auto-pruned after 7 days.
- **Confidence levels**: `high` (CLVisit data), `medium` (propagated from last known city), `low` (fallback/needs attention)
- **EntrySource**: `visit`, `manual`, `propagated`, `fallback`, `migrated`, `debug`
- **Last-known-city propagation**: When no CLVisit fires (stationary user), the pipeline carries forward the last known city with `medium` confidence.
- **Travel day detection**: Multiple cities above a 2-hour threshold in one day → `isTravelDay = true`
- **City key format**: `"City|State|Country"` (pipe-delimited), used as the stable identifier for color lookups and analytics.

## Pipeline Architecture

```
CLVisit received by iOS
  → LiveLocationProvider fires callback
  → VisitPipeline.handleVisit()
    → Filter by accuracy (reject > 1000m)
    → Save RawVisit
    → CityResolver.resolve() (geocode or cache hit)
    → DailyAggregator.aggregate() for affected date(s)
    → Upsert DailyEntry + update CityRecord
    → PipelineLogger logs each step

Daily trigger (BGTask / push / foreground)
  → VisitPipeline.runCatchup()
    → Retry unresolved geocoding
    → Find missing dates
    → Aggregate from RawVisits, or propagate last known city
```

## Working with SwiftData Predicates

SwiftData `#Predicate` macros cannot compare enum cases directly. Always compare against raw value strings:

```swift
// WRONG — will crash at runtime
#Predicate<DailyEntry> { $0.confidence != .low }

// CORRECT — use the stored String property directly
let lowRaw = EntryConfidence.lowRaw
#Predicate<DailyEntry> { $0.confidenceRaw != lowRaw }
```

## Build & Test

```bash
# Generate Xcode project (after editing project.yml)
xcodegen generate

# Build
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# Run all tests
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# Run specific test class
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DailyAggregatorTests -quiet
```

## Testing Strategy

- **Unit test** pure logic: DailyAggregator, CityPropagation, CityResolver (coordinate cache), VisitPipeline, LegacyMigrator, AnalyticsService, CityDisplayFormatter, DataExport/Import, Deduplication
- **Use in-memory SwiftData containers** for service tests (`ModelConfiguration(isStoredInMemoryOnly: true)`)
- **Debug tooling** for integration testing: scenario injection, pipeline inspector, log viewer (Settings → Debug Tools in DEBUG builds)
- **No automated UI tests** — SwiftUI views are verified visually in the simulator
- TDD for all service/logic code: write failing test first, then implement

## Docs

- **Original design spec**: `docs/superpowers/specs/2026-03-16-roam-design.md`
- **Location tracking redesign spec**: `docs/superpowers/specs/2026-03-22-location-tracking-redesign.md`
- **Location tracking redesign plan**: `docs/superpowers/plans/2026-03-22-location-tracking-redesign.md`

## Rules

- **All code must compile and work.** Do not present code that is incomplete, placeholder, or untested. If you're unsure something compiles, verify it before presenting. No "TODO" stubs, no "implement this later" comments, no half-finished functions.
- Always run the build after writing code. If it fails, fix it before showing it to the user.

## Conventions

- Commit messages use imperative mood: `feat:`, `fix:`, `refactor:`, `test:`
- One commit per logical unit of work
- Keep SwiftUI views small and focused — extract subviews into their own files
- Analytics are computed on-device from SwiftData queries, never stored
