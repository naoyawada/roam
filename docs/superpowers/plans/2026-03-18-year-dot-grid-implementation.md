# Year Dot Grid Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a year view to the Timeline tab showing a 12-month dot-grid calendar, navigable via pinch and swipe gestures.

**Architecture:** New `MiniMonthGridView` renders a single mini-month as a 7-column grid of colored squares. `YearDotGridView` arranges 12 of these in a 4×3 layout. `TimelineView` gains a `mode` state (`.month`/`.year`) toggled by `MagnifyGesture` (pinch) and swipe via `DragGesture`. The Insights `YearPicker` drops its "All Time" option.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, MagnifyGesture, DragGesture

**Spec:** `docs/superpowers/specs/2026-03-18-year-dot-grid-design.md`

---

### Task 1: Create MiniMonthGridView

**Files:**
- Create: `Roam/Views/Timeline/MiniMonthGridView.swift`

This is the core reusable unit — a single mini-month showing the month label and a 7-column grid of small colored squares.

- [ ] **Step 1: Create MiniMonthGridView.swift**

```swift
import SwiftUI

struct MiniMonthGridView: View {
    let year: Int
    let month: Int
    let logs: [NightLog]
    let cityColors: [CityColor]

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private var firstDayOfMonth: Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1, hour: 12))!
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: firstDayOfMonth)!.count
    }

    private var firstWeekdayOffset: Int {
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var today: DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.dateComponents([.year, .month, .day], from: BackfillService.calendarTodayNoonUTC())
    }

    private func logFor(day: Int) -> NightLog? {
        let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return logs.first { calendar.isDate($0.date, inSameDayAs: targetDate) }
    }

    private func colorFor(log: NightLog?) -> Color? {
        guard let log, log.status != .unresolved else { return nil }
        let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
        guard let cityColor = cityColors.first(where: { $0.cityKey == key }) else { return nil }
        return ColorPalette.color(for: cityColor.colorIndex)
    }

    var body: some View {
        let monthName = calendar.shortMonthSymbols[month - 1]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 1.5), count: 7)

        VStack(alignment: .leading, spacing: 3) {
            Text(monthName)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 1.5) {
                ForEach((-firstWeekdayOffset)..<0, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    let log = logFor(day: day)
                    let isFuture = (year > today.year! || (year == today.year! && month > today.month!) ||
                                   (year == today.year! && month == today.month! && day > today.day!))

                    if isFuture {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RoamTheme.surfaceSubtle)
                            .opacity(0.5)
                            .aspectRatio(1, contentMode: .fit)
                    } else if log?.status == .unresolved {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RoamTheme.unresolvedFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(RoamTheme.unresolvedBorder, style: StrokeStyle(lineWidth: 0.5, dash: [2]))
                            )
                            .aspectRatio(1, contentMode: .fit)
                    } else if let color = colorFor(log: log) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .aspectRatio(1, contentMode: .fit)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodegen generate
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Timeline/MiniMonthGridView.swift
git commit -m "feat: add MiniMonthGridView for year dot-grid (#9)"
```

---

### Task 2: Create YearDotGridView

**Files:**
- Create: `Roam/Views/Timeline/YearDotGridView.swift`

The 4×3 container that lays out 12 `MiniMonthGridView`s and reports which month the user taps.

- [ ] **Step 1: Create YearDotGridView.swift**

```swift
import SwiftUI

struct YearDotGridView: View {
    let year: Int
    let logs: [NightLog]
    let cityColors: [CityColor]
    let onMonthTapped: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(1...12, id: \.self) { month in
                MiniMonthGridView(
                    year: year,
                    month: month,
                    logs: logs,
                    cityColors: cityColors
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onMonthTapped(month)
                }
            }
        }
        .padding(.horizontal)
    }
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodegen generate
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Timeline/YearDotGridView.swift
git commit -m "feat: add YearDotGridView 4×3 grid container (#9)"
```

---

### Task 3: Add year/month mode to TimelineView

