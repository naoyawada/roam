# Roam

An iOS app that automatically tracks which city you sleep in each night. Background location capture at 2 AM, rich analytics, iCloud sync.

## Stack

- **Swift 6**, **SwiftUI**, **SwiftData** (with CloudKit sync)
- **Core Location** for background capture
- **BGTaskScheduler** for nightly background tasks
- **Swift Charts** for visualizations
- **MapKit** (`MKLocalSearchCompleter`) for city search
- **XcodeGen** for project generation (`project.yml` → `Roam.xcodeproj`)
- Minimum deployment: **iOS 26**

## Project Structure

```
Roam/
  Models/       — SwiftData @Model classes and enums (NightLog, CityColor, UserSettings)
  Services/     — Business logic (DateNormalization, LocationCaptureService, BackgroundTaskService, BackfillService, AnalyticsService, CityDisplayFormatter)
  Views/        — SwiftUI views organized by tab (Dashboard/, Timeline/, Insights/, Settings/, Onboarding/, Shared/)
  Utilities/    — ColorPalette
RoamTests/      — Unit tests for pure logic (date normalization, analytics, display formatting, location validation, backfill)
```

## Key Concepts

- **NightLog**: One entry per calendar night. The `date` field is normalized to noon UTC. Captures before 6 AM roll back to the previous calendar day.
- **CityColor**: Persistent city-to-color-index mapping. Colors are assigned in order of first appearance and never change.
- **CaptureSource**: `.automatic` (background) or `.manual` (user-entered)
- **LogStatus**: `.confirmed`, `.unresolved` (capture failed), `.manual` (user-resolved)
- **City key format**: `"City|State|Country"` (pipe-delimited), used as the stable identifier for city color lookups and analytics.

## Working with SwiftData Predicates

SwiftData `#Predicate` macros cannot compare enum cases directly. Always compare against raw value strings:

```swift
// WRONG — will crash at runtime
#Predicate<NightLog> { $0.status != .unresolved }

// CORRECT
let unresolvedRaw = LogStatus.unresolvedRaw
#Predicate<NightLog> { $0.status.rawValue != unresolvedRaw }
```

## Build & Test

```bash
# Generate Xcode project (after editing project.yml)
xcodegen generate

# Build
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet

# Run all tests
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet

# Run specific test class
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/DateNormalizationTests -quiet
```

## Testing Strategy

- **Unit test** pure logic: DateNormalization, AnalyticsService, CityDisplayFormatter, BackfillService, location validation
- **Use in-memory SwiftData containers** for service tests (`ModelConfiguration(isStoredInMemoryOnly: true)`)
- **No automated UI tests** — SwiftUI views are verified visually in the simulator
- TDD for all service/logic code: write failing test first, then implement

## Docs

- **Design spec**: `docs/superpowers/specs/2026-03-16-roam-design.md`
- **Implementation plan**: `docs/superpowers/plans/2026-03-16-roam-implementation.md`

## Rules

- **All code must compile and work.** Do not present code that is incomplete, placeholder, or untested. If you're unsure something compiles, verify it before presenting. No "TODO" stubs, no "implement this later" comments, no half-finished functions.
- Always run the build after writing code. If it fails, fix it before showing it to the user.

## Conventions

- Commit messages use imperative mood: `feat:`, `fix:`, `refactor:`, `test:`
- One commit per logical unit of work
- Keep SwiftUI views small and focused — extract subviews into their own files
- Analytics are computed on-device from SwiftData queries, never stored
