# UX Polish & Map View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add haptic feedback, empty states, spatial zoom transitions, and a Map tab to elevate Roam's user experience.

**Architecture:** Four independent features layered onto the existing SwiftUI + SwiftData app. HapticService is a shared utility. Empty states are per-view conditionals. Spatial zoom uses scale+fade animation in TimelineView (simplified from spec's GeometryReader approach — the `ZStack` with `.transition(.scale.combined(with: .opacity))` achieves the visual effect without needing preference keys on `YearDotGridView`). Map tab is a new NavigationStack-wrapped view with MapKit annotations and a detail sheet.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, MapKit, UIKit (UIImpactFeedbackGenerator, UISelectionFeedbackGenerator)

**Spec:** `docs/superpowers/specs/2026-03-21-ux-polish-and-map-view-design.md`

---

### Task 1: HapticService Utility

**Files:**
- Create: `Roam/Utilities/HapticService.swift`

- [ ] **Step 1: Create HapticService**

```swift
import UIKit

enum HapticService {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Utilities/HapticService.swift
git commit -m "feat: add HapticService utility for tactile feedback"
```

---

### Task 2: Add Haptics to Timeline Navigation

**Files:**
- Modify: `Roam/Views/Timeline/TimelineView.swift`

Add `HapticService.selection()` calls when month/year changes — in all four navigation functions (`previousMonth`, `nextMonth`, `previousYear`, `nextYear`) so both swipe gestures and chevron buttons trigger haptics. Add `HapticService.medium()` when pinch threshold crosses for mode change.

- [ ] **Step 1: Add haptics to month navigation functions**

In `TimelineView.swift`, update the four navigation functions:

```swift
private func previousMonth() {
    HapticService.selection()
    if displayedMonth == 1 {
        displayedMonth = 12
        displayedYear -= 1
    } else {
        displayedMonth -= 1
    }
}

private func nextMonth() {
    HapticService.selection()
    if displayedMonth == 12 {
        displayedMonth = 1
        displayedYear += 1
    } else {
        displayedMonth += 1
    }
}

private func previousYear() {
    HapticService.selection()
    displayedYear -= 1
}

private func nextYear() {
    HapticService.selection()
    displayedYear += 1
}
```

- [ ] **Step 2: Add haptics to pinch-to-zoom transitions**

In `monthContent`, inside the `MagnifyGesture.onEnded`, add `HapticService.medium()` before `mode = .year`:

```swift
.gesture(
    MagnifyGesture()
        .onEnded { value in
            if value.magnification < 0.7 {
                HapticService.medium()
                withAnimation {
                    mode = .year
                }
            }
        }
)
```

In `yearContent`, inside the `MagnifyGesture.onEnded`, add `HapticService.medium()` before `mode = .month`:

```swift
.gesture(
    MagnifyGesture()
        .onEnded { value in
            if value.magnification > 1.3 {
                let currentMonth = Calendar.current.component(.month, from: Date())
                let currentYear = Calendar.current.component(.year, from: Date())
                displayedMonth = (displayedYear == currentYear) ? currentMonth : 1
                HapticService.medium()
                withAnimation {
                    mode = .month
                }
            }
        }
)
```

Also in `yearContent`, the `onMonthTapped` closure should add a haptic:

```swift
) { month in
    displayedMonth = month
    HapticService.medium()
    withAnimation {
        mode = .month
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Roam/Views/Timeline/TimelineView.swift
git commit -m "feat: add haptic feedback to Timeline navigation and zoom"
```

---

### Task 3: Add Haptics to Day Cell Tap and City Selection

**Files:**
- Modify: `Roam/Views/Timeline/CalendarGridView.swift`
- Modify: `Roam/Views/Settings/CitySearchView.swift`
- Modify: `Roam/Views/Shared/UnresolvedResolutionView.swift`

- [ ] **Step 1: Add haptic to day cell tap in CalendarGridView**

In `CalendarGridView.swift`, inside the `.onTapGesture` block (line 74), add `HapticService.selection()`:

```swift
.onTapGesture {
    if !isFuture {
        HapticService.selection()
        onDayTapped(log, dayDate)
    }
}
```

- [ ] **Step 2: Add haptic to city selection in CitySearchView**

In `CitySearchView.swift`, add `HapticService.medium()` in two places:

1. In the recent city button action (before `dismiss()`):
```swift
Button {
    HapticService.medium()
    selectedCity = entry.city
    selectedState = entry.state
    selectedCountry = entry.country
    dismiss()
}
```

2. At the end of `selectCompletion(_:)` (before `dismiss()`):
```swift
selectedCountry = reps.region?.identifier
HapticService.medium()
dismiss()
```

- [ ] **Step 3: Add haptic to unresolved resolution confirm**

In `UnresolvedResolutionView.swift`, add `HapticService.medium()` at the start of the "Confirm" button action (line 25):

```swift
Button("Confirm") {
    HapticService.medium()
    log.city = selectedCity
    // ... rest of existing code unchanged
```

- [ ] **Step 4: Build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Roam/Views/Timeline/CalendarGridView.swift Roam/Views/Settings/CitySearchView.swift Roam/Views/Shared/UnresolvedResolutionView.swift
git commit -m "feat: add haptic feedback to day cell tap and city selection"
```

---

### Task 4: Empty States

**Files:**
- Modify: `Roam/Views/Dashboard/DashboardView.swift`
- Modify: `Roam/Views/Timeline/TimelineView.swift`
- Modify: `Roam/Views/Insights/InsightsView.swift`

- [ ] **Step 1: Add empty state to DashboardView**

In `DashboardView.swift`, wrap the existing `VStack` content in a conditional. Check if `allLogs` is empty:

```swift
var body: some View {
    let analytics = AnalyticsService(context: context)
    ScrollView {
        if allLogs.isEmpty {
            VStack {
                Spacer(minLength: 120)
                Text("Your first night will appear here")
                    .font(.subheadline)
                    .foregroundStyle(RoamTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                // ... existing content unchanged ...
            }
            .padding()
        }
    }
    .navigationTitle("Roam")
    // ... rest unchanged (toolbar, grainBackground)
```

- [ ] **Step 2: Add empty state to Timeline**

In `TimelineView.swift`, add a check for whether the current month/year has any logs. Add a computed property:

```swift
private var currentViewHasLogs: Bool {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return allLogs.contains { log in
        cal.component(.year, from: log.date) == displayedYear &&
        (mode == .year || cal.component(.month, from: log.date) == displayedMonth)
    }
}
```

Then in `body`, after the `switch mode` / `ZStack` block and before the `legend`, add:

```swift
if !currentViewHasLogs {
    Text("No nights logged")
        .font(.subheadline)
        .foregroundStyle(RoamTheme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
}
```

The calendar grid still renders (showing empty cells), and the text appears below it as a subtle hint.

- [ ] **Step 3: Add empty state to InsightsView**

In `InsightsView.swift`, show the YearPicker always but conditionally show the rest. Replace the body:

```swift
var body: some View {
    let analytics = AnalyticsService(context: context)
    let years = analytics.availableYears()
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            YearPicker(years: years.isEmpty ? [currentYear] : years, selectedYear: $selectedYear)

            if years.isEmpty {
                Text("Insights will appear once you have a few nights logged")
                    .font(.subheadline)
                    .foregroundStyle(RoamTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
            } else {
                MonthlyBreakdownChart(
                    breakdown: analytics.monthlyBreakdown(year: selectedYear),
                    cityColors: cityColors
                )

                let cityDays = analytics.daysPerCity(year: selectedYear)
                let topCity = cityDays.max(by: { $0.value < $1.value })
                let topCityName = topCity?.key.split(separator: "|").first.map(String.init) ?? ""
                let homeCityKey = settings.first?.homeCityKey ?? ""

                HighlightsGrid(
                    mostVisited: (city: topCityName, nights: topCity?.value ?? 0),
                    longestStreak: analytics.longestStreak(year: selectedYear),
                    newCityCount: analytics.newCities(year: selectedYear).count,
                    homeAwayRatio: analytics.homeAwayRatio(year: selectedYear, homeCityKey: homeCityKey)
                )

                let yoyData = years.suffix(2).map { year in
                    let awayNights = analytics.confirmedLogs(year: year).filter {
                        CityDisplayFormatter.cityKey(city: $0.city, state: $0.state, country: $0.country) != homeCityKey
                    }.count
                    return (
                        year: year,
                        totalCities: analytics.uniqueCitiesCount(year: year),
                        nightsAway: awayNights,
                        avgTrip: analytics.averageTripLength(year: year, homeCityKey: homeCityKey)
                    )
                }

                if yoyData.count >= 2 {
                    YearOverYearView(years: yoyData)
                }
            }
        }
        .padding()
    }
    .navigationTitle("Insights")
    .navigationBarTitleDisplayMode(.large)
    .grainBackground()
}
```

- [ ] **Step 4: Build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Roam/Views/Dashboard/DashboardView.swift Roam/Views/Timeline/TimelineView.swift Roam/Views/Insights/InsightsView.swift
git commit -m "feat: add empty states for Dashboard, Timeline, and Insights"
```

---

### Task 5: Spatial Zoom Transition in Timeline

**Files:**
- Modify: `Roam/Views/Timeline/TimelineView.swift`

This replaces the hard mode swap with a scale+fade animation. The approach: wrap both views in a `ZStack` and use SwiftUI's `.transition` modifier with scale and opacity. When `mode` changes inside `withAnimation`, SwiftUI cross-fades with the specified transitions.

**Note:** The spec mentioned using `GeometryReader` + preference keys on `YearDotGridView`. This plan uses a simpler `ZStack` + `.transition(.scale.combined(with: .opacity))` approach which achieves the same visual effect (zoom in/out feel) without modifying `YearDotGridView` or `MiniMonthGridView`.

- [ ] **Step 1: Add reduced motion environment and animation helper**

Add at the top of `TimelineView` (near the other `@State` properties):

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Add a computed property in the body of `TimelineView`:

```swift
private var zoomAnimation: Animation {
    reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.35)
}
```

- [ ] **Step 2: Replace switch with ZStack transition in body**

Replace the `switch mode` block in `body` with a `ZStack` that renders both views conditionally. The full `body` becomes:

```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                if mode == .month {
                    monthContent
                        .transition(.asymmetric(
                            insertion: .scale(scale: 1.0).combined(with: .opacity),
                            removal: .scale(scale: 0.3).combined(with: .opacity)
                        ))
                }
                if mode == .year {
                    yearContent
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.3).combined(with: .opacity),
                            removal: .scale(scale: 1.0).combined(with: .opacity)
                        ))
                }
            }

            if !currentViewHasLogs {
                Text("No nights logged")
                    .font(.subheadline)
                    .foregroundStyle(RoamTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }

            legend
        }
        .padding()
    }
    .navigationTitle("Timeline")
    .navigationBarTitleDisplayMode(.large)
    .grainBackground()
    .sheet(item: $selectedLog) { log in
        DayDetailSheet(log: log)
    }
}
```

Transition logic:
- **Month → Year (pinch out):** month removal shrinks to 0.3x + fades out; year insertion starts at 0.3x + fades in (growing from small)
- **Year → Month (pinch in):** year removal stays at 1.0x + fades out; month insertion at 1.0x + fades in

- [ ] **Step 3: Update all mode-change animations to use zoomAnimation**

In `monthContent`, update the magnify gesture to use `zoomAnimation`:

```swift
.gesture(
    MagnifyGesture()
        .onEnded { value in
            if value.magnification < 0.7 {
                HapticService.medium()
                withAnimation(zoomAnimation) {
                    mode = .year
                }
            }
        }
)
```

In `yearContent`, update the magnify gesture:

```swift
.gesture(
    MagnifyGesture()
        .onEnded { value in
            if value.magnification > 1.3 {
                let currentMonth = Calendar.current.component(.month, from: Date())
                let currentYr = Calendar.current.component(.year, from: Date())
                displayedMonth = (displayedYear == currentYr) ? currentMonth : 1
                HapticService.medium()
                withAnimation(zoomAnimation) {
                    mode = .month
                }
            }
        }
)
```

Update the `onMonthTapped` closure in `yearContent`:

```swift
) { month in
    displayedMonth = month
    HapticService.medium()
    withAnimation(zoomAnimation) {
        mode = .month
    }
}
```

- [ ] **Step 4: Build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Roam/Views/Timeline/TimelineView.swift
git commit -m "feat: spatial zoom transition between month and year views"
```

---

### Task 6: Map View — Data Model and Pin Annotation

**Files:**
- Create: `Roam/Views/Map/CityPinAnnotation.swift`

- [ ] **Step 1: Create the Map directory**

Run: `mkdir -p Roam/Views/Map`

- [ ] **Step 2: Create CityPinAnnotation**

```swift
import SwiftUI

struct CityMapItem: Identifiable {
    let id: String  // cityKey
    let displayName: String
    let latitude: Double
    let longitude: Double
    let totalNights: Int
    let firstVisit: Date
    let lastVisit: Date
    let color: Color
}

struct CityPinAnnotation: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.4), radius: 2, y: 1)
    }
}
```

- [ ] **Step 3: Regenerate Xcode project (new directory)**

Run: `xcodegen generate`

- [ ] **Step 4: Build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Roam/Views/Map/CityPinAnnotation.swift Roam.xcodeproj/project.pbxproj
git commit -m "feat: add CityMapItem model and CityPinAnnotation view"
```