**Files:**
- Modify: `Roam/Views/Timeline/TimelineView.swift`

Add `TimelineMode` enum, view state, conditional rendering, pinch gesture, swipe gesture, and year navigation.

- [ ] **Step 1: Update TimelineView.swift with full year/month mode support**

Replace the entire `TimelineView.swift` with:

```swift
import SwiftUI
import SwiftData

enum TimelineMode {
    case month
    case year
}

struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NightLog.date) private var allLogs: [NightLog]
    @Query private var cityColors: [CityColor]

    @State private var displayedMonth = Calendar.current.component(.month, from: Date())
    @State private var displayedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedLog: NightLog?
    @State private var mode: TimelineMode = .month

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let firstWeekday = Calendar.current.firstWeekday - 1
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                switch mode {
                case .month:
                    monthContent
                case .year:
                    yearContent
                }

                legend

                Spacer()
            }
            .grainBackground()
            .navigationTitle("Timeline")
            .sheet(item: $selectedLog) { log in
                DayDetailSheet(log: log)
            }
        }
    }

    // MARK: - Month View

    private var monthContent: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthYearString)
                    .font(.headline)
                Spacer()
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            // Weekday headers
            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            // Calendar grid
            CalendarGridView(
                year: displayedYear,
                month: displayedMonth,
                logs: allLogs,
                cityColors: cityColors
            ) { log, date in
                if let log {
                    selectedLog = log
                } else {
                    let newLog = NightLog(date: date, capturedAt: .now, source: .manual, status: .unresolved)
                    context.insert(newLog)
                    try? context.save()
                    selectedLog = newLog
                }
            }
            .padding(.horizontal)
            .gesture(
                MagnifyGesture()
                    .onEnded { value in
                        if value.magnification < 0.7 {
                            withAnimation {
                                mode = .year
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width < -50 {
                            withAnimation { nextMonth() }
                        } else if value.translation.width > 50 {
                            withAnimation { previousMonth() }
                        }
                    }
            )
        }
    }

    // MARK: - Year View

    private var yearContent: some View {
        VStack(spacing: 16) {
            // Year navigation
            HStack {
                Button(action: previousYear) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(String(displayedYear))
                    .font(.headline)
                Spacer()
                Button(action: nextYear) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            YearDotGridView(
                year: displayedYear,
                logs: allLogs,
                cityColors: cityColors
            ) { month in
                displayedMonth = month
                withAnimation {
                    mode = .month
                }
            }
            .gesture(
                MagnifyGesture()
                    .onEnded { value in
                        if value.magnification > 1.3 {
                            let currentMonth = Calendar.current.component(.month, from: Date())
                            let currentYear = Calendar.current.component(.year, from: Date())
                            displayedMonth = (displayedYear == currentYear) ? currentMonth : 1
                            withAnimation {
                                mode = .month
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width < -50 {
                            withAnimation { nextYear() }
                        } else if value.translation.width > 50 {
                            withAnimation { previousYear() }
                        }
                    }
            )
        }
    }

    // MARK: - Navigation

    private var monthYearString: String {
        let components = DateComponents(year: displayedYear, month: displayedMonth)
        let date = Calendar.current.date(from: components)!
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func previousMonth() {
        if displayedMonth == 1 {
            displayedMonth = 12
            displayedYear -= 1
        } else {
            displayedMonth -= 1
        }
    }

    private func nextMonth() {
        if displayedMonth == 12 {
            displayedMonth = 1
            displayedYear += 1
        } else {
            displayedMonth += 1
        }
    }

    private func previousYear() {
        displayedYear -= 1
    }

    private func nextYear() {
        displayedYear += 1
    }

    // MARK: - Legend

    private var legendLogs: [NightLog] {
        switch mode {
        case .month:
            return allLogs
        case .year:
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            return allLogs.filter {
                cal.component(.year, from: $0.date) == displayedYear
            }
        }
    }

    private var legend: some View {
        var keyCounts: [String: Int] = [:]
        for log in legendLogs where log.status != .unresolved {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            keyCounts[key, default: 0] += 1
        }
        let sorted = cityColors
            .filter { keyCounts[$0.cityKey] != nil }
            .sorted { keyCounts[$0.cityKey, default: 0] > keyCounts[$1.cityKey, default: 0] }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(sorted, id: \.cityKey) { cc in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ColorPalette.color(for: cc.colorIndex))
                            .frame(width: 10, height: 10)
                        let parts = cc.cityKey.split(separator: "|")
                        let city = parts.first.map(String.init)
                        let state = parts.count > 1 ? String(parts[1]) : nil
                        let country = parts.count > 2 ? String(parts[2]) : nil
                        Text(CityDisplayFormatter.format(city: city, state: state, country: country))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(RoamTheme.unresolvedFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(RoamTheme.unresolvedBorder, style: StrokeStyle(lineWidth: 1, dash: [2]))
                        )
                        .frame(width: 10, height: 10)
                    Text("Unresolved")
                        .font(.caption2)
                }
            }
            .padding(.horizontal)
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
xcodegen generate
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run existing tests to verify no regressions**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add Roam/Views/Timeline/TimelineView.swift
git commit -m "feat: add year/month mode with pinch and swipe gestures to Timeline (#9)"
```

