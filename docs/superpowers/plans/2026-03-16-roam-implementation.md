# Roam Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS app that automatically logs which city you sleep in each night, with a stats dashboard, calendar timeline, and rich analytics.

**Architecture:** SwiftUI app with three tabs (Dashboard, Timeline, Insights) + Settings. SwiftData models persist NightLog entries with iCloud sync via CloudKit. A background task fires at 2 AM to capture location, reverse geocode to a city, and save. Pure logic is unit tested; views are verified visually.

**Tech Stack:** Swift, SwiftUI, SwiftData, CloudKit, Core Location, BGTaskScheduler, Swift Charts, MapKit (MKLocalSearchCompleter), XcodeGen

---

## File Structure

```
roam/
├── project.yml                          — XcodeGen project definition
├── Roam/
│   ├── RoamApp.swift                    — App entry point, SwiftData container, background task registration
│   ├── ContentView.swift                — Root TabView (Dashboard, Timeline, Insights)
│   ├── Models/
│   │   ├── NightLog.swift               — SwiftData @Model for nightly location entries
│   │   ├── CityColor.swift              — SwiftData @Model for persistent city-to-color mapping
│   │   ├── UserSettings.swift           — SwiftData @Model for user preferences (home city, check times)
│   │   ├── CaptureSource.swift          — Enum: .automatic, .manual
│   │   └── LogStatus.swift              — Enum: .confirmed, .unresolved, .manual
│   ├── Services/
│   │   ├── DateNormalization.swift       — Pure functions for night-date normalization
│   │   ├── LocationCaptureService.swift  — Core Location wrapper + reverse geocoding + validation
│   │   ├── BackgroundTaskService.swift   — BGTaskScheduler registration and task handling
│   │   ├── BackfillService.swift         — Foreground backfill for missed nights
│   │   ├── AnalyticsService.swift        — Computed stats from SwiftData queries
│   │   └── CityDisplayFormatter.swift    — City display string formatting (US vs international)
│   ├── Views/
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift       — Dashboard tab container
│   │   │   ├── CurrentCityBanner.swift   — Current city + streak display
│   │   │   ├── YearSummaryBar.swift      — Proportional color bar of cities
│   │   │   ├── TopCitiesList.swift       — Ranked city list with counts
│   │   │   └── QuickStatsRow.swift       — 3-card stats row
│   │   ├── Timeline/
│   │   │   ├── TimelineView.swift        — Timeline tab container with month navigation
│   │   │   ├── CalendarGridView.swift    — Monthly calendar grid
│   │   │   ├── DayCell.swift             — Single day cell (color-coded)
│   │   │   └── DayDetailSheet.swift      — Tap-to-detail bottom sheet
│   │   ├── Insights/
│   │   │   ├── InsightsView.swift        — Insights tab container
│   │   │   ├── YearPicker.swift          — Chip-style year selector
│   │   │   ├── MonthlyBreakdownChart.swift — Stacked bar chart (Swift Charts)
│   │   │   ├── HighlightsGrid.swift      — 2x2 stat highlight cards
│   │   │   └── YearOverYearView.swift    — Year comparison table
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift        — Settings screen
│   │   │   ├── CitySearchView.swift      — MKLocalSearchCompleter city picker
│   │   │   └── DataExportView.swift      — CSV/JSON export
│   │   ├── Onboarding/
│   │   │   └── OnboardingView.swift      — Permission request flow
│   │   └── Shared/
│   │       ├── UnresolvedBanner.swift    — Banner for unresolved nights
│   │       └── UnresolvedResolutionView.swift — City picker for resolving missed nights
│   └── Utilities/
│       └── ColorPalette.swift            — Fixed color palette for city assignment
├── RoamTests/
│   ├── DateNormalizationTests.swift      — Date normalization unit tests
│   ├── AnalyticsServiceTests.swift       — Analytics computation tests
│   ├── CityDisplayFormatterTests.swift   — Display format tests
│   ├── LocationValidationTests.swift     — Location reading validation tests
│   └── BackfillServiceTests.swift        — Foreground backfill logic tests
├── Roam/Info.plist                       — App configuration
└── Roam/Roam.entitlements               — CloudKit + background modes
```

---

## Chunk 1: Project Setup & Data Model

### Task 1: Create Xcode Project

**Files:**
- Create: `project.yml`
- Create: `Roam/Info.plist`
- Create: `Roam/Roam.entitlements`

- [ ] **Step 1: Install XcodeGen if needed**

Run: `brew list xcodegen || brew install xcodegen`
Expected: XcodeGen available at command line

- [ ] **Step 2: Create project.yml**

```yaml
name: Roam
options:
  bundleIdPrefix: com.roamapp
  deploymentTarget:
    iOS: "26.0"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "6.0"
    TARGETED_DEVICE_FAMILY: "1"

targets:
  Roam:
    type: application
    platform: iOS
    sources:
      - path: Roam
    settings:
      base:
        INFOPLIST_FILE: Roam/Info.plist
        CODE_SIGN_ENTITLEMENTS: Roam/Roam.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.roamapp.Roam
    entitlements:
      path: Roam/Roam.entitlements
      properties:
        com.apple.developer.icloud-container-identifiers:
          - "iCloud.com.roamapp.Roam"
        com.apple.developer.icloud-services:
          - "CloudKit"

  RoamTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: RoamTests
    dependencies:
      - target: Roam
    settings:
      base:
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Roam.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Roam"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

- [ ] **Step 3: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>UIBackgroundModes</key>
    <array>
        <string>fetch</string>
        <string>location</string>
    </array>
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>Roam uses your location to automatically log which city you sleep in each night.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Roam uses your location to log which city you are in.</string>
    <key>BGTaskSchedulerPermittedIdentifiers</key>
    <array>
        <string>com.roamapp.nightCapture</string>
        <string>com.roamapp.nightCaptureRetry</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Create entitlements file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.roamapp.Roam</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 5: Create directory structure**

Run:
```bash
mkdir -p Roam/{Models,Services,Views/{Dashboard,Timeline,Insights,Settings,Onboarding,Shared},Utilities}
mkdir -p RoamTests
```

- [ ] **Step 6: Generate Xcode project**

Run: `xcodegen generate`
Expected: `Roam.xcodeproj` created successfully

- [ ] **Step 7: Commit**

```bash
git add project.yml Roam/Info.plist Roam/Roam.entitlements Roam.xcodeproj .gitignore
git commit -m "feat: initialize Xcode project with XcodeGen"
```

---

### Task 2: SwiftData Models & Enums

**Files:**
- Create: `Roam/Models/CaptureSource.swift`
- Create: `Roam/Models/LogStatus.swift`
- Create: `Roam/Models/NightLog.swift`
- Create: `Roam/Models/CityColor.swift`
- Create: `Roam/Models/UserSettings.swift`

- [ ] **Step 1: Create CaptureSource enum**

```swift
// Roam/Models/CaptureSource.swift
import Foundation

enum CaptureSource: String, Codable, Equatable {
    case automatic
    case manual

    static let automaticRaw = "automatic"
    static let manualRaw = "manual"
}
```

- [ ] **Step 2: Create LogStatus enum**

```swift
// Roam/Models/LogStatus.swift
import Foundation

enum LogStatus: String, Codable, Equatable {
    case confirmed
    case unresolved
    case manual

    static let confirmedRaw = "confirmed"
    static let unresolvedRaw = "unresolved"
    static let manualRaw = "manual"
}
```

- [ ] **Step 3: Create NightLog model**

```swift
// Roam/Models/NightLog.swift
import Foundation
import SwiftData

@Model
final class NightLog {
    var id: UUID = UUID()
    @Attribute(.unique) var date: Date
    var city: String?
    var state: String?
    var country: String?
    var latitude: Double?
    var longitude: Double?
    var capturedAt: Date
    var horizontalAccuracy: Double?
    var source: CaptureSource
    var status: LogStatus

    init(
        id: UUID = UUID(),
        date: Date,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        capturedAt: Date = .now,
        horizontalAccuracy: Double? = nil,
        source: CaptureSource = .automatic,
        status: LogStatus = .confirmed
    ) {
        self.id = id
        self.date = date
        self.city = city
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.capturedAt = capturedAt
        self.horizontalAccuracy = horizontalAccuracy
        self.source = source
        self.status = status
    }
}
```

- [ ] **Step 4: Create CityColor model**

```swift
// Roam/Models/CityColor.swift
import Foundation
import SwiftData

@Model
final class CityColor {
    @Attribute(.unique) var cityKey: String
    var colorIndex: Int

    init(cityKey: String, colorIndex: Int) {
        self.cityKey = cityKey
        self.colorIndex = colorIndex
    }
}
```

- [ ] **Step 5: Create UserSettings model**

```swift
// Roam/Models/UserSettings.swift
import Foundation
import SwiftData

@Model
final class UserSettings {
    var homeCityKey: String?
    var primaryCheckHour: Int
    var primaryCheckMinute: Int
    var retryCheckHour: Int
    var retryCheckMinute: Int
    var hasCompletedOnboarding: Bool
    var iCloudSyncEnabled: Bool
    var notificationsEnabled: Bool

