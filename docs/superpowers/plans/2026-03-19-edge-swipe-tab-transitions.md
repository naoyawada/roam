# Edge-Swipe Tab Transitions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add interactive, finger-following horizontal slide transitions between tabs, triggered by edge swipes and tab bar taps.

**Architecture:** A new `SwipeableTabContainer` view manages the three tab content views with offset-based horizontal positioning. It attaches a `DragGesture` restricted to 20pt edge zones, tracks finger offset in real-time, and handles commit/snap-back/rubber-band logic. The existing `TabView` keeps its native tab bar but delegates content rendering to this overlay.

**Tech Stack:** SwiftUI (iOS 26), `DragGesture`, `GeometryReader`, spring animations, `@Environment(\.accessibilityReduceMotion)`

**Spec:** `docs/superpowers/specs/2026-03-19-edge-swipe-tab-transitions-design.md`
**Issue:** #11

---

### Task 1: Create SwipeableTabContainer with static layout

**Files:**
- Create: `Roam/Views/Shared/SwipeableTabContainer.swift`

Build the container that lays out three tab views side by side using horizontal offsets, showing only the selected tab.

- [ ] **Step 1: Create SwipeableTabContainer with basic structure**

```swift
import SwiftUI

struct SwipeableTabContainer<Tab0: View, Tab1: View, Tab2: View>: View {
    @Binding var selection: Int
    let tab0: Tab0
    let tab1: Tab1
    let tab2: Tab2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let tabCount = 3

    init(selection: Binding<Int>,
         @ViewBuilder tab0: () -> Tab0,
         @ViewBuilder tab1: () -> Tab1,
         @ViewBuilder tab2: () -> Tab2) {
        self._selection = selection
        self.tab0 = tab0()
        self.tab1 = tab1()
        self.tab2 = tab2()
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            HStack(spacing: 0) {
                tab0.frame(width: width).clipped()
                    .allowsHitTesting(selection == 0)
                tab1.frame(width: width).clipped()
                    .allowsHitTesting(selection == 1)
                tab2.frame(width: width).clipped()
                    .allowsHitTesting(selection == 2)
            }
            .offset(x: -CGFloat(selection) * width + dragOffset)
        }
    }
}
```

**Notes:**
- Uses `@ViewBuilder` closures so the call site can use trailing closure syntax.
- Uses `@GestureState` for `dragOffset` (not `@State`) — this automatically resets to 0 when the gesture is cancelled or interrupted (e.g., incoming call, notification pull-down), preventing the UI from getting stuck mid-drag.
- `.allowsHitTesting` on each tab prevents taps on off-screen tab content (toolbar buttons, etc.).
- No `project.yml` update needed — `sources: - path: Roam` auto-discovers all files under `Roam/`.

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Shared/SwipeableTabContainer.swift
git commit -m "feat: add SwipeableTabContainer with static horizontal layout"
```

---

### Task 2: Add edge-detection drag gesture with finger tracking

**Files:**
- Modify: `Roam/Views/Shared/SwipeableTabContainer.swift`

Add a `DragGesture` that only activates when the touch starts within 20pt of either screen edge, and tracks the finger offset in real-time.

- [ ] **Step 1: Add edge-detection drag gesture**

Add these properties and the gesture to the `body` in `SwipeableTabContainer`:

```swift
private let edgeZoneWidth: CGFloat = 20

private func isInEdgeZone(startX: CGFloat, screenWidth: CGFloat) -> Bool {
    startX <= edgeZoneWidth || startX >= screenWidth - edgeZoneWidth
}
```

Update the `body` to add a `.highPriorityGesture` on the `HStack`:

```swift
.highPriorityGesture(
    DragGesture(minimumDistance: 10)
        .updating($dragOffset) { value, state, _ in
            guard isInEdgeZone(startX: value.startLocation.x, screenWidth: width) else {
                return
            }
            isDragging = true
            state = value.translation.width
        }
        .onEnded { value in
            guard isDragging else { return }
            isDragging = false
            // dragOffset resets automatically via @GestureState
        }
)
```

**Note:** Using `.updating($dragOffset)` instead of `.onChanged` because `@GestureState` requires the `updating` modifier. The `state` parameter is the writable reference to `dragOffset`. When the gesture is interrupted (cancelled without `onEnded`), `@GestureState` automatically resets `dragOffset` to 0.

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Shared/SwipeableTabContainer.swift
git commit -m "feat: add edge-detection drag gesture with finger tracking"
```

---

### Task 3: Add commit/snap-back logic on gesture end

