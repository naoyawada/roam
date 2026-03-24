# Roam

An iOS app that automatically tracks which city you spend each day in. Passive CLVisit-based location monitoring, rich analytics, and a warm minimal design.

## Features

- **Passive location tracking** — CLVisit monitoring detects city arrivals/departures with no manual input
- **Last-known-city propagation** — stationary days are filled in automatically with medium confidence
- **Travel day detection** — multiple cities in one day are flagged with departure/arrival details
- **Dashboard** — current city, streak, year summary bar, top cities
- **Timeline** — color-coded calendar view with spatial zoom transitions
- **Insights** — monthly breakdown charts, streaks, home vs. away ratio, travel stats
- **Local notifications** — 8 types (new city, welcome back, welcome home, trip summary, travel day, streak milestones, monthly recap, new year) with per-type toggles
- **Color themes** — 5 palettes (Earthy, Cool, Warm, Botanical, Mono)
- **Data export/import** — CSV or JSON with duplicate detection
- **iCloud sync** — DailyEntry and CityRecord sync via CloudKit

## Stack

- Swift 6 / SwiftUI / iOS 26
- SwiftData with CloudKit sync
- Core Location (CLVisit monitoring + significant location changes)
- BGTaskScheduler (daily catch-up)
- UserNotifications (local push)
- Swift Charts
- MapKit (MKLocalSearchCompleter for city search)
- XcodeGen (project.yml → Roam.xcodeproj)

## Building

```bash
# Generate Xcode project
brew install xcodegen
xcodegen generate

# Build
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

# Test
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

## Project Structure

```
Roam/
  Models/       — SwiftData models (DailyEntry, RawVisit, CityRecord, UserSettings, PipelineEvent)
  Services/     — Pipeline (VisitPipeline, DailyAggregator, CityResolver, NotificationService, AnalyticsService, LocationProvider)
  Views/        — SwiftUI views by tab (Dashboard, Timeline, Insights, Settings, Onboarding, Shared)
  Utilities/    — Design system (RoamTheme, ColorPalette, HapticService)
RoamTests/      — Unit tests (79 tests)
```

## Privacy

Location data is stored on-device (raw coordinates) and at the city level in iCloud. Your data is never shared with third parties. See [PRIVACY.md](PRIVACY.md) for details.

## License

Private — not open source.