---

### Task 7: Map View — Detail Sheet

**Files:**
- Create: `Roam/Views/Map/CityDetailSheet.swift`

- [ ] **Step 1: Create CityDetailSheet**

```swift
import SwiftUI

struct CityDetailSheet: View {
    let item: CityMapItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.color)
                    .frame(width: 10, height: 10)
                Text(item.displayName)
                    .font(.headline)
                    .foregroundStyle(RoamTheme.textPrimary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nights")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textSecondary)
                    Text("\(item.totalNights)")
                        .font(.title2)
                        .fontWeight(.regular)
                        .foregroundStyle(RoamTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("First visit")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textSecondary)
                    Text(item.firstVisit.formatted(.dateTime.month(.wide).day().year()))
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last visit")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textSecondary)
                    Text(item.lastVisit.formatted(.dateTime.month(.wide).day().year()))
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoamTheme.background)
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Map/CityDetailSheet.swift
git commit -m "feat: add CityDetailSheet for map pin details"
```

---

### Task 8: Map View — Main MapView

**Files:**
- Create: `Roam/Views/Map/MapView.swift`

- [ ] **Step 1: Create MapView**

```swift
import SwiftUI
import SwiftData
@preconcurrency import MapKit

struct MapView: View {
    @Query(sort: \NightLog.date) private var allLogs: [NightLog]
    @Query private var cityColors: [CityColor]

    @State private var selectedItem: CityMapItem?
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var cityItems: [CityMapItem] {
        let confirmedRaw = LogStatus.confirmedRaw
        let manualRaw = LogStatus.manualRaw

        // Group logs by city key, only confirmed/manual with coordinates
        var groups: [String: (logs: [NightLog], lat: Double, lon: Double, count: Int)] = [:]

        for log in allLogs {
            guard log.statusRaw == confirmedRaw || log.statusRaw == manualRaw,
                  let city = log.city, !city.isEmpty,
                  let lat = log.latitude, let lon = log.longitude else { continue }

            let key = CityDisplayFormatter.cityKey(city: city, state: log.state, country: log.country)
            if var group = groups[key] {
                group.logs.append(log)
                group.lat += lat
                group.lon += lon
                group.count += 1
                groups[key] = group
            } else {
                groups[key] = (logs: [log], lat: lat, lon: lon, count: 1)
            }
        }

        return groups.compactMap { key, group in
            let sorted = group.logs.sorted { $0.date < $1.date }
            guard let first = sorted.first, let last = sorted.last else { return nil }

            let parts = key.split(separator: "|")
            let city = parts.count > 0 ? String(parts[0]) : ""
            let state = parts.count > 1 ? String(parts[1]) : nil
            let country = parts.count > 2 ? String(parts[2]) : nil
            let displayName = CityDisplayFormatter.format(city: city, state: state, country: country)

            let colorIndex = cityColors.first(where: { $0.cityKey == key })?.colorIndex ?? 0
            let color = ColorPalette.color(for: colorIndex)

            return CityMapItem(
                id: key,
                displayName: displayName,
                latitude: group.lat / Double(group.count),
                longitude: group.lon / Double(group.count),
                totalNights: sorted.count,
                firstVisit: first.date,
                lastVisit: last.date,
                color: color
            )
        }
    }

    private var defaultRegion: MKCoordinateRegion {
        // Center on device locale's region, fallback to world view
        if let regionCode = Locale.current.region?.identifier,
           let timezone = TimeZone.current.identifier.split(separator: "/").first {
            // Rough continent centers based on timezone prefix
            switch String(timezone) {
            case "America": return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.6), span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50))
            case "Europe": return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 50.1, longitude: 9.7), span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30))
            case "Asia": return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0), span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50))
            case "Australia": return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -25.3, longitude: 133.8), span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30))
            case "Africa": return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 1.6, longitude: 17.3), span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50))
            default: break
            }
            _ = regionCode // suppress unused warning
        }
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 20, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120))
    }

    var body: some View {
        ZStack {
            if cityItems.isEmpty {
                Map(position: $cameraPosition) {}
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .onAppear {
                        cameraPosition = .region(defaultRegion)
                    }

                Text("Your cities will appear here")
                    .font(.subheadline)
                    .foregroundStyle(RoamTheme.textSecondary)
            } else {
                Map(position: $cameraPosition) {
                    ForEach(cityItems) { item in
                        Annotation(item.displayName, coordinate: CLLocationCoordinate2D(
                            latitude: item.latitude,
                            longitude: item.longitude
                        )) {
                            CityPinAnnotation(color: item.color)
                                .onTapGesture {
                                    HapticService.selection()
                                    selectedItem = item
                                }
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedItem) { item in
            CityDetailSheet(item: item)
                .presentationDetents([.height(200)])
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Map/MapView.swift
git commit -m "feat: add MapView with city pins and detail sheet"
```