**Files:**
- Modify: `Roam/Views/Shared/SwipeableTabContainer.swift`

When the drag ends, commit the tab switch if the drag exceeds 40% of screen width or velocity exceeds 500pt/s. Otherwise, spring back.

- [ ] **Step 1: Add commit/snap-back logic**

Replace the `.onEnded` handler with:

```swift
.onEnded { value in
    guard isDragging else { return }
    isDragging = false

    let translation = value.translation.width
    let velocity = value.velocity.width
    let commitThreshold = width * 0.4
    let velocityThreshold: CGFloat = 500

    var newSelection = selection

    if translation < -commitThreshold || velocity < -velocityThreshold {
        // Swiping left → next tab
        if selection < tabCount - 1 {
            newSelection = selection + 1
        }
    } else if translation > commitThreshold || velocity > velocityThreshold {
        // Swiping right → previous tab
        if selection > 0 {
            newSelection = selection - 1
        }
    }

    // @GestureState resets dragOffset to 0 automatically when gesture ends
    withAnimation(.spring(duration: 0.3)) {
        selection = newSelection
    }
}
```

Also wrap the `dragOffset` assignment in `onChanged` so it doesn't animate during tracking — ensure the offset follows the finger directly (no animation wrapper on the `onChanged`).

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Shared/SwipeableTabContainer.swift
git commit -m "feat: add commit/snap-back logic for tab switch gesture"
```

---

### Task 4: Add rubber-band dampening at boundaries

**Files:**
- Modify: `Roam/Views/Shared/SwipeableTabContainer.swift`

When on the first tab swiping right, or the last tab swiping left, apply a dampening factor so the content follows the finger with resistance then springs back.

- [ ] **Step 1: Add rubber-band logic to onChanged**

In the `onChanged` handler, after setting `isDragging = true`, compute the effective offset:

Update the `.updating($dragOffset)` handler to apply dampening:

```swift
.updating($dragOffset) { value, state, _ in
    guard isInEdgeZone(startX: value.startLocation.x, screenWidth: width) else {
        return
    }
    isDragging = true

    let translation = value.translation.width
    let isAtLeadingEdge = selection == 0 && translation > 0
    let isAtTrailingEdge = selection == tabCount - 1 && translation < 0

    if isAtLeadingEdge || isAtTrailingEdge {
        // Rubber-band: dampened follow
        state = translation * 0.3
    } else {
        state = translation
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Shared/SwipeableTabContainer.swift
git commit -m "feat: add rubber-band dampening at tab boundaries"
```

---

### Task 5: Add tap-triggered directional slide animation

**Files:**
- Modify: `Roam/Views/Shared/SwipeableTabContainer.swift`

When the tab bar selection changes (via tap), animate a directional slide using `.onChange(of: selection)`.

- [ ] **Step 1: Add onChange handler for tap-triggered animation**

Add a `@State private var animatedSelection: Int` initialized to match `selection`. Use `animatedSelection` for the offset calculation instead of `selection`. Detect direction and animate:

```swift
// In body, use animatedSelection for positioning:
.offset(x: -CGFloat(animatedSelection) * width + dragOffset)

// Add onChange:
.onChange(of: selection) { oldValue, newValue in
    guard !isDragging else {
        // During drag, update immediately (drag end handles animation)
        animatedSelection = newValue
        return
    }
    withAnimation(.spring(duration: 0.3)) {
        animatedSelection = newValue
    }
}

// In onEnded, update animatedSelection inside the withAnimation block:
// @GestureState resets dragOffset to 0 automatically when gesture ends
withAnimation(.spring(duration: 0.3)) {
    selection = newSelection
    animatedSelection = newSelection
}
```

Initialize `animatedSelection` in the init to match `selection`, avoiding a flash of wrong content on first render:

```swift
// In the init, add:
self._animatedSelection = State(initialValue: selection.wrappedValue)
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Shared/SwipeableTabContainer.swift
git commit -m "feat: add tap-triggered directional slide animation"
```

---

### Task 6: Add Reduce Motion support

**Files:**
- Modify: `Roam/Views/Shared/SwipeableTabContainer.swift`

When Reduce Motion is enabled, use instant crossfade instead of sliding for all transitions.

- [ ] **Step 1: Add Reduce Motion fallback**

In the `onChange(of: selection)` handler, check `reduceMotion`:

```swift
.onChange(of: selection) { oldValue, newValue in
    guard !isDragging else {
        animatedSelection = newValue
        return
    }
    if reduceMotion {
        withAnimation(.easeInOut(duration: 0.15)) {
            animatedSelection = newValue
        }
    } else {
        withAnimation(.spring(duration: 0.3)) {
            animatedSelection = newValue
        }
    }
}
```

In the `onEnded` handler, use the same conditional:

```swift
// @GestureState resets dragOffset to 0 automatically when gesture ends
let animation: Animation = reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.3)
withAnimation(animation) {
    selection = newSelection
    animatedSelection = newSelection
}
```

When `reduceMotion` is true, the drag gesture still works but skips finger tracking. Update the `.updating` handler to conditionally skip offset changes:

```swift
.updating($dragOffset) { value, state, _ in
    guard isInEdgeZone(startX: value.startLocation.x, screenWidth: width) else {
        return
    }
    isDragging = true
    guard !reduceMotion else { return } // No finger tracking with Reduce Motion

    let translation = value.translation.width
    let isAtLeadingEdge = selection == 0 && translation > 0
    let isAtTrailingEdge = selection == tabCount - 1 && translation < 0
    if isAtLeadingEdge || isAtTrailingEdge {
        state = translation * 0.3
    } else {
        state = translation
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Shared/SwipeableTabContainer.swift
git commit -m "feat: add Reduce Motion crossfade fallback for tab transitions"
```

---

### Task 7: Integrate SwipeableTabContainer into ContentView

**Files:**
- Modify: `Roam/ContentView.swift`

Replace the inline tab content with `Color.clear` placeholders and add the `SwipeableTabContainer` as an overlay.

- [ ] **Step 1: Add selectedTab state and refactor TabView**

Replace the existing `TabView` block (lines 41-70 of `ContentView.swift`) with:

```swift
TabView(selection: $selectedTab) {
    Tab("Dashboard", systemImage: "chart.bar.fill", value: 0) {
        Color.clear
    }
    Tab("Timeline", systemImage: "calendar", value: 1) {
        Color.clear
    }
    Tab("Insights", systemImage: "lightbulb.fill", value: 2) {
        Color.clear
    }
}
.tint(RoamTheme.accent)
.overlay {
    SwipeableTabContainer(selection: $selectedTab, tab0: {
        NavigationStack {
            DashboardView()
                .safeAreaInset(edge: .top) {
                    if !unresolvedLogs.isEmpty {
                        UnresolvedBanner(unresolvedCount: unresolvedLogs.count) {
                            unresolvedToResolve = unresolvedLogs.first
                        }
                        .padding(.horizontal)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
    }, tab1: {
        TimelineView()
    }, tab2: {
        InsightsView()
    })
}
```

Add the state variable:

```swift
@State private var selectedTab: Int = 0
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run in simulator and verify:**
- Tab bar shows three tabs and is tappable
- Tapping a tab slides content directionally
- Edge swipe from left/right edges switches tabs with finger tracking
- Mid-content swipes in Timeline still navigate months/years
- Rubber-band effect at Dashboard (swipe right) and Insights (swipe left)
- Settings gear button opens settings sheet
- Unresolved banner appears on Dashboard when applicable

- [ ] **Step 4: Commit**

```bash
git add Roam/Views/Shared/SwipeableTabContainer.swift Roam/ContentView.swift
git commit -m "feat: integrate SwipeableTabContainer into ContentView"
```

---

### Task 8: Final polish and build verification

**Files:**
- Possibly modify: `Roam/Views/Shared/SwipeableTabContainer.swift`

- [ ] **Step 1: Full build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run all tests to check for regressions**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: All tests pass

- [ ] **Step 3: Manual QA checklist**

Verify in simulator:
- [ ] Edge swipe left/right between all three tabs
- [ ] Mid-content swipes in Timeline month/year views still work
- [ ] Tap tab bar items → directional slide
- [ ] Rapid tab switching (both swipe and tap)
- [ ] Rubber-band at Dashboard (left edge) and Insights (right edge)
- [ ] Back-swipe gesture mid-transition — should not break
- [ ] Enable Reduce Motion → verify crossfade fallback
- [ ] VoiceOver active → verify tab switching still works
- [ ] Sheets (Settings, DayDetail, CitySearch, UnresolvedResolution) present normally
- [ ] Edge gesture does not leak through presented sheets
- [ ] Interruption during gesture (notification pull-down) → should snap to nearest tab
- [ ] No regressions on scroll state or view layout within each tab

- [ ] **Step 4: Final commit if any polish changes were made**

```bash
git add -A
git commit -m "fix: polish edge-swipe tab transitions"
```
