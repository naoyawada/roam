# UX Polish & Map View Design Spec

**Date:** 2026-03-21

## Overview

Four improvements to elevate Roam's user experience: haptic feedback throughout the app, empty states for new users, a spatial zoom transition in Timeline, and a new Map tab.

---

## 1. Haptic Feedback

Add tactile feedback using `UIImpactFeedbackGenerator` and `UISelectionFeedbackGenerator`.

### HapticService

A small utility enum with static methods:

```swift
enum HapticService {
    static func selection()  // UISelectionFeedbackGenerator
    static func light()      // UIImpactFeedbackGenerator(.light)
    static func medium()     // UIImpactFeedbackGenerator(.medium)
}
```

### Interaction Points

**Selection haptics** (light, subtle):
- Swiping between months/years in Timeline (fires once per month/year change)
- Tapping a calendar day cell in Timeline
- Tapping a tab in the tab bar

**Impact haptics** (medium):
- Confirming a city selection in CitySearchView (recent city tap or search result tap)
- Resolving an unresolved night (confirm button)
- Pinch threshold crossed (month ↔ year transition in Timeline)

---

## 2. Empty States

Minimal text-only empty states when no NightLog data exists. No icons, no buttons — just quiet guidance.

### Dashboard

When no NightLogs exist, replace stats content with centered text:
- Text: "Your first night will appear here"
- Style: `RoamTheme.textSecondary`, `.subheadline`
- The "Roam" navigation title still shows

### Timeline

When no NightLogs exist for the displayed month/year:
- Below the month/year navigation header, centered: "No nights logged"
- Style: `RoamTheme.textSecondary`, `.subheadline`
- Calendar grid still renders with empty cells

### Insights

When no NightLogs exist at all:
- Replace charts/cards with centered: "Insights will appear once you have a few nights logged"
- Style: `RoamTheme.textSecondary`, `.subheadline`
- Year picker still shows current year

---

## 3. Spatial Zoom Transition (Timeline)

Replace the hard swap between month and year views with a spatial zoom animation.

### Pinch Out (month → year)

1. Current month's calendar grid scales down
2. Grid moves to its position in the 4×3 year layout
3. Other 11 mini-months fade in around it

### Pinch In (year → month)

1. Tapped mini-month scales up to fill the view
2. Other 11 months fade out
3. Navigation header cross-fades from year label to month label

### Technical Approach

- Use `@Namespace` with `matchedGeometryEffect` keyed on month index
- Animate the container frame between `CalendarGridView` (month mode) and the corresponding `MiniMonthGridView` cell (year mode)
- Animation: ~0.35s spring
- Accessibility: falls back to simple cross-fade when `accessibilityReduceMotion` is enabled

---

## 4. Map View

A new fourth tab showing all visited cities as colored pins on a minimal Apple Maps base.

### Tab Configuration

- Label: "Map", icon: `map.fill`
- Tab order: Dashboard, Timeline, **Map**, Insights
- Value: `AppTab.map` (new case, rawValue 2; shift Insights to 3)
- Wrapped in `NavigationStack` with `.navigationTitle("Map")`, `.navigationBarTitleDisplayMode(.large)`

### Map Setup

- SwiftUI `Map` view with `.mapStyle(.standard(pointsOfInterest: .excludingAll))`
- Initial camera: fits all pins with padding. If only one city, center on it with reasonable zoom. If no data, center on device locale region.
- No route lines, no clustering

### Pins

- One `Annotation` per unique city from all confirmed/manual NightLogs (exclude unresolved)
- Pin color: matches the city's `CityColor` palette index
- Pin visual: filled circle (12pt) with a subtle border, consistent with Timeline legend dot style
- Cities without stored coordinates are excluded from the map

### Pin Data Source

- Query all NightLogs, group by city key (`City|State|Country`)
- For each city: total nights, first visit date, most recent visit date
- Pin coordinates: use latitude/longitude from the first NightLog with coordinates for that city

### Detail Sheet

Presented on pin tap with `.presentationDetents([.height(200)])`:

- City name formatted via `CityDisplayFormatter` (e.g., "Austin, TX")
- Color swatch: 10×10 rounded rectangle matching the pin color
- Total nights count
- First visit date (formatted `.dateTime.month(.wide).day().year()`)
- Most recent visit date (same format)
- Styled with `RoamTheme` tokens, grain background on sheet

### MapView File Structure

- `Roam/Views/Map/MapView.swift` — main map tab view
- `Roam/Views/Map/CityPinAnnotation.swift` — pin annotation view
- `Roam/Views/Map/CityDetailSheet.swift` — bottom sheet for pin detail

---

## Files to Create

| File | Purpose |
|------|---------|
| `Roam/Utilities/HapticService.swift` | Haptic feedback utility |
| `Roam/Views/Map/MapView.swift` | Map tab view |
| `Roam/Views/Map/CityPinAnnotation.swift` | Pin annotation component |
| `Roam/Views/Map/CityDetailSheet.swift` | Pin detail bottom sheet |

## Files to Modify

| File | Changes |
|------|---------|
| `Roam/ContentView.swift` | Add Map tab, add haptic on tab change |
| `Roam/Views/Dashboard/DashboardView.swift` | Add empty state |
| `Roam/Views/Timeline/TimelineView.swift` | Add empty state, haptics on swipe/pinch, spatial zoom with matchedGeometryEffect |
| `Roam/Views/Timeline/CalendarGridView.swift` | Add haptic on day cell tap |
| `Roam/Views/Timeline/MiniMonthGridView.swift` | Add matchedGeometryEffect anchor |
| `Roam/Views/Timeline/YearDotGridView.swift` | Add matchedGeometryEffect anchor |
| `Roam/Views/Insights/InsightsView.swift` | Add empty state |
| `Roam/Views/Settings/CitySearchView.swift` | Add haptic on city selection |
| `Roam/Views/Shared/UnresolvedResolutionView.swift` | Add haptic on confirm |