    init(
        homeCityKey: String? = nil,
        primaryCheckHour: Int = 2,
        primaryCheckMinute: Int = 0,
        retryCheckHour: Int = 5,
        retryCheckMinute: Int = 0,
        hasCompletedOnboarding: Bool = false,
        iCloudSyncEnabled: Bool = true,
        notificationsEnabled: Bool = true
    ) {
        self.homeCityKey = homeCityKey
        self.primaryCheckHour = primaryCheckHour
        self.primaryCheckMinute = primaryCheckMinute
        self.retryCheckHour = retryCheckHour
        self.retryCheckMinute = retryCheckMinute
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.notificationsEnabled = notificationsEnabled
    }
}
```

- [ ] **Step 6: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add Roam/Models/
git commit -m "feat: add SwiftData models (NightLog, CityColor, UserSettings) and enums"
```

---

### Task 3: Date Normalization with Tests

**Files:**
- Create: `Roam/Services/DateNormalization.swift`
- Create: `RoamTests/DateNormalizationTests.swift`

- [ ] **Step 1: Write failing tests for date normalization**

```swift
// RoamTests/DateNormalizationTests.swift
import XCTest
@testable import Roam

final class DateNormalizationTests: XCTestCase {

    // Capture at 2 AM on March 17 → logs as March 16 (the night of the 16th)
    func testCaptureAt2AMRollsBackToYesterday() {
        let capture = date(2026, 3, 17, hour: 2, minute: 0)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 3, day: 16)
    }

    // Capture at 5:59 AM → still rolls back
    func testCaptureAt559AMRollsBack() {
        let capture = date(2026, 3, 17, hour: 5, minute: 59)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 3, day: 16)
    }

    // Capture at 6:00 AM → does NOT roll back (same calendar day)
    func testCaptureAt6AMDoesNotRollBack() {
        let capture = date(2026, 3, 17, hour: 6, minute: 0)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 3, day: 17)
    }

    // Capture at 11 PM → same calendar day
    func testCaptureAt11PMSameDay() {
        let capture = date(2026, 3, 16, hour: 23, minute: 0)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 3, day: 16)
    }

    // Midnight capture → rolls back to previous day
    func testCaptureAtMidnightRollsBack() {
        let capture = date(2026, 3, 17, hour: 0, minute: 0)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 3, day: 16)
    }

    // New Year's edge: 2 AM on Jan 1 → logs as Dec 31 of previous year
    func testNewYearsEdge() {
        let capture = date(2027, 1, 1, hour: 2, minute: 0)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 12, day: 31)
    }

    // Result is always noon UTC
    func testResultIsNoonUTC() {
        let capture = date(2026, 6, 15, hour: 14, minute: 30)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(identifier: "UTC")!,
            from: normalized
        )
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = TimeZone.current
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func assertNoonUTC(_ date: Date, year: Int, month: Int, day: Int,
                                file: StaticString = #filePath, line: UInt = #line) {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
        XCTAssertEqual(comps.year, year, "Year mismatch", file: file, line: line)
        XCTAssertEqual(comps.month, month, "Month mismatch", file: file, line: line)
        XCTAssertEqual(comps.day, day, "Day mismatch", file: file, line: line)
        XCTAssertEqual(comps.hour, 12, "Should be noon UTC", file: file, line: line)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/DateNormalizationTests -quiet 2>&1 | tail -20`
Expected: FAIL — `DateNormalization` not found

- [ ] **Step 3: Implement DateNormalization**

```swift
// Roam/Services/DateNormalization.swift
import Foundation

enum DateNormalization {

    /// Given a capture timestamp, return the normalized "night date" stored as noon UTC.
    ///
    /// Rule: if capture is before 6:00 AM local time, the night belongs to the previous calendar day.
    /// The result is noon UTC on the normalized calendar date.
    static func normalizedNightDate(from captureDate: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let hour = calendar.component(.hour, from: captureDate)
        let calendarDate: Date
        if hour < 6 {
            calendarDate = calendar.date(byAdding: .day, value: -1, to: captureDate)!
        } else {
            calendarDate = captureDate
        }

        let components = calendar.dateComponents([.year, .month, .day], from: calendarDate)

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        var noonComponents = DateComponents()
        noonComponents.year = components.year
        noonComponents.month = components.month
        noonComponents.day = components.day
        noonComponents.hour = 12
        noonComponents.minute = 0
        noonComponents.second = 0

        return utcCalendar.date(from: noonComponents)!
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/DateNormalizationTests -quiet 2>&1 | tail -20`
Expected: All 7 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/DateNormalization.swift RoamTests/DateNormalizationTests.swift
git commit -m "feat: add date normalization with unit tests"
```

---

### Task 4: City Display Formatter with Tests

**Files:**
- Create: `Roam/Services/CityDisplayFormatter.swift`
- Create: `RoamTests/CityDisplayFormatterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// RoamTests/CityDisplayFormatterTests.swift
import XCTest
@testable import Roam

final class CityDisplayFormatterTests: XCTestCase {

    func testUSCity() {
        let result = CityDisplayFormatter.format(city: "Austin", state: "TX", country: "US", deviceRegion: "US")
        XCTAssertEqual(result, "Austin, TX")
    }

    func testInternationalCity() {
        let result = CityDisplayFormatter.format(city: "Tokyo", state: "Tokyo", country: "JP", deviceRegion: "US")
        XCTAssertEqual(result, "Tokyo, Japan")
    }

    func testSameCountryAsDevice() {
        let result = CityDisplayFormatter.format(city: "Osaka", state: "Osaka", country: "JP", deviceRegion: "JP")
        XCTAssertEqual(result, "Osaka, Osaka")
    }

    func testCityOnly() {
        let result = CityDisplayFormatter.format(city: "Unknown", state: nil, country: nil, deviceRegion: "US")
        XCTAssertEqual(result, "Unknown")
    }

    func testNilCity() {
        let result = CityDisplayFormatter.format(city: nil, state: nil, country: nil, deviceRegion: "US")
        XCTAssertEqual(result, "Unknown location")
    }

