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
- Navigating between months/years in Timeline — fires once per month/year change, whether via swipe gesture or chevron button tap
- Tapping a calendar day cell in Timeline

**Impact haptics** (medium):
- Confirming a city selection in CitySearchView (recent city tap or search result tap)
- Resolving an unresolved night (confirm button)
- Pinch threshold crossed (month ↔ year transition in Timeline)

**Note:** No custom haptic on tab bar taps. The native SwiftUI `TabView` may provide its own system haptic on iOS 26; adding a custom one risks a double-tap feel. Verify system behavior before adding.

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

### Map

When no cities have coordinates:
- Map centers on device locale region
- Centered overlay text: "Your cities will appear here"
- Style: `RoamTheme.textSecondary`, `.subheadline`

---

## 3. Spatial Zoom Transition (Timeline)

Replace the hard swap between month and year views with a spatial zoom animation.

### Pinch Out (month → year)

1. Current month's calendar grid scales down via `scaleEffect` + position offset
2. Grid animates toward its position in the 4×3 year layout
3. Other 11 mini-months fade in around it

### Pinch In (year → month)

1. Tapped mini-month scales up via `scaleEffect` to fill the view
2. Other 11 months fade out
3. Navigation header cross-fades from year label to month label

### Technical Approach

Use a scale + position animation on the container frame — not `matchedGeometryEffect`. The month and year views have different internal grid structures (42-cell calendar vs compressed mini-month), so `matchedGeometryEffect` would only animate the bounding rectangle while internal content jumps. Instead:

- Track the target mini-month's frame in the year grid using `GeometryReader` + preference key
- On pinch-out: apply `scaleEffect` and `offset` to animate the month view shrinking into the target frame position, then swap to year view
- On pinch-in: start the month view at the mini-month's scale/position, animate to full size
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
- Note: `selectedTab` uses `@State` (not persisted via `@SceneStorage`), so the rawValue renumbering is safe — no migration needed.

### Map Setup

- SwiftUI `Map` view with `.mapStyle(.standard(pointsOfInterest: .excludingAll))`
- Initial camera: fits all pins with padding. If only one city, center on it with reasonable zoom. If no data, center on device locale region.
- No route lines, no clustering

### Pins

- One `Annotation` per unique city from all confirmed/manual NightLogs (exclude unresolved)
- Pin color: matches the city's `CityColor.colorIndex` via `ColorPalette.color(for:)`
- **Note on palette limits:** `ColorPalette` has 5 distinct colors; cities with `colorIndex >= 5` get `otherColor` (semi-transparent gray). Multiple cities may share this color. This is an accepted limitation consistent with how the Dashboard and Timeline already display 6+ cities. Future work can expand the palette.
- Pin visual: filled circle (12pt) with a subtle border, consistent with Timeline legend dot style

### Pin Data Source

- Query all NightLogs, group by city key using `CityDisplayFormatter.cityKey(city:state:country:)` (NightLog does not have a stored `cityKey` property — compute it from the three optional fields)
- For each city: total nights, first visit date, most recent visit date
- **Pin coordinates:** Use the average of all latitude/longitude values from NightLogs with coordinates for that city. This gives a more central pin position than using the first capture, which could be suburban.
- **Cities without coordinates:** Manually-entered cities (via CitySearchView/UnresolvedResolutionView) currently do not store latitude/longitude. These cities are excluded from the map. This is an accepted limitation for v1 — a future improvement could geocode city names to canonical coordinates.

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
| `Roam/ContentView.swift` | Add Map tab (AppTab.map case), shift Insights rawValue |
| `Roam/Views/Dashboard/DashboardView.swift` | Add empty state |
| `Roam/Views/Timeline/TimelineView.swift` | Add empty state, haptics on swipe/pinch/chevron, spatial zoom with scale+position animation |
| `Roam/Views/Timeline/CalendarGridView.swift` | Add haptic on day cell tap |
| `Roam/Views/Timeline/YearDotGridView.swift` | Add GeometryReader preference key for mini-month frame positions |
| `Roam/Views/Insights/InsightsView.swift` | Add empty state |
| `Roam/Views/Settings/CitySearchView.swift` | Add haptic on city selection |
| `Roam/Views/Shared/UnresolvedResolutionView.swift` | Add haptic on confirm |
