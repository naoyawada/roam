# Roam

An iOS app that automatically tracks which city you sleep in each night. Background location capture, rich analytics, and a warm minimal design.

## Features

- **Automatic nightly capture** — logs your city at 2 AM via background location
- **Dashboard** — current city, streak, year summary bar, top cities
- **Timeline** — color-coded calendar view of your nights
- **Insights** — monthly breakdown charts, streaks, home vs. away ratio, year-over-year comparisons
- **All Cities** — ranked list with drill-down for cities beyond the top 5
- **Unresolved nights** — prompts you to fill in missed captures
- **Data export** — CSV or JSON with optional year filtering
- **Dark mode** — fully adaptive warm design

## Design

Cursor-inspired warm minimalism with a leather brown accent (`#7A5C44`), earthy city color palette, paper grain texture, and border-only cards. Top 5 cities get distinct colors; the rest collapse to a neutral "Other" with a detail view.

## Stack

- Swift 6 / SwiftUI / iOS 26
- SwiftData with iCloud sync (CloudKit)
- Core Location (background)
- BGTaskScheduler
- Swift Charts
- MapKit (MKLocalSearchCompleter)

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
  Models/       — SwiftData models (NightLog, CityColor, UserSettings)
  Services/     — Business logic (location capture, analytics, backfill, date normalization)
  Views/        — SwiftUI views by tab (Dashboard, Timeline, Insights, Settings, Onboarding)
  Utilities/    — Design system (RoamTheme, ColorPalette)
RoamTests/      — Unit tests (28 tests)
```

## License

Private — not open source.