---

### Task 9: Wire Map Tab into ContentView

**Files:**
- Modify: `Roam/ContentView.swift`

- [ ] **Step 1: Add map case to AppTab enum**

Update `AppTab` in `ContentView.swift`:

```swift
enum AppTab: Int, CaseIterable {
    case dashboard = 0
    case timeline = 1
    case map = 2
    case insights = 3
}
```

Note: `selectedTab` uses `@State` (not persisted via `@SceneStorage`), so the rawValue renumbering is safe.

- [ ] **Step 2: Add Map tab to TabView**

Insert the Map tab between Timeline and Insights:

```swift
Tab("Timeline", systemImage: "calendar", value: .timeline) {
    NavigationStack {
        TimelineView()
    }
}
Tab("Map", systemImage: "map.fill", value: .map) {
    NavigationStack {
        MapView()
    }
}
Tab("Insights", systemImage: "lightbulb.fill", value: .insights) {
    NavigationStack {
        InsightsView()
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Roam/ContentView.swift
git commit -m "feat: add Map as fourth tab in tab bar"
```

---

### Task 10: Regenerate Project and Final Build

- [ ] **Step 1: Regenerate Xcode project**

Run: `xcodegen generate`

- [ ] **Step 2: Full build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit if project file changed**

```bash
git add Roam.xcodeproj/project.pbxproj
git commit -m "chore: regenerate Xcode project"
```

---

## Visual Verification Checklist

After all tasks are complete, verify in the simulator:

- [ ] Haptics fire on: month/year swipe, chevron tap, day cell tap, city selection, unresolved confirm, pinch zoom
- [ ] Dashboard shows empty state text when no data
- [ ] Timeline shows "No nights logged" text when current month/year has no data
- [ ] Insights shows empty state text when no data, YearPicker still visible
- [ ] Timeline month↔year transition uses spatial zoom animation (scale+fade)
- [ ] Reduced Motion setting falls back to simple cross-fade
- [ ] Map tab appears between Timeline and Insights
- [ ] Map shows colored pins for cities with coordinates
- [ ] Tapping a pin opens detail sheet with city name, nights, dates
- [ ] Map shows empty state when no data, centered on locale region
- [ ] All existing functionality still works (sheets, toolbar, navigation)
