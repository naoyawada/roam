# Edge-Swipe Tab Transitions

**Date:** 2026-03-19
**Issue:** #11 (partial — tab transition animations)

## Problem

Navigating between tabs (Dashboard, Timeline, Insights) has no custom animation, making the app feel abrupt. The Timeline tab already uses horizontal drag gestures for month/year navigation, so a naive full-screen swipe gesture would conflict.

## Solution

A custom `SwipeableTabContainer` that provides interactive, finger-following horizontal slide transitions between tabs. The gesture only activates from the screen edges (~20pt), avoiding conflicts with in-content horizontal gestures.

## Design Decisions

### Edge-only swipe (20pt zone)
The gesture activates only when the touch starts within 20pt of either screen edge. This avoids conflict with Timeline's month/year swipe gestures and any future horizontal scrolling content. Users already have the mental model of "swipe from edge = navigate" from the iOS back gesture.

### Interactive finger-following
Content tracks the user's finger during the drag. The current tab slides away while the adjacent tab peeks in from the edge. This is more polished than a triggered animation and gives the user a sense of direct manipulation.

### Commit threshold
On release, the tab switch commits if:
- Drag distance exceeds 40% of screen width, OR
- Drag velocity exceeds ~500pt/s

Otherwise, the content springs back to the current tab.

### Rubber-band at boundaries
When on the first tab (Dashboard) swiping right, or the last tab (Insights) swiping left, the content follows the finger with a dampening factor (`offset * 0.3`) then springs back on release. Matches the iOS overscroll feel.

### Tap-triggered sliding
Tapping a tab bar item also triggers a directional slide animation. The direction is determined by comparing the old and new tab indices (higher index = slide left, lower = slide right).

### Animation timing
All transitions use `.spring(duration: 0.3)` — snappy but fluid, in between fast (0.25s) and smooth (0.4s).

### Reduce Motion
When `AccessibilitySettings.isReduceMotionEnabled` is true, all tab transitions (swipe and tap) use an instant crossfade instead of sliding. The edge gesture still functions but triggers the crossfade rather than finger-tracking.

## Architecture

### SwipeableTabContainer

A new view in `Views/Shared/SwipeableTabContainer.swift` that:

- Accepts a `@Binding<Int>` for the selected tab index (0 = Dashboard, 1 = Timeline, 2 = Insights)
- Lays out tab content views with offset-based horizontal positioning
- Attaches a `DragGesture` restricted to the edge zones
- Tracks finger offset in real-time during the drag
- Renders only the current tab and the immediate neighbor during a gesture (not all three)
- Handles commit/snap-back logic on gesture end
- Applies rubber-band dampening at boundaries
- Observes selection changes from tab bar taps and animates directionally

### Integration with ContentView

```
TabView (selection binding to selectedTab)
├── Tab("Dashboard")  → proxy content (hidden)
├── Tab("Timeline")   → proxy content (hidden)
├── Tab("Insights")   → proxy content (hidden)
└── .overlay { SwipeableTabContainer(selection: $selectedTab) }
```

The `TabView` exists solely for its native tab bar. Content rendering is handled by the overlay. Tapping a tab bar item updates `selectedTab`, which the container animates.

All three tab views remain in memory (not lazily loaded) to preserve scroll position and state, matching standard `TabView` behavior.

### Sheets and banners

Settings sheet (`.sheet`) and unresolved resolution sheet (`.sheet(item:)`) remain at the `TabView` level, unaffected by the swipe container. The unresolved banner stays within Dashboard's `NavigationStack`.

## File Changes

### New files
- `Views/Shared/SwipeableTabContainer.swift` — container view with gesture, animation, and Reduce Motion logic

### Modified files
- `ContentView.swift` — add `@State private var selectedTab: Int`, replace inline tab content with `SwipeableTabContainer` overlay

### Unchanged
- All existing tab views (DashboardView, TimelineView, InsightsView) — no modifications needed

## Test Plan

- **Unit tests:** None (purely visual/gestural)
- **Manual QA:**
  - Edge swipe left/right between all three tabs
  - Verify mid-content swipes in Timeline month/year views still work
  - Tap tab bar items and verify directional slide
  - Rapid tab switching (both swipe and tap)
  - Rubber-band at Dashboard (left edge) and Insights (right edge)
  - Back-swipe gesture mid-transition
  - Enable Reduce Motion in Settings → verify crossfade fallback
  - VoiceOver active — verify tab switching still works
  - Verify sheets (Settings, DayDetail, CitySearch, UnresolvedResolution) present normally
  - Verify no regressions on scroll state or view layout within each tab