    func testCityKey() {
        let key = CityDisplayFormatter.cityKey(city: "Austin", state: "TX", country: "US")
        XCTAssertEqual(key, "Austin|TX|US")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/CityDisplayFormatterTests -quiet 2>&1 | tail -20`
Expected: FAIL — `CityDisplayFormatter` not found

- [ ] **Step 3: Implement CityDisplayFormatter**

```swift
// Roam/Services/CityDisplayFormatter.swift
import Foundation

enum CityDisplayFormatter {

    /// Format a city for display based on locale conventions.
    /// - Same country as device region: "City, State"
    /// - Different country: "City, Country" (localized country name)
    static func format(city: String?, state: String?, country: String?, deviceRegion: String? = nil) -> String {
        guard let city else { return "Unknown location" }

        let region = deviceRegion ?? Locale.current.region?.identifier ?? "US"

        if let country, country != region {
            let localizedCountry = Locale.current.localizedString(forRegionCode: country) ?? country
            return "\(city), \(localizedCountry)"
        } else if let state {
            return "\(city), \(state)"
        }
        return city
    }

    /// Generate a stable key for a city, used for CityColor mapping.
    static func cityKey(city: String?, state: String?, country: String?) -> String {
        [city, state, country].compactMap { $0 }.joined(separator: "|")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/CityDisplayFormatterTests -quiet 2>&1 | tail -20`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/CityDisplayFormatter.swift RoamTests/CityDisplayFormatterTests.swift
git commit -m "feat: add city display formatter with locale-aware formatting"
```

---

### Task 5: Color Palette Utility

**Files:**
- Create: `Roam/Utilities/ColorPalette.swift`

- [ ] **Step 1: Create ColorPalette**

```swift
// Roam/Utilities/ColorPalette.swift
import SwiftUI

enum ColorPalette {
    static let colors: [Color] = [
        Color(red: 0.39, green: 0.40, blue: 0.95),  // indigo
        Color(red: 0.55, green: 0.36, blue: 0.96),  // violet
        Color(red: 0.66, green: 0.33, blue: 0.97),  // purple
        Color(red: 0.75, green: 0.52, blue: 0.99),  // light purple
        Color(red: 0.24, green: 0.64, blue: 0.96),  // blue
        Color(red: 0.20, green: 0.78, blue: 0.82),  // teal
        Color(red: 0.30, green: 0.80, blue: 0.47),  // green
        Color(red: 0.96, green: 0.68, blue: 0.20),  // amber
        Color(red: 0.95, green: 0.45, blue: 0.32),  // coral
        Color(red: 0.92, green: 0.30, blue: 0.48),  // pink
    ]

    static let unresolvedColor = Color.yellow.opacity(0.3)

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Utilities/ColorPalette.swift
git commit -m "feat: add color palette for city color assignment"
```

---

## Chunk 2: Location Capture & Background Tasks

### Task 6: Location Capture Service

**Files:**
- Create: `Roam/Services/LocationCaptureService.swift`
- Create: `RoamTests/LocationValidationTests.swift`

- [ ] **Step 1: Write failing tests for location validation**

```swift
// RoamTests/LocationValidationTests.swift
import XCTest
import CoreLocation
@testable import Roam

final class LocationValidationTests: XCTestCase {

    func testValidLocation() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74),
            altitude: 0,
            horizontalAccuracy: 50,
            verticalAccuracy: 0,
            course: 0,
            speed: 0,
            timestamp: Date()
        )
        XCTAssertTrue(LocationCaptureService.isValidReading(location))
    }

    func testInvalidAccuracy() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74),
            altitude: 0,
            horizontalAccuracy: 1500,
            verticalAccuracy: 0,
            course: 0,
            speed: 0,
            timestamp: Date()
        )
        XCTAssertFalse(LocationCaptureService.isValidReading(location))
    }

    func testTooFast() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74),
            altitude: 0,
            horizontalAccuracy: 50,
            verticalAccuracy: 0,
            course: 0,
            speed: 60.0,  // ~216 km/h, above 55.6 m/s threshold
            timestamp: Date()
        )
        XCTAssertFalse(LocationCaptureService.isValidReading(location))
    }

    func testNegativeSpeedIsValid() {
        // CLLocation reports -1 when speed is unavailable — should not reject
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74),
            altitude: 0,
            horizontalAccuracy: 50,
            verticalAccuracy: 0,
            course: 0,
            speed: -1.0,
            timestamp: Date()
        )
        XCTAssertTrue(LocationCaptureService.isValidReading(location))
    }

    func testNegativeAccuracyIsInvalid() {
        // CLLocation reports -1 when accuracy is unavailable
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74),
            altitude: 0,
            horizontalAccuracy: -1,
            verticalAccuracy: 0,
            course: 0,
            speed: 0,
            timestamp: Date()
        )
        XCTAssertFalse(LocationCaptureService.isValidReading(location))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/LocationValidationTests -quiet 2>&1 | tail -20`
Expected: FAIL — `LocationCaptureService` not found

- [ ] **Step 3: Implement LocationCaptureService**

```swift
// Roam/Services/LocationCaptureService.swift
import CoreLocation
import SwiftData

@MainActor
final class LocationCaptureService: NSObject, ObservableObject {

    static let maxAccuracy: CLLocationDistance = 1000  // meters
    static let maxSpeed: CLLocationSpeed = 55.6        // m/s (~200 km/h)

    private let locationManager = CLLocationManager()
    private var captureCompletion: ((CLLocation?) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    /// Validate whether a location reading meets quality thresholds.
    static func isValidReading(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy < maxAccuracy else {
            return false
        }
        if location.speed >= 0, location.speed > maxSpeed {
            return false
        }
        return true
    }

    /// Request a single location reading.
    func requestLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            captureCompletion = { location in
                continuation.resume(returning: location)
            }
            locationManager.requestLocation()
        }
    }

    /// Reverse geocode a location into city/state/country.
    func reverseGeocode(_ location: CLLocation) async -> CLPlacemark? {
        let geocoder = CLGeocoder()
        let placemarks = try? await geocoder.reverseGeocodeLocation(location)
        return placemarks?.first
    }

    /// Full capture flow: get location, validate, geocode, return result.
    func captureNight() async -> CaptureResult? {
        guard let location = await requestLocation() else { return nil }
        guard Self.isValidReading(location) else { return nil }
        guard let placemark = await reverseGeocode(location) else { return nil }
        guard let city = placemark.locality else { return nil }

        return CaptureResult(
            city: city,
            state: placemark.administrativeArea,
            country: placemark.isoCountryCode,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            capturedAt: location.timestamp
        )
    }

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
}

extension LocationCaptureService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            captureCompletion?(locations.last)
            captureCompletion = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            captureCompletion?(nil)
            captureCompletion = nil
        }
    }
}

struct CaptureResult {
    let city: String
    let state: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let capturedAt: Date
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/LocationValidationTests -quiet 2>&1 | tail -20`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/LocationCaptureService.swift RoamTests/LocationValidationTests.swift
git commit -m "feat: add location capture service with validation"
```

---

### Task 7: Background Task Service

**Files:**
- Create: `Roam/Services/BackgroundTaskService.swift`

- [ ] **Step 1: Implement BackgroundTaskService**

```swift
// Roam/Services/BackgroundTaskService.swift
import BackgroundTasks
import SwiftData

enum BackgroundTaskService {

    static let primaryTaskID = "com.roamapp.nightCapture"
    static let retryTaskID = "com.roamapp.nightCaptureRetry"

    /// Register background task handlers. Call once at app launch.
    @MainActor
    static func register(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: primaryTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await handleCapture(task: refreshTask, isRetry: false, modelContainer: modelContainer)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: retryTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await handleCapture(task: refreshTask, isRetry: true, modelContainer: modelContainer)
            }
        }
    }

    /// Schedule the primary capture task.
    static func schedulePrimaryCapture(hour: Int = 2, minute: Int = 0) {
        let request = BGAppRefreshTaskRequest(identifier: primaryTaskID)
        request.earliestBeginDate = nextDate(hour: hour, minute: minute)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Schedule the retry capture task.
    static func scheduleRetryCapture(hour: Int = 5, minute: Int = 0) {
        let request = BGAppRefreshTaskRequest(identifier: retryTaskID)
        request.earliestBeginDate = nextDate(hour: hour, minute: minute)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    private static func handleCapture(
        task: BGAppRefreshTask,
        isRetry: Bool,
        modelContainer: ModelContainer
    ) async {
        // Schedule next primary capture regardless of outcome
        schedulePrimaryCapture()

        let service = LocationCaptureService()
        let context = modelContainer.mainContext

        task.expirationHandler = {
            // Task ran out of time — if not retry, schedule retry
            if !isRetry {
                scheduleRetryCapture()
            }
        }

        guard let result = await service.captureNight() else {
            // Capture failed
            if isRetry {
                // Both attempts failed — save unresolved
                let nightDate = DateNormalization.normalizedNightDate(from: .now)
                let existing = try? context.fetch(
                    FetchDescriptor<NightLog>(predicate: #Predicate { $0.date == nightDate })
                ).first
                if existing == nil {
                    let log = NightLog(date: nightDate, capturedAt: .now, source: .automatic, status: .unresolved)
                    context.insert(log)
                    try? context.save()
                }
            } else {
                scheduleRetryCapture()
            }
            task.setTaskCompleted(success: true)
            return
        }

        // Save confirmed entry
        let nightDate = DateNormalization.normalizedNightDate(from: result.capturedAt)
        let existing = try? context.fetch(
            FetchDescriptor<NightLog>(predicate: #Predicate { $0.date == nightDate })
        ).first

        if let existing, existing.status != .unresolved {
            // Already have a confirmed/manual entry — don't overwrite
            task.setTaskCompleted(success: true)
            return
        }

        if let existing {
            // Update unresolved entry
            existing.city = result.city
            existing.state = result.state
            existing.country = result.country
            existing.latitude = result.latitude
            existing.longitude = result.longitude
            existing.capturedAt = result.capturedAt
            existing.horizontalAccuracy = result.horizontalAccuracy
            existing.source = .automatic
            existing.status = .confirmed
        } else {
            let log = NightLog(
                date: nightDate,
                city: result.city,
                state: result.state,
                country: result.country,
                latitude: result.latitude,
                longitude: result.longitude,
                capturedAt: result.capturedAt,
                horizontalAccuracy: result.horizontalAccuracy,
                source: .automatic,
                status: .confirmed
            )
            context.insert(log)
        }

        // Assign city color if new
        let cityKey = CityDisplayFormatter.cityKey(city: result.city, state: result.state, country: result.country)
        let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
        if !existingColors.contains(where: { $0.cityKey == cityKey }) {
            let nextIndex = (existingColors.map(\.colorIndex).max() ?? -1) + 1
            context.insert(CityColor(cityKey: cityKey, colorIndex: nextIndex))
        }

        try? context.save()
        task.setTaskCompleted(success: true)
    }

    private static func nextDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        let candidate = calendar.date(from: components)!
        return candidate > Date() ? candidate : calendar.date(byAdding: .day, value: 1, to: candidate)!
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Services/BackgroundTaskService.swift
git commit -m "feat: add background task service for nightly location capture"
```

---

### Task 8: Backfill Service with Tests

**Files:**
- Create: `Roam/Services/BackfillService.swift`
- Create: `RoamTests/BackfillServiceTests.swift`

- [ ] **Step 1: Write failing tests for backfill logic**

```swift
// RoamTests/BackfillServiceTests.swift
import XCTest
@testable import Roam

final class BackfillServiceTests: XCTestCase {

    func testMissedNightsCalculation_noGaps() {
        let today = noonUTC(2026, 3, 16)
        let existingDates = [noonUTC(2026, 3, 14), noonUTC(2026, 3, 15)]
        let missed = BackfillService.missedNights(existingDates: existingDates, today: today, maxDays: 30)
        XCTAssertTrue(missed.isEmpty)
    }

    func testMissedNightsCalculation_withGap() {
        let today = noonUTC(2026, 3, 16)
        let existingDates = [noonUTC(2026, 3, 13)]
        let missed = BackfillService.missedNights(existingDates: existingDates, today: today, maxDays: 30)
        XCTAssertEqual(missed.count, 2)
        XCTAssertEqual(missed[0], noonUTC(2026, 3, 14))
        XCTAssertEqual(missed[1], noonUTC(2026, 3, 15))
    }

    func testMissedNightsCappedAt30Days() {
        let today = noonUTC(2026, 3, 16)
        let existingDates: [Date] = []  // no entries at all
        let missed = BackfillService.missedNights(existingDates: existingDates, today: today, maxDays: 30)
        XCTAssertEqual(missed.count, 30)
    }

    func testMissedNightsExcludesToday() {
        let today = noonUTC(2026, 3, 16)
        let existingDates = [noonUTC(2026, 3, 15)]
        let missed = BackfillService.missedNights(existingDates: existingDates, today: today, maxDays: 30)
        // Today (March 16) should NOT be in missed — the night hasn't happened yet
        XCTAssertTrue(missed.isEmpty)
    }

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/BackfillServiceTests -quiet 2>&1 | tail -20`
Expected: FAIL — `BackfillService` not found

- [ ] **Step 3: Implement BackfillService**

```swift
// Roam/Services/BackfillService.swift
import Foundation
import SwiftData

enum BackfillService {

    /// Calculate which nights are missing entries.
    /// Returns normalized dates (noon UTC) for each missed night.
    /// Excludes today — the current night hasn't completed yet.
    static func missedNights(existingDates: [Date], today: Date, maxDays: Int = 30) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let existingSet = Set(existingDates.map { cal.startOfDay(for: $0) })

        var missed: [Date] = []
        for daysAgo in 1...maxDays {
            guard let candidate = cal.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let startOfCandidate = cal.startOfDay(for: candidate)

            // Rebuild as noon UTC for consistency
            var components = cal.dateComponents([.year, .month, .day], from: startOfCandidate)
            components.hour = 12
            let noonDate = cal.date(from: components)!

            if !existingSet.contains(startOfCandidate) {
                missed.append(noonDate)
            }
        }
        return missed.reversed()  // chronological order
    }

    /// Run backfill on foreground launch. Creates .unresolved entries for missed nights.
    @MainActor
    static func backfillMissedNights(context: ModelContext) {
        let today = DateNormalization.normalizedNightDate(from: .now)

        let allLogs = (try? context.fetch(FetchDescriptor<NightLog>())) ?? []
        let existingDates = allLogs.map(\.date)

        let missed = missedNights(existingDates: existingDates, today: today)

        for nightDate in missed {
            let log = NightLog(date: nightDate, capturedAt: .now, source: .automatic, status: .unresolved)
            context.insert(log)
        }

        if !missed.isEmpty {
            try? context.save()
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/BackfillServiceTests -quiet 2>&1 | tail -20`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/BackfillService.swift RoamTests/BackfillServiceTests.swift
git commit -m "feat: add backfill service for missed nights on foreground launch"
```

---

### Task 9: App Entry Point

**Files:**
- Create: `Roam/RoamApp.swift`

- [ ] **Step 1: Create RoamApp entry point**

```swift
// Roam/RoamApp.swift
import SwiftUI
import SwiftData

@main
struct RoamApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([NightLog.self, CityColor.self, UserSettings.self])
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        BackgroundTaskService.register(modelContainer: modelContainer)
        BackgroundTaskService.schedulePrimaryCapture()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
```

- [ ] **Step 2: Create placeholder ContentView**

```swift
// Roam/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                Text("Dashboard")
            }
            Tab("Timeline", systemImage: "calendar") {
                Text("Timeline")
            }
            Tab("Insights", systemImage: "lightbulb.fill") {
                Text("Insights")
            }
        }
    }
}
```

- [ ] **Step 3: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Roam/RoamApp.swift Roam/ContentView.swift
git commit -m "feat: add app entry point with SwiftData container and tab structure"
```

---

## Chunk 3: Dashboard Tab

### Task 10: Analytics Service with Tests

**Files:**
- Create: `Roam/Services/AnalyticsService.swift`
- Create: `RoamTests/AnalyticsServiceTests.swift`

- [ ] **Step 1: Write failing tests for analytics**

```swift
// RoamTests/AnalyticsServiceTests.swift
import XCTest
import SwiftData
@testable import Roam

@MainActor
final class AnalyticsServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([NightLog.self, CityColor.self, UserSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    func testDaysPerCity() {
        insertLog(date: noonUTC(2026, 1, 1), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 2), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 3), city: "New York", state: "NY", country: "US")

        let analytics = AnalyticsService(context: context)
        let result = analytics.daysPerCity(year: 2026)

        XCTAssertEqual(result["Austin|TX|US"], 2)
        XCTAssertEqual(result["New York|NY|US"], 1)
    }

    func testCurrentStreak() {
        insertLog(date: noonUTC(2026, 3, 13), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 3, 14), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 3, 15), city: "Austin", state: "TX", country: "US")

        let analytics = AnalyticsService(context: context)
        let streak = analytics.currentStreak(asOf: noonUTC(2026, 3, 16))

        XCTAssertEqual(streak.city, "Austin")
        XCTAssertEqual(streak.days, 3)
    }

    func testCurrentStreakBrokenByDifferentCity() {
        insertLog(date: noonUTC(2026, 3, 13), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 3, 14), city: "New York", state: "NY", country: "US")
        insertLog(date: noonUTC(2026, 3, 15), city: "Austin", state: "TX", country: "US")

        let analytics = AnalyticsService(context: context)
        let streak = analytics.currentStreak(asOf: noonUTC(2026, 3, 16))

        XCTAssertEqual(streak.city, "Austin")
        XCTAssertEqual(streak.days, 1)
    }

    func testLongestStreak() {
        insertLog(date: noonUTC(2026, 1, 1), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 2), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 3), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 4), city: "New York", state: "NY", country: "US")
        insertLog(date: noonUTC(2026, 1, 5), city: "New York", state: "NY", country: "US")

        let analytics = AnalyticsService(context: context)
        let streak = analytics.longestStreak(year: 2026)

        XCTAssertEqual(streak.city, "Austin")
        XCTAssertEqual(streak.days, 3)
    }

    func testUniqueCitiesCount() {
        insertLog(date: noonUTC(2026, 1, 1), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 2), city: "New York", state: "NY", country: "US")
        insertLog(date: noonUTC(2026, 1, 3), city: "Austin", state: "TX", country: "US")

        let analytics = AnalyticsService(context: context)
        XCTAssertEqual(analytics.uniqueCitiesCount(year: 2026), 2)
    }

    func testHomeAwayRatio() {
        insertLog(date: noonUTC(2026, 1, 1), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 2), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 3), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 4), city: "New York", state: "NY", country: "US")