---

### Task 4: Remove "All Time" from Insights YearPicker

**Files:**
- Modify: `Roam/Views/Insights/YearPicker.swift`
- Modify: `Roam/Views/Insights/InsightsView.swift`

Change `selectedYear` from `Int?` to `Int` and remove the "All Time" chip. Simplify InsightsView to remove all-time aggregation logic.

- [ ] **Step 1: Update YearPicker.swift**

Replace the entire file with:

```swift
import SwiftUI

struct YearPicker: View {
    let years: [Int]
    @Binding var selectedYear: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(years, id: \.self) { year in
                    chipButton(label: String(year), isSelected: selectedYear == year) {
                        selectedYear = year
                    }
                }
            }
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? RoamTheme.accent : RoamTheme.textSecondary)
                .background(isSelected ? RoamTheme.accentLight : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? RoamTheme.accentBorder : RoamTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Update InsightsView.swift**

Replace the entire file with:

```swift
import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Query private var cityColors: [CityColor]
    @Query private var settings: [UserSettings]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: .now)

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        let analytics = AnalyticsService(context: context)
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    let years = analytics.availableYears()

                    YearPicker(years: years.isEmpty ? [currentYear] : years, selectedYear: $selectedYear)

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
                .padding()
            }
            .grainBackground()
            .navigationTitle("Insights")
        }
    }
}
```

- [ ] **Step 3: Build and verify**

Run:
```bash
xcodegen generate
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run all tests**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Roam/Views/Insights/YearPicker.swift Roam/Views/Insights/InsightsView.swift
git commit -m "feat: remove All Time from Insights year picker (#9)"
```

---

### Task 5: Visual verification in simulator

- [ ] **Step 1: Verify month view**
- Open Timeline tab in simulator
- Confirm month view looks identical to before (no regressions)
- Swipe left/right to navigate between months

- [ ] **Step 2: Verify year view**
- Pinch out on month view to enter year view
- Confirm 12 mini-months in 4×3 grid with correct day layout
- Confirm city colors match NightLog data
- Confirm unresolved days show dashed border
- Confirm future days show subtle fill
- Swipe left/right to navigate between years
- Year nav arrows work

- [ ] **Step 3: Verify navigation**
- Tap a mini-month to zoom into that month in month view
- Pinch in on year view to return to month view
- Confirm correct month is selected after zoom

- [ ] **Step 4: Verify Insights**
- Open Insights tab
- Confirm "All Time" chip is gone
- Year picker shows available years only
- All highlights and charts still render correctly

- [ ] **Step 5: Final commit if any tweaks were needed**

```bash
git add -A
git commit -m "fix: visual tweaks from simulator testing (#9)"
```
