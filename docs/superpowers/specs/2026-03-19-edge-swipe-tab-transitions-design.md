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

### Back-swipe coexistence
The left edge zone overlaps with the iOS system back-swipe gesture on `NavigationStack`. Rules:
- **At NavigationStack root** (no pushed views): the tab-switch gesture takes effect. The system back gesture has nothing to pop, so there is no conflict.
- **With a pushed view** (e.g., Export Data in Settings): the system back gesture takes priority. The tab-switch edge gesture is suppressed when the active tab's `NavigationStack` has a navigation depth > 0. In practice, only Settings uses `NavigationLink` pushes, and Settings is presented as a sheet (not a tab), so this is unlikely to arise for the three main tabs. If a tab gains pushed views in the future, the container should check `NavigationPath` depth and disable the left-edge gesture accordingly.

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
Tapping a tab bar item also triggers a directional slide animation. The direction is determined by comparing the old and new tab indices (higher index = slide left, lower = slide right). Detected via `.onChange(of: selectedTab)` — this fires for both user taps and any future programmatic tab changes, all of which should animate directionally.

### Gesture priority
The edge-swipe gesture uses `.highPriorityGesture` so it takes precedence over any `.simultaneousGesture` modifiers on child views (e.g., Timeline's month/year drag gestures). Since the edge zone (20pt) and Timeline's gesture zone (mid-content, 50pt minimum distance) don't overlap spatially, both can coexist without interference.

### Animation timing
All transitions use `.spring(duration: 0.3)` — snappy but fluid, in between fast (0.25s) and smooth (0.4s).

### Reduce Motion
When `@Environment(\.accessibilityReduceMotion)` is true, all tab transitions (swipe and tap) use an instant crossfade instead of sliding. The edge gesture still functions but triggers the crossfade rather than finger-tracking.

## Architecture

### SwipeableTabContainer

A new view in `Views/Shared/SwipeableTabContainer.swift` that:

- Accepts a `@Binding<Int>` for the selected tab index (0 = Dashboard, 1 = Timeline, 2 = Insights)
- Lays out tab content views with offset-based horizontal positioning
- Attaches a `DragGesture` restricted to the edge zones
- Tracks finger offset in real-time during the drag
- Keeps all three tab views in the hierarchy at all times (preserving scroll state), but only the current tab and immediate neighbor are positioned on-screen during a gesture
- Handles commit/snap-back logic on gesture end
- Applies rubber-band dampening at boundaries
- Observes selection changes from tab bar taps and animates directionally

### Integration with ContentView

```
TabView (selection binding to selectedTab)
├── Tab("Dashboard")  → Color.clear placeholder
├── Tab("Timeline")   → Color.clear placeholder
├── Tab("Insights")   → Color.clear placeholder
└── .overlay { SwipeableTabContainer(selection: $selectedTab) }
```

The `TabView` exists solely for its native tab bar. Each tab contains `Color.clear` as placeholder content — the real views are rendered in the `SwipeableTabContainer` overlay. Tapping a tab bar item updates `selectedTab`, which the container observes via `.onChange` and animates directionally.

The overlay ignores the tab bar safe area (`.ignoresSafeArea(edges: .bottom)` is NOT used) so it naturally respects the tab bar inset. Each tab's `NavigationStack` with its toolbar and `safeAreaInset` modifiers lives inside the container, behaving identically to how they did inside the `TabView`.

All three tab views remain in the view hierarchy at all times (not lazily loaded) to preserve scroll position and state, matching standard `TabView` behavior. Views off-screen are positioned via horizontal offset but not removed.

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
  - Test with a sheet presented — edge gesture should not leak through the sheet
  - Interruption during gesture (notification pull-down, incoming call) — should snap to nearest tab