        let analytics = AnalyticsService(context: context)
        let ratio = analytics.homeAwayRatio(year: 2026, homeCityKey: "Austin|TX|US")

        XCTAssertEqual(ratio.homePercentage, 0.75, accuracy: 0.01)
        XCTAssertEqual(ratio.awayPercentage, 0.25, accuracy: 0.01)
    }

    // MARK: - Helpers

    private func insertLog(date: Date, city: String, state: String, country: String) {
        let log = NightLog(
            date: date,
            city: city,
            state: state,
            country: country,
            capturedAt: date,
            source: .automatic,
            status: .confirmed
        )
        context.insert(log)
        try! context.save()
    }

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/AnalyticsServiceTests -quiet 2>&1 | tail -20`
Expected: FAIL — `AnalyticsService` not found

- [ ] **Step 3: Implement AnalyticsService**

```swift
// Roam/Services/AnalyticsService.swift
import Foundation
import SwiftData

struct StreakInfo {
    let city: String
    let days: Int
}

struct HomeAwayRatio {
    let homePercentage: Double
    let awayPercentage: Double
}

struct MonthlyBreakdown {
    let month: Int
    let cityDays: [(cityKey: String, city: String, days: Int)]
}

@MainActor
final class AnalyticsService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Core Queries

    func confirmedLogs(year: Int) -> [NightLog] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let startOfYear = cal.date(from: DateComponents(year: year, month: 1, day: 1, hour: 0))!
        let endOfYear = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1, hour: 0))!

        let unresolvedRaw = LogStatus.unresolvedRaw
        let descriptor = FetchDescriptor<NightLog>(
            predicate: #Predicate<NightLog> {
                $0.date >= startOfYear && $0.date < endOfYear &&
                $0.status.rawValue != unresolvedRaw
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func allConfirmedLogs() -> [NightLog] {
        let unresolvedRaw = LogStatus.unresolvedRaw
        let descriptor = FetchDescriptor<NightLog>(
            predicate: #Predicate<NightLog> { $0.status.rawValue != unresolvedRaw },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Days Per City

    func daysPerCity(year: Int) -> [String: Int] {
        let logs = confirmedLogs(year: year)
        var result: [String: Int] = [:]
        for log in logs {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            result[key, default: 0] += 1
        }
        return result
    }

    // MARK: - Streaks

    func currentStreak(asOf today: Date) -> StreakInfo {
        let logs = allConfirmedLogs().reversed()
        guard let first = logs.first else { return StreakInfo(city: "", days: 0) }

        let firstKey = CityDisplayFormatter.cityKey(city: first.city, state: first.state, country: first.country)
        var count = 1
        var previousDate = first.date

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        for log in logs.dropFirst() {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            let daysBetween = cal.dateComponents([.day], from: log.date, to: previousDate).day ?? 0

            if key == firstKey && daysBetween == 1 {
                count += 1
                previousDate = log.date
            } else {
                break
            }
        }
        return StreakInfo(city: first.city ?? "", days: count)
    }

    func longestStreak(year: Int) -> StreakInfo {
        let logs = confirmedLogs(year: year)
        guard !logs.isEmpty else { return StreakInfo(city: "", days: 0) }

        var bestCity = ""
        var bestCount = 0
        var currentCity = ""
        var currentCount = 0
        var previousDate: Date?

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        for log in logs {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)

            if let prev = previousDate {
                let daysBetween = cal.dateComponents([.day], from: prev, to: log.date).day ?? 0
                if key == currentCity && daysBetween == 1 {
                    currentCount += 1
                } else {
                    currentCity = key
                    currentCount = 1
                }
            } else {
                currentCity = key
                currentCount = 1
            }

            if currentCount > bestCount {
                bestCount = currentCount
                bestCity = log.city ?? ""
            }
            previousDate = log.date
        }
        return StreakInfo(city: bestCity, days: bestCount)
    }

    // MARK: - Unique Cities

    func uniqueCitiesCount(year: Int) -> Int {
        daysPerCity(year: year).keys.count
    }

    // MARK: - Home / Away

    func homeAwayRatio(year: Int, homeCityKey: String) -> HomeAwayRatio {
        let logs = confirmedLogs(year: year)
        guard !logs.isEmpty else { return HomeAwayRatio(homePercentage: 0, awayPercentage: 0) }

        let homeCount = logs.filter {
            CityDisplayFormatter.cityKey(city: $0.city, state: $0.state, country: $0.country) == homeCityKey
        }.count
        let total = Double(logs.count)

        return HomeAwayRatio(
            homePercentage: Double(homeCount) / total,
            awayPercentage: Double(logs.count - homeCount) / total
        )
    }

    // MARK: - Monthly Breakdown

    func monthlyBreakdown(year: Int) -> [MonthlyBreakdown] {
        let logs = confirmedLogs(year: year)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        var byMonth: [Int: [NightLog]] = [:]
        for log in logs {
            let month = cal.component(.month, from: log.date)
            byMonth[month, default: []].append(log)
        }

        return (1...12).map { month in
            let monthLogs = byMonth[month] ?? []
            var cityDays: [String: (city: String, days: Int)] = [:]
            for log in monthLogs {
                let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
                if cityDays[key] != nil {
                    cityDays[key]!.days += 1
                } else {
                    cityDays[key] = (city: log.city ?? "Unknown", days: 1)
                }
            }
            let sorted = cityDays.map { (cityKey: $0.key, city: $0.value.city, days: $0.value.days) }
                .sorted { $0.days > $1.days }
            return MonthlyBreakdown(month: month, cityDays: sorted)
        }
    }

    // MARK: - New Cities

    func newCities(year: Int) -> [String] {
        let thisYearKeys = Set(daysPerCity(year: year).keys)
        var allPriorKeys: Set<String> = []
        for priorYear in 2020..<year {
            allPriorKeys.formUnion(daysPerCity(year: priorYear).keys)
        }
        return Array(thisYearKeys.subtracting(allPriorKeys)).sorted()
    }

    // MARK: - Average Trip Length

    func averageTripLength(year: Int, homeCityKey: String) -> Double {
        let logs = confirmedLogs(year: year)
        var trips: [Int] = []
        var awayCount = 0

        for log in logs {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            if key == homeCityKey {
                if awayCount > 0 {
                    trips.append(awayCount)
                    awayCount = 0
                }
            } else {
                awayCount += 1
            }
        }
        if awayCount > 0 { trips.append(awayCount) }
        guard !trips.isEmpty else { return 0 }
        return Double(trips.reduce(0, +)) / Double(trips.count)
    }

    // MARK: - Available Years

    func availableYears() -> [Int] {
        let logs = allConfirmedLogs()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let years = Set(logs.map { cal.component(.year, from: $0.date) })
        return years.sorted().reversed()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RoamTests/AnalyticsServiceTests -quiet 2>&1 | tail -20`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/AnalyticsService.swift RoamTests/AnalyticsServiceTests.swift
git commit -m "feat: add analytics service with streak, city count, and ratio calculations"
```

---

### Task 11: Dashboard Views

**Files:**
- Create: `Roam/Views/Dashboard/DashboardView.swift`
- Create: `Roam/Views/Dashboard/CurrentCityBanner.swift`
- Create: `Roam/Views/Dashboard/YearSummaryBar.swift`
- Create: `Roam/Views/Dashboard/TopCitiesList.swift`
- Create: `Roam/Views/Dashboard/QuickStatsRow.swift`

- [ ] **Step 1: Create CurrentCityBanner**

```swift
// Roam/Views/Dashboard/CurrentCityBanner.swift
import SwiftUI

struct CurrentCityBanner: View {
    let cityName: String
    let streakDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Currently in")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(cityName)
                .font(.title)
                .fontWeight(.bold)
            Text("Day \(streakDays) of current streak")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 2: Create YearSummaryBar**

```swift
// Roam/Views/Dashboard/YearSummaryBar.swift
import SwiftUI

struct YearSummaryBar: View {
    let cityDays: [(name: String, days: Int, color: Color)]
    let totalDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(Calendar.current.component(.year, from: .now)))
                    .fontWeight(.semibold)
                Spacer()
                Text("\(totalDays) days logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(cityDays.enumerated()), id: \.offset) { _, entry in
                        let width = totalDays > 0
                            ? geo.size.width * CGFloat(entry.days) / CGFloat(totalDays)
                            : 0
                        RoundedRectangle(cornerRadius: 4)
                            .fill(entry.color)
                            .frame(width: max(width, 4))
                            .overlay {
                                if width > 40 {
                                    Text(entry.name)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
            .frame(height: 28)
        }
    }
}
```

- [ ] **Step 3: Create TopCitiesList**

```swift
// Roam/Views/Dashboard/TopCitiesList.swift
import SwiftUI

struct TopCitiesList: View {
    let cities: [(name: String, nights: Int, percentage: Double, color: Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Top Cities")
                .fontWeight(.semibold)
                .padding(.bottom, 12)

            ForEach(Array(cities.enumerated()), id: \.offset) { _, city in
                HStack {
                    Circle()
                        .fill(city.color)
                        .frame(width: 10, height: 10)
                    Text(city.name)
                    Spacer()
                    Text("\(city.nights) nights")
                        .fontWeight(.semibold)
                    Text("\(Int(city.percentage * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.vertical, 8)
                if city.name != cities.last?.name {
                    Divider()
                }
            }
        }
    }
}
```

- [ ] **Step 4: Create QuickStatsRow**

```swift
// Roam/Views/Dashboard/QuickStatsRow.swift
import SwiftUI

struct QuickStatsRow: View {
    let citiesVisited: Int
    let longestStreak: Int
    let homeRatio: Int

    var body: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(citiesVisited)", label: "Cities visited")
            StatCard(value: "\(longestStreak)", label: "Longest streak")
            StatCard(value: "\(homeRatio)%", label: "Home ratio")
        }
    }
}

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 5: Create DashboardView**

```swift
// Roam/Views/Dashboard/DashboardView.swift
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NightLog.date, order: .reverse) private var allLogs: [NightLog]
    @Query private var cityColors: [CityColor]
    @Query private var settings: [UserSettings]

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        let analytics = AnalyticsService(context: context)
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    let streak = analytics.currentStreak(asOf: DateNormalization.normalizedNightDate(from: .now))

                    CurrentCityBanner(
                        cityName: streak.city.isEmpty ? "No data yet" : streak.city,
                        streakDays: streak.days
                    )

                    let cityDaysMap = analytics.daysPerCity(year: currentYear)
                    let totalDays = cityDaysMap.values.reduce(0, +)
                    let sortedCities = cityDaysMap.sorted { $0.value > $1.value }

                    YearSummaryBar(
                        cityDays: sortedCities.map { entry in
                            let colorIndex = cityColors.first { $0.cityKey == entry.key }?.colorIndex ?? 0
                            let parts = entry.key.split(separator: "|")
                            return (name: String(parts.first ?? ""), days: entry.value, color: ColorPalette.color(for: colorIndex))
                        },
                        totalDays: totalDays
                    )

                    let deviceRegion = Locale.current.region?.identifier
                    TopCitiesList(
                        cities: sortedCities.prefix(5).map { entry in
                            let colorIndex = cityColors.first { $0.cityKey == entry.key }?.colorIndex ?? 0
                            let parts = entry.key.split(separator: "|")
                            let city = parts.count > 0 ? String(parts[0]) : ""
                            let state = parts.count > 1 ? String(parts[1]) : nil
                            let country = parts.count > 2 ? String(parts[2]) : nil
                            let displayName = CityDisplayFormatter.format(city: city, state: state, country: country, deviceRegion: deviceRegion)
                            return (name: displayName, nights: entry.value, percentage: totalDays > 0 ? Double(entry.value) / Double(totalDays) : 0, color: ColorPalette.color(for: colorIndex))
                        }
                    )

                    let homeCityKey = settings.first?.homeCityKey ?? ""
                    let longestStreak = analytics.longestStreak(year: currentYear)
                    let ratio = analytics.homeAwayRatio(year: currentYear, homeCityKey: homeCityKey)

                    QuickStatsRow(
                        citiesVisited: analytics.uniqueCitiesCount(year: currentYear),
                        longestStreak: longestStreak.days,
                        homeRatio: Int(ratio.homePercentage * 100)
                    )
                }
                .padding()
            }
            .navigationTitle("Roam")
        }
    }
}
```

- [ ] **Step 6: Wire Dashboard into ContentView**

Update `Roam/ContentView.swift`:

```swift
// Roam/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView()
            }
            Tab("Timeline", systemImage: "calendar") {
                Text("Timeline")
            }
            Tab("Insights", systemImage: "lightbulb.fill") {
                Text("Insights")
            }
        }
    }
}
```

- [ ] **Step 7: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add Roam/Views/Dashboard/ Roam/ContentView.swift
git commit -m "feat: add dashboard tab with city banner, summary bar, top cities, and quick stats"
```

---

## Chunk 4: Timeline Tab

### Task 12: Calendar Grid & Day Cell

**Files:**
- Create: `Roam/Views/Timeline/TimelineView.swift`
- Create: `Roam/Views/Timeline/CalendarGridView.swift`
- Create: `Roam/Views/Timeline/DayCell.swift`

- [ ] **Step 1: Create DayCell**

```swift
// Roam/Views/Timeline/DayCell.swift
import SwiftUI

struct DayCell: View {
    let day: Int
    let color: Color?
    let isUnresolved: Bool
    let isFuture: Bool
    let isToday: Bool

    var body: some View {
        ZStack {
            if let color, !isFuture {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
            } else if isUnresolved {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorPalette.unresolvedColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.yellow.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .opacity(isFuture ? 0.3 : 0.5)
            }

            Text("\(day)")
                .font(.caption)
                .fontWeight(isToday ? .bold : .semibold)
                .foregroundStyle(isFuture ? .secondary : .primary)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
```

- [ ] **Step 2: Create CalendarGridView**

```swift
// Roam/Views/Timeline/CalendarGridView.swift
import SwiftUI
import SwiftData

struct CalendarGridView: View {
    let year: Int
    let month: Int
    let logs: [NightLog]
    let cityColors: [CityColor]
    let onDayTapped: (NightLog?) -> Void

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

    private var firstWeekday: Int {
        // 1 = Sunday in Calendar
        calendar.component(.weekday, from: firstDayOfMonth) - 1
    }

    private var today: DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.dateComponents([.year, .month, .day], from: DateNormalization.normalizedNightDate(from: .now))
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
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        LazyVGrid(columns: columns, spacing: 4) {
            // Empty cells before first day
            ForEach(0..<firstWeekday, id: \.self) { _ in
                Color.clear.aspectRatio(1, contentMode: .fit)
            }

            // Day cells
            ForEach(1...daysInMonth, id: \.self) { day in
                let log = logFor(day: day)
                let isFuture = (year > today.year! || (year == today.year! && month > today.month!) ||
                               (year == today.year! && month == today.month! && day > today.day!))
                let isToday = (year == today.year! && month == today.month! && day == today.day!)

                DayCell(
                    day: day,
                    color: colorFor(log: log),
                    isUnresolved: log?.status == .unresolved,
                    isFuture: isFuture,
                    isToday: isToday
                )
                .onTapGesture {
                    if !isFuture {
                        onDayTapped(log)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Create TimelineView**

```swift
// Roam/Views/Timeline/TimelineView.swift
import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NightLog.date) private var allLogs: [NightLog]
    @Query private var cityColors: [CityColor]

    @State private var displayedMonth = Calendar.current.component(.month, from: Date())
    @State private var displayedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedLog: NightLog?
    @State private var showingDetail = false

    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols

    var body: some View {
        NavigationStack {
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
                    ForEach(weekdaySymbols, id: \.self) { symbol in
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
                ) { log in
                    selectedLog = log
                    showingDetail = true
                }
                .padding(.horizontal)

                // Legend
                legend

                Spacer()
            }
            .navigationTitle("Timeline")
            .sheet(isPresented: $showingDetail) {
                if let selectedLog {
                    DayDetailSheet(log: selectedLog)
                }
            }
        }
    }

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

    private var legend: some View {
        let usedKeys = Set(allLogs.compactMap {
            $0.status != .unresolved ? CityDisplayFormatter.cityKey(city: $0.city, state: $0.state, country: $0.country) : nil
        })

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(cityColors.filter { usedKeys.contains($0.cityKey) }, id: \.cityKey) { cc in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ColorPalette.color(for: cc.colorIndex))
                            .frame(width: 10, height: 10)
                        Text(cc.cityKey.split(separator: "|").first.map(String.init) ?? "")
                            .font(.caption2)
                    }
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorPalette.unresolvedColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(Color.yellow.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2]))
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

- [ ] **Step 4: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Roam/Views/Timeline/TimelineView.swift Roam/Views/Timeline/CalendarGridView.swift Roam/Views/Timeline/DayCell.swift
git commit -m "feat: add timeline tab with calendar grid and color-coded day cells"
```

---

### Task 13: Day Detail Sheet

**Files:**
- Create: `Roam/Views/Timeline/DayDetailSheet.swift`

- [ ] **Step 1: Create DayDetailSheet**

```swift
// Roam/Views/Timeline/DayDetailSheet.swift
import SwiftUI

struct DayDetailSheet: View {
    let log: NightLog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingCitySearch = false
    @State private var selectedCity: String?
    @State private var selectedState: String?
    @State private var selectedCountry: String?

    private var dateString: String {
        log.date.formatted(date: .long, time: .omitted)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Date", value: dateString)
                    LabeledContent("City", value: CityDisplayFormatter.format(
                        city: log.city, state: log.state, country: log.country
                    ))
                    LabeledContent("Status", value: log.status.rawValue.capitalized)
                }

                if log.status == .confirmed || log.status == .manual {
                    Section("Capture Details") {
                        LabeledContent("Captured at", value: log.capturedAt.formatted(date: .omitted, time: .shortened))
                        if let accuracy = log.horizontalAccuracy {
                            LabeledContent("Accuracy", value: "\(Int(accuracy))m")
                        }
                        LabeledContent("Source", value: log.source.rawValue.capitalized)
                        if let lat = log.latitude, let lon = log.longitude {
                            LabeledContent("Coordinates", value: String(format: "%.4f, %.4f", lat, lon))
                        }
                    }
                }

                Section {
                    Button("Edit City") {
                        showingCitySearch = true
                    }
                }
            }
            .navigationTitle("Night Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCitySearch) {
                CitySearchView(
                    selectedCity: $selectedCity,
                    selectedState: $selectedState,
                    selectedCountry: $selectedCountry
                )
            }
            .onChange(of: selectedCity) { _, newCity in
                guard let newCity else { return }
                log.city = newCity
                log.state = selectedState
                log.country = selectedCountry
                log.source = .manual
                if log.status == .unresolved { log.status = .manual }

                let cityKey = CityDisplayFormatter.cityKey(city: newCity, state: selectedState, country: selectedCountry)
                let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
                if !existingColors.contains(where: { $0.cityKey == cityKey }) {
                    let nextIndex = (existingColors.map(\.colorIndex).max() ?? -1) + 1
                    context.insert(CityColor(cityKey: cityKey, colorIndex: nextIndex))
                }
                try? context.save()
            }
        }
        .presentationDetents([.medium, .large])
    }
}
```

- [ ] **Step 2: Wire Timeline into ContentView**

Update `Roam/ContentView.swift`:

```swift
// Roam/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView()
            }
            Tab("Timeline", systemImage: "calendar") {
                TimelineView()
            }
            Tab("Insights", systemImage: "lightbulb.fill") {
                Text("Insights")
            }
        }
    }
}
```

- [ ] **Step 3: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Roam/Views/Timeline/DayDetailSheet.swift Roam/ContentView.swift
git commit -m "feat: add day detail sheet and wire timeline into tab bar"
```

---

## Chunk 5: Insights Tab

### Task 14: Insights Views

**Files:**
- Create: `Roam/Views/Insights/InsightsView.swift`
- Create: `Roam/Views/Insights/YearPicker.swift`
- Create: `Roam/Views/Insights/MonthlyBreakdownChart.swift`
- Create: `Roam/Views/Insights/HighlightsGrid.swift`
- Create: `Roam/Views/Insights/YearOverYearView.swift`

- [ ] **Step 1: Create YearPicker**

```swift
// Roam/Views/Insights/YearPicker.swift
import SwiftUI

struct YearPicker: View {
    let years: [Int]
    /// nil means "All Time"
    @Binding var selectedYear: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(years, id: \.self) { year in
                    chipButton(label: String(year), isSelected: selectedYear == year) {
                        selectedYear = year
                    }
                }
                chipButton(label: "All Time", isSelected: selectedYear == nil) {
                    selectedYear = nil
                }
            }
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Create MonthlyBreakdownChart**

```swift
// Roam/Views/Insights/MonthlyBreakdownChart.swift
import SwiftUI
import Charts

struct MonthlyBreakdownChart: View {
    let breakdown: [MonthlyBreakdown]
    let cityColors: [CityColor]

    private let monthLabels = Calendar.current.veryShortMonthSymbols

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Breakdown")
                .fontWeight(.semibold)

            Chart {
                ForEach(breakdown, id: \.month) { month in
                    ForEach(Array(month.cityDays.enumerated()), id: \.offset) { _, entry in
                        BarMark(
                            x: .value("Month", monthLabels[month.month - 1]),
                            y: .value("Days", entry.days)
                        )
                        .foregroundStyle(colorForCity(entry.cityKey))
                    }
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
        }
    }

    private func colorForCity(_ key: String) -> Color {
        guard let cc = cityColors.first(where: { $0.cityKey == key }) else {
            return .gray
        }
        return ColorPalette.color(for: cc.colorIndex)
    }
}
```

- [ ] **Step 3: Create HighlightsGrid**

```swift
// Roam/Views/Insights/HighlightsGrid.swift
import SwiftUI

struct HighlightsGrid: View {
    let mostVisited: (city: String, nights: Int)
    let longestStreak: StreakInfo
    let newCities: [String]
    let homeAwayRatio: HomeAwayRatio

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Highlights")
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                HighlightCard(
                    label: "Most visited",
                    value: mostVisited.city,
                    detail: "\(mostVisited.nights) nights"
                )
                HighlightCard(
                    label: "Longest streak",
                    value: longestStreak.city,
                    detail: "\(longestStreak.days) consecutive"
                )
                HighlightCard(
                    label: "New cities this year",
                    value: "\(newCities.count)",
                    detail: newCities.prefix(3).joined(separator: ", ")
                )
                HighlightCard(
                    label: "Home vs. away",
                    value: "\(Int(homeAwayRatio.homePercentage * 100))% / \(Int(homeAwayRatio.awayPercentage * 100))%",
                    detail: ""
                )
            }
        }
    }
}

private struct HighlightCard: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 4: Create YearOverYearView**

```swift
// Roam/Views/Insights/YearOverYearView.swift
import SwiftUI

struct YearOverYearView: View {
    let years: [(year: Int, totalCities: Int, nightsAway: Int, avgTrip: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Year over Year")
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                comparisonRow(label: "Total cities") { "\($0.totalCities)" }
                comparisonRow(label: "Nights away") { "\($0.nightsAway)" }
                comparisonRow(label: "Avg trip length") { String(format: "%.1fd", $0.avgTrip) }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func comparisonRow(
        label: String,
        value: @escaping ((year: Int, totalCities: Int, nightsAway: Int, avgTrip: Double)) -> String
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 16) {
                ForEach(years, id: \.year) { yearData in
                    VStack(alignment: .trailing) {
                        Text(value(yearData))
                            .font(.subheadline)
                            .fontWeight(yearData.year == years.last?.year ? .semibold : .regular)
                            .foregroundStyle(yearData.year == years.last?.year ? .primary : .secondary)
                    }
                    .frame(width: 50, alignment: .trailing)
                }
            }
        }
    }
}
```

- [ ] **Step 5: Create InsightsView**

```swift
// Roam/Views/Insights/InsightsView.swift
import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Query private var cityColors: [CityColor]
    @Query private var settings: [UserSettings]

    @State private var selectedYear: Int? = Calendar.current.component(.year, from: .now)

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

                    // When selectedYear is nil, show all-time data using current year for monthly chart
                    let displayYear = selectedYear ?? currentYear

                    MonthlyBreakdownChart(
                        breakdown: analytics.monthlyBreakdown(year: displayYear),
                        cityColors: cityColors
                    )

                    // For "All Time", aggregate across all years
                    let cityDays: [String: Int]
                    if let year = selectedYear {
                        cityDays = analytics.daysPerCity(year: year)
                    } else {
                        var allTimeDays: [String: Int] = [:]
                        for year in analytics.availableYears() {
                            for (key, count) in analytics.daysPerCity(year: year) {
                                allTimeDays[key, default: 0] += count
                            }
                        }
                        cityDays = allTimeDays
                    }

                    let topCity = cityDays.max(by: { $0.value < $1.value })
                    let topCityName = topCity?.key.split(separator: "|").first.map(String.init) ?? ""
                    let homeCityKey = settings.first?.homeCityKey ?? ""

                    HighlightsGrid(
                        mostVisited: (city: topCityName, nights: topCity?.value ?? 0),
                        longestStreak: analytics.longestStreak(year: displayYear),
                        newCities: analytics.newCities(year: displayYear),
                        homeAwayRatio: analytics.homeAwayRatio(year: displayYear, homeCityKey: homeCityKey)
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
            .navigationTitle("Insights")
        }
    }
}
```

- [ ] **Step 6: Wire Insights into ContentView**

Update `Roam/ContentView.swift`:

```swift
// Roam/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.bar.fill") {
                DashboardView()
            }
            Tab("Timeline", systemImage: "calendar") {
                TimelineView()
            }
            Tab("Insights", systemImage: "lightbulb.fill") {
                InsightsView()
            }
        }
    }
}
```

- [ ] **Step 7: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add Roam/Views/Insights/ Roam/ContentView.swift
git commit -m "feat: add insights tab with charts, highlights, and year-over-year comparison"
```

---

## Chunk 6: Settings, Onboarding & Integration

### Task 15: City Search View

**Files:**
- Create: `Roam/Views/Settings/CitySearchView.swift`

- [ ] **Step 1: Create CitySearchView**

```swift
// Roam/Views/Settings/CitySearchView.swift
import SwiftUI
import MapKit

struct CitySearchView: View {
    @Binding var selectedCity: String?
    @Binding var selectedState: String?
    @Binding var selectedCountry: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @State private var completer = CitySearchCompleter()

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { completion in
                Button {
                    Task { await selectCompletion(completion) }
                } label: {
                    VStack(alignment: .leading) {
                        Text(completion.title)
                        Text(completion.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search cities")
            .onChange(of: searchText) { _, newValue in
                completer.search(query: newValue) { completions in
                    results = completions
                }
            }
            .navigationTitle("Select City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(),
              let item = response.mapItems.first else { return }

        selectedCity = item.placemark.locality
        selectedState = item.placemark.administrativeArea
        selectedCountry = item.placemark.isoCountryCode
        dismiss()
    }
}

private class CitySearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var handler: (([MKLocalSearchCompletion]) -> Void)?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(query: String, handler: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.handler = handler
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        handler?(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        handler?([])
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Settings/CitySearchView.swift
git commit -m "feat: add city search view with MKLocalSearchCompleter"
```

---

### Task 16: Data Export View

**Files:**
- Create: `Roam/Views/Settings/DataExportView.swift`

- [ ] **Step 1: Create DataExportView**

```swift
// Roam/Views/Settings/DataExportView.swift
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NightLog.date) private var allLogs: [NightLog]

    @State private var exportFormat: ExportFormat = .csv
    @State private var filterYear: Int? = nil
    @State private var showingShareSheet = false
    @State private var exportURL: URL?

    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
    }

    private var filteredLogs: [NightLog] {
        guard let year = filterYear else { return Array(allLogs) }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return allLogs.filter { cal.component(.year, from: $0.date) == year }
    }

    private var availableYears: [Int] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let years = Set(allLogs.map { cal.component(.year, from: $0.date) })
        return years.sorted().reversed()
    }

    var body: some View {
        Form {
            Section("Scope") {
                Picker("Year", selection: $filterYear) {
                    Text("All Time").tag(nil as Int?)
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year)).tag(year as Int?)
                    }
                }
            }

            Section("Format") {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button("Export \(filteredLogs.count) entries") {
                    exportData()
                }
            }
        }
        .navigationTitle("Export Data")
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareLink(item: url)
            }
        }
    }

    private func exportData() {
        let tempDir = FileManager.default.temporaryDirectory

        switch exportFormat {
        case .csv:
            let csv = generateCSV()
            let url = tempDir.appendingPathComponent("roam-export.csv")
            try? csv.write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
        case .json:
            let json = generateJSON()
            let url = tempDir.appendingPathComponent("roam-export.json")
            try? json.write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
        }
        showingShareSheet = true
    }

    private func generateCSV() -> String {
        var lines = ["date,city,state,country,latitude,longitude,source,status,captured_at,accuracy"]
        let formatter = ISO8601DateFormatter()
        for log in filteredLogs {
            let fields = [
                formatter.string(from: log.date),
                log.city ?? "",
                log.state ?? "",
                log.country ?? "",
                log.latitude.map { String($0) } ?? "",
                log.longitude.map { String($0) } ?? "",
                log.source.rawValue,
                log.status.rawValue,
                formatter.string(from: log.capturedAt),
                log.horizontalAccuracy.map { String(Int($0)) } ?? ""
            ]
            lines.append(fields.map { "\"\($0)\"" }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private func generateJSON() -> String {
        let formatter = ISO8601DateFormatter()
        let entries = filteredLogs.map { log -> [String: Any] in
            var dict: [String: Any] = [
                "date": formatter.string(from: log.date),
                "source": log.source.rawValue,
                "status": log.status.rawValue,
                "captured_at": formatter.string(from: log.capturedAt)
            ]
            if let city = log.city { dict["city"] = city }
            if let state = log.state { dict["state"] = state }
            if let country = log.country { dict["country"] = country }
            if let lat = log.latitude { dict["latitude"] = lat }
            if let lon = log.longitude { dict["longitude"] = lon }
            if let acc = log.horizontalAccuracy { dict["accuracy"] = acc }
            return dict
        }
        let data = try? JSONSerialization.data(withJSONObject: entries, options: .prettyPrinted)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Settings/DataExportView.swift
git commit -m "feat: add data export view with CSV and JSON support"
```

---

### Task 17: Settings View

**Files:**
- Create: `Roam/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Create SettingsView**

```swift
// Roam/Views/Settings/SettingsView.swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsArray: [UserSettings]
    @State private var showingCitySearch = false
    @State private var selectedCity: String?
    @State private var selectedState: String?
    @State private var selectedCountry: String?

    private var settings: UserSettings {
        if let existing = settingsArray.first {
            return existing
        }
        let new = UserSettings()
        context.insert(new)
        try? context.save()
        return new
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Home City") {
                    Button {
                        showingCitySearch = true
                    } label: {
                        HStack {
                            Text("Home City")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(homeCityDisplay)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Capture Schedule") {
                    DatePicker(
                        "Primary check",
                        selection: Binding(
                            get: { timeFromComponents(hour: settings.primaryCheckHour, minute: settings.primaryCheckMinute) },
                            set: { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                settings.primaryCheckHour = comps.hour ?? 2
                                settings.primaryCheckMinute = comps.minute ?? 0
                                BackgroundTaskService.schedulePrimaryCapture(hour: settings.primaryCheckHour, minute: settings.primaryCheckMinute)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "Retry check",
                        selection: Binding(
                            get: { timeFromComponents(hour: settings.retryCheckHour, minute: settings.retryCheckMinute) },
                            set: { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                settings.retryCheckHour = comps.hour ?? 5
                                settings.retryCheckMinute = comps.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("Data") {
                    Toggle("iCloud Sync", isOn: Binding(
                        get: { settings.iCloudSyncEnabled },
                        set: { settings.iCloudSyncEnabled = $0 }
                    ))
                    Toggle("Unresolved Night Notifications", isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: { settings.notificationsEnabled = $0 }
                    ))
                    NavigationLink("Export Data") {
                        DataExportView()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    Text("Roam tracks your location once nightly to log which city you sleep in. Location data is stored on-device and synced via iCloud. Your data is never shared with third parties.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCitySearch) {
                CitySearchView(
                    selectedCity: $selectedCity,
                    selectedState: $selectedState,
                    selectedCountry: $selectedCountry
                )
            }
            .onChange(of: selectedCity) { _, newCity in
                guard let newCity else { return }
                let key = CityDisplayFormatter.cityKey(city: newCity, state: selectedState, country: selectedCountry)
                settings.homeCityKey = key
                try? context.save()
            }
        }
    }

    private var homeCityDisplay: String {
        guard let key = settings.homeCityKey else { return "Not set" }
        let parts = key.split(separator: "|")
        guard let city = parts.first else { return "Not set" }
        let state = parts.count > 1 ? String(parts[1]) : nil
        let country = parts.count > 2 ? String(parts[2]) : nil
        return CityDisplayFormatter.format(city: String(city), state: state, country: country)
    }

    private func timeFromComponents(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Settings/SettingsView.swift
git commit -m "feat: add settings view with home city, capture schedule, and export"
```

---

### Task 18: Onboarding View

**Files:**
- Create: `Roam/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Create OnboardingView**

```swift
// Roam/Views/Onboarding/OnboardingView.swift
import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @ObservedObject var locationService: LocationCaptureService
    @Binding var hasCompletedOnboarding: Bool

    @State private var step: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case locationExplanation
        case requestingPermission
        case complete
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            switch step {
            case .welcome:
                welcomeView
            case .locationExplanation:
                locationExplanationView
            case .requestingPermission:
                requestingView
            case .complete:
                completeView
            }

            Spacer()
        }
        .padding(32)
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Welcome to Roam")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Track which city you sleep in each night, automatically.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Get Started") {
                step = .locationExplanation
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top)
        }
    }

    private var locationExplanationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Location Access")
                .font(.title2)
                .fontWeight(.bold)
            Text("Roam checks your location once at night (around 2 AM) to determine which city you're in. This requires \"Always\" location access so it can work while you sleep.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Your location data stays on your device and in your private iCloud account. It is never shared.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Allow Location Access") {
                step = .requestingPermission
                locationService.requestWhenInUseAuthorization()
                // After granting "While Using", we need to request Always
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if locationService.authorizationStatus == .authorizedWhenInUse {
                        locationService.requestAlwaysAuthorization()
                    }
                    step = .complete
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip for Now") {
                step = .complete
            }
            .foregroundStyle(.secondary)
        }
    }

    private var requestingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Waiting for permission...")
                .foregroundStyle(.secondary)
        }
    }

    private var completeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("You're all set!")
                .font(.title2)
                .fontWeight(.bold)

            let hasAlways = locationService.authorizationStatus == .authorizedAlways
            Text(hasAlways
                 ? "Roam will automatically log your city each night."
                 : "Roam will log your city when you open the app. Enable \"Always\" in Settings for automatic tracking.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Start Using Roam") {
                hasCompletedOnboarding = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Onboarding/OnboardingView.swift
git commit -m "feat: add onboarding flow with location permission request"
```

---

### Task 19: Unresolved Banner & Final Integration

**Files:**
- Create: `Roam/Views/Shared/UnresolvedBanner.swift`
- Create: `Roam/Views/Shared/UnresolvedResolutionView.swift`
- Modify: `Roam/RoamApp.swift`
- Modify: `Roam/ContentView.swift`

- [ ] **Step 1: Create UnresolvedBanner**

```swift
// Roam/Views/Shared/UnresolvedBanner.swift
import SwiftUI
import SwiftData

struct UnresolvedBanner: View {
    let unresolvedCount: Int
    let onTap: () -> Void

    var body: some View {
        if unresolvedCount > 0 {
            Button(action: onTap) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.yellow)
                    Text("\(unresolvedCount) night\(unresolvedCount == 1 ? "" : "s") need\(unresolvedCount == 1 ? "s" : "") your input")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}
```

- [ ] **Step 2: Update ContentView with onboarding, settings, unresolved banner, and backfill**

```swift
// Roam/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [UserSettings]
    @Query private var allLogs: [NightLog]

    @StateObject private var locationService = LocationCaptureService()
    @State private var showingSettings = false
    @State private var showingUnresolvedResolution = false
    @State private var unresolvedToResolve: NightLog?

    private var unresolvedLogs: [NightLog] {
        allLogs.filter { $0.status == .unresolved }
    }

    private var hasCompletedOnboarding: Bool {
        settings.first?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(
                locationService: locationService,
                hasCompletedOnboarding: Binding(
                    get: { hasCompletedOnboarding },
                    set: { newValue in
                        if newValue {
                            let s = settings.first ?? UserSettings()
                            if settings.first == nil { context.insert(s) }
                            s.hasCompletedOnboarding = true
                            try? context.save()
                        }
                    }
                )
            )
        } else {
            TabView {
                Tab("Dashboard", systemImage: "chart.bar.fill") {
                    DashboardView()
                        .safeAreaInset(edge: .top) {
                            UnresolvedBanner(unresolvedCount: unresolvedLogs.count) {
                                unresolvedToResolve = unresolvedLogs.first
                                showingUnresolvedResolution = true
                            }
                            .padding(.horizontal)
                        }
                }
                Tab("Timeline", systemImage: "calendar") {
                    TimelineView()
                }
                Tab("Insights", systemImage: "lightbulb.fill") {
                    InsightsView()
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingUnresolvedResolution) {
                if let log = unresolvedToResolve {
                    UnresolvedResolutionView(log: log)
                }
            }
            .onAppear {
                BackfillService.backfillMissedNights(context: context)
                assignMissingColors()
            }
        }
    }

    /// Assign colors to any cities that don't have one yet.
    private func assignMissingColors() {
        let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
        let existingKeys = Set(existingColors.map(\.cityKey))
        let maxIndex = existingColors.map(\.colorIndex).max() ?? -1

        var nextIndex = maxIndex + 1
        var cityKeys = Set<String>()

        for log in allLogs where log.city != nil {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            if !existingKeys.contains(key) && !cityKeys.contains(key) {
                cityKeys.insert(key)
                let cityColor = CityColor(cityKey: key, colorIndex: nextIndex)
                context.insert(cityColor)
                nextIndex += 1
            }
        }

        if !cityKeys.isEmpty {
            try? context.save()
        }
    }
}
```

- [ ] **Step 3: Create UnresolvedResolutionView**

```swift
// Roam/Views/Shared/UnresolvedResolutionView.swift
import SwiftUI
import SwiftData

struct UnresolvedResolutionView: View {
    let log: NightLog
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCity: String?
    @State private var selectedState: String?
    @State private var selectedCountry: String?
    @State private var showingCitySearch = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Where were you on \(log.date.formatted(date: .long, time: .omitted))?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let city = selectedCity {
                    Text(CityDisplayFormatter.format(city: city, state: selectedState, country: selectedCountry))
                        .font(.title3)
                        .fontWeight(.semibold)

                    Button("Confirm") {
                        log.city = selectedCity
                        log.state = selectedState
                        log.country = selectedCountry
                        log.source = .manual
                        log.status = .manual

                        // Assign color if new city
                        let cityKey = CityDisplayFormatter.cityKey(city: selectedCity, state: selectedState, country: selectedCountry)
                        let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
                        if !existingColors.contains(where: { $0.cityKey == cityKey }) {
                            let nextIndex = (existingColors.map(\.colorIndex).max() ?? -1) + 1
                            context.insert(CityColor(cityKey: cityKey, colorIndex: nextIndex))
                        }

                        try? context.save()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Search for City") {
                    showingCitySearch = true
                }
            }
            .padding()
            .navigationTitle("Resolve Night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCitySearch) {
                CitySearchView(
                    selectedCity: $selectedCity,
                    selectedState: $selectedState,
                    selectedCountry: $selectedCountry
                )
            }
        }
    }
}
```

- [ ] **Step 4: Update RoamApp (no changes needed — already correct from Task 9)**

RoamApp.swift from Task 9 already registers background tasks and sets up the model container. No changes needed here. The backfill is triggered in ContentView's `.onAppear`.

- [ ] **Step 5: Verify full build**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Run all tests**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -30`
Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add Roam/Views/Shared/UnresolvedBanner.swift Roam/Views/Shared/UnresolvedResolutionView.swift Roam/ContentView.swift
git commit -m "feat: add onboarding gate, unresolved banner and resolution, color assignment, and backfill on launch"
```
