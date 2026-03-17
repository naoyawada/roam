# Reliability Hardening Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two redundant capture layers (significant location monitoring + foreground catch) and a passive diagnostic in Settings so that no single iOS limitation can cause a missed night log.

**Architecture:** Extract the shared save-with-dedup logic from BackgroundTaskService into a reusable CaptureResultSaver. Build SignificantLocationService as a CLLocationManager wrapper that captures during the 12-6 AM window on cell tower changes. Add a foreground catch in ContentView.onAppear. All three layers use the same CaptureResultSaver and LocationCaptureService.captureNight() flow.

**Tech Stack:** Swift, SwiftUI, SwiftData, Core Location, os.Logger

---

## File Structure

```
Roam/Services/
├── CaptureResultSaver.swift          — NEW: Shared save-with-dedup logic (extracted from BackgroundTaskService)
├── SignificantLocationService.swift   — NEW: Always-on significant location monitoring
├── BackgroundTaskService.swift        — MODIFY: Refactor to use CaptureResultSaver
├── LocationCaptureService.swift       — UNCHANGED
├── BackfillService.swift              — UNCHANGED
├── DateNormalization.swift            — UNCHANGED

Roam/
├── RoamApp.swift                      — MODIFY: Initialize SignificantLocationService
├── ContentView.swift                  — MODIFY: Add foreground catch before backfill

Roam/Views/Settings/
├── SettingsView.swift                 — MODIFY: Add "Capture Status" section

RoamTests/
├── CaptureResultSaverTests.swift      — NEW: Dedup logic tests with in-memory SwiftData
├── SignificantLocationServiceTests.swift — NEW: Time-window logic tests
```

---

## Chunk 1: Extract Shared Save Logic

The save-confirmed-entry and save-unresolved patterns in BackgroundTaskService (lines 115-168, 172-188) will be needed by three consumers. Extract into a focused helper.

### Task 1: Create CaptureResultSaver with tests

**Files:**
- Create: `Roam/Services/CaptureResultSaver.swift`
- Create: `RoamTests/CaptureResultSaverTests.swift`

- [ ] **Step 1: Write failing tests for save logic**

```swift
// RoamTests/CaptureResultSaverTests.swift
import XCTest
import SwiftData
@testable import Roam

final class CaptureResultSaverTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: NightLog.self, CityColor.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    // Save a confirmed entry when no entry exists
    @MainActor
    func testSaveResult_noExistingEntry_createsConfirmed() {
        let result = makeCaptureResult(city: "Austin", capturedAt: date(2026, 3, 17, hour: 2))
        CaptureResultSaver.save(result: result, context: context)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].city, "Austin")
        XCTAssertEqual(logs[0].status, .confirmed)
    }

    // Don't overwrite a confirmed entry
    @MainActor
    func testSaveResult_confirmedExists_doesNotOverwrite() {
        let nightDate = noonUTC(2026, 3, 16)
        let existing = NightLog(date: nightDate, city: "Austin", source: .automatic, status: .confirmed)
        context.insert(existing)
        try! context.save()

        let result = makeCaptureResult(city: "Houston", capturedAt: date(2026, 3, 17, hour: 2))
        CaptureResultSaver.save(result: result, context: context)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].city, "Austin") // unchanged
    }

    // Update an unresolved entry with capture data
    @MainActor
    func testSaveResult_unresolvedExists_updatesToConfirmed() {
        let nightDate = noonUTC(2026, 3, 16)
        let existing = NightLog(date: nightDate, source: .automatic, status: .unresolved)
        context.insert(existing)
        try! context.save()

        let result = makeCaptureResult(city: "Austin", capturedAt: date(2026, 3, 17, hour: 2))
        CaptureResultSaver.save(result: result, context: context)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].city, "Austin")
        XCTAssertEqual(logs[0].status, .confirmed)
    }

    // Assigns a city color for new cities
    @MainActor
    func testSaveResult_newCity_assignsCityColor() {
        let result = makeCaptureResult(city: "Austin", state: "TX", country: "US", capturedAt: date(2026, 3, 17, hour: 2))
        CaptureResultSaver.save(result: result, context: context)

        let colors = try! context.fetch(FetchDescriptor<CityColor>())
        XCTAssertEqual(colors.count, 1)
        XCTAssertEqual(colors[0].cityKey, "Austin|TX|US")
    }

    // MARK: - Helpers

    private func makeCaptureResult(
        city: String, state: String? = nil, country: String? = nil,
        capturedAt: Date
    ) -> CaptureResult {
        CaptureResult(
            city: city, state: state, country: country,
            latitude: 30.27, longitude: -97.74,
            horizontalAccuracy: 10.0, capturedAt: capturedAt
        )
    }

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/CaptureResultSaverTests -quiet 2>&1`
Expected: FAIL — `CaptureResultSaver` not found

- [ ] **Step 3: Implement CaptureResultSaver**

```swift
// Roam/Services/CaptureResultSaver.swift
import os
import SwiftData

enum CaptureResultSaver {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "CaptureResultSaver")

    /// Save a capture result with dedup logic:
    /// - If a confirmed/manual entry exists for the night → no-op
    /// - If an unresolved entry exists → update it to confirmed
    /// - If no entry exists → create a new confirmed entry
    /// Also assigns a city color if the city is new.
    @MainActor
    static func save(result: CaptureResult, context: ModelContext) {
        let nightDate = DateNormalization.normalizedNightDate(from: result.capturedAt)
        let existing = try? context.fetch(
            FetchDescriptor<NightLog>(predicate: #Predicate { $0.date == nightDate })
        ).first

        let unresolvedRaw = LogStatus.unresolvedRaw
        if let existing, existing.statusRaw != unresolvedRaw {
            logger.info("Entry already exists for \(nightDate), skipping")
            return
        }

        if let existing {
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

        do {
            try context.save()
            logger.info("Saved confirmed entry: \(result.city) for \(nightDate)")
        } catch {
            logger.error("Failed to save entry: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/CaptureResultSaverTests -quiet 2>&1`
Expected: 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/CaptureResultSaver.swift RoamTests/CaptureResultSaverTests.swift
git commit -m "feat: extract CaptureResultSaver with dedup logic and tests"
```

### Task 2: Refactor BackgroundTaskService to use CaptureResultSaver

**Files:**
- Modify: `Roam/Services/BackgroundTaskService.swift`

- [ ] **Step 1: Replace inline save logic with CaptureResultSaver.save()**

In `BackgroundTaskService.handleCapture()`, replace lines 115-168 (the save-confirmed-entry block) with:

```swift
        CaptureResultSaver.save(result: result, context: context)
        task.setTaskCompleted(success: true)
```

Remove the `saveUnresolvedEntry` private method (lines 172-188) and replace its two call sites (lines 86 and 107) with the existing inline pattern — or keep `saveUnresolvedEntry` as-is since it creates unresolved entries (different from CaptureResultSaver which saves confirmed results).

- [ ] **Step 2: Build and run full test suite**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1`
Expected: All tests PASS, no regressions

- [ ] **Step 3: Commit**

```bash
git add Roam/Services/BackgroundTaskService.swift
git commit -m "refactor: use CaptureResultSaver in BackgroundTaskService"
```

---

## Chunk 2: Significant Location Monitoring

### Task 3: Create SignificantLocationService with tests

**Files:**
- Create: `Roam/Services/SignificantLocationService.swift`
- Create: `RoamTests/SignificantLocationServiceTests.swift`

- [ ] **Step 1: Write failing tests for time-window logic**

The time-window check must be a pure, testable static method.

```swift
// RoamTests/SignificantLocationServiceTests.swift
import XCTest
@testable import Roam

final class SignificantLocationServiceTests: XCTestCase {

    // 2 AM is inside the capture window
    func testIsInCaptureWindow_2AM_returnsTrue() {
        let date = makeDate(hour: 2, minute: 0)
        XCTAssertTrue(SignificantLocationService.isInCaptureWindow(date: date))
    }

    // 5:59 AM is inside the capture window
    func testIsInCaptureWindow_559AM_returnsTrue() {
        let date = makeDate(hour: 5, minute: 59)
        XCTAssertTrue(SignificantLocationService.isInCaptureWindow(date: date))
    }

    // Midnight is inside the capture window
    func testIsInCaptureWindow_midnight_returnsTrue() {
        let date = makeDate(hour: 0, minute: 0)
        XCTAssertTrue(SignificantLocationService.isInCaptureWindow(date: date))
    }

    // 6 AM is outside the capture window
    func testIsInCaptureWindow_6AM_returnsFalse() {
        let date = makeDate(hour: 6, minute: 0)
        XCTAssertFalse(SignificantLocationService.isInCaptureWindow(date: date))
    }

    // 10 PM is outside the capture window
    func testIsInCaptureWindow_10PM_returnsFalse() {
        let date = makeDate(hour: 22, minute: 0)
        XCTAssertFalse(SignificantLocationService.isInCaptureWindow(date: date))
    }

    // Noon is outside the capture window
    func testIsInCaptureWindow_noon_returnsFalse() {
        let date = makeDate(hour: 12, minute: 0)
        XCTAssertFalse(SignificantLocationService.isInCaptureWindow(date: date))
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: DateComponents(
            year: 2026, month: 3, day: 17,
            hour: hour, minute: minute, second: 0
        ))!
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/SignificantLocationServiceTests -quiet 2>&1`
Expected: FAIL — `SignificantLocationService` not found

- [ ] **Step 3: Implement SignificantLocationService**

```swift
// Roam/Services/SignificantLocationService.swift
import CoreLocation
import os
import SwiftData

@MainActor
final class SignificantLocationService: NSObject, ObservableObject {

    private let locationManager = CLLocationManager()
    private let modelContainer: ModelContainer
    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "SignificantLocation")

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        locationManager.delegate = self
    }

    func startMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            Self.logger.warning("Significant location monitoring not available")
            return
        }
        locationManager.startMonitoringSignificantLocationChanges()
        Self.logger.info("Significant location monitoring started")
    }

    /// Check if the given date falls within the capture window (12:00 AM – 5:59 AM local).
    nonisolated static func isInCaptureWindow(date: Date, timeZone: TimeZone = .current) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let hour = cal.component(.hour, from: date)
        return hour < 6
    }

    private func handleLocationUpdate() async {
        let now = Date.now

        guard Self.isInCaptureWindow(date: now) else {
            Self.logger.info("Outside capture window, ignoring")
            return
        }

        let context = modelContainer.mainContext
        let nightDate = DateNormalization.normalizedNightDate(from: now)

        // Check if we already have a confirmed/manual entry for tonight
        let existing = try? context.fetch(
            FetchDescriptor<NightLog>(predicate: #Predicate { $0.date == nightDate })
        ).first

        let unresolvedRaw = LogStatus.unresolvedRaw
        if let existing, existing.statusRaw != unresolvedRaw {
            Self.logger.info("Confirmed entry already exists for \(nightDate), skipping")
            return
        }

        // Check authorization
        guard locationManager.authorizationStatus == .authorizedAlways else {
            Self.logger.error("Location not authorizedAlways, skipping capture")
            return
        }

        // Attempt capture
        Self.logger.info("No confirmed entry for tonight, attempting capture")
        let service = LocationCaptureService()
        guard let result = await service.captureNight() else {
            Self.logger.error("Significant location capture failed")
            return
        }

        CaptureResultSaver.save(result: result, context: context)
        Self.logger.info("Significant location capture succeeded: \(result.city)")
    }
}

extension SignificantLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            await handleLocationUpdate()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        SignificantLocationService.logger.error("Significant location error: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/SignificantLocationServiceTests -quiet 2>&1`
Expected: 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/SignificantLocationService.swift RoamTests/SignificantLocationServiceTests.swift
git commit -m "feat: add SignificantLocationService with time-window capture"
```

### Task 4: Wire SignificantLocationService into RoamApp

**Files:**
- Modify: `Roam/RoamApp.swift`

- [ ] **Step 1: Add SignificantLocationService to RoamApp**

Replace the current `RoamApp` with:

```swift
import SwiftUI
import SwiftData

@main
struct RoamApp: App {
    @Environment(\.scenePhase) private var scenePhase
    let modelContainer: ModelContainer
    let significantLocationService: SignificantLocationService

    init() {
        do {
            modelContainer = try ModelContainer(for: NightLog.self, CityColor.self, UserSettings.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        significantLocationService = SignificantLocationService(modelContainer: modelContainer)

        BackgroundTaskService.register(modelContainer: modelContainer)
        BackgroundTaskService.schedulePrimaryCapture()
        significantLocationService.startMonitoring()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                BackgroundTaskService.schedulePrimaryCapture()
            }
        }
    }
}
```

- [ ] **Step 2: Build and run full test suite**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add Roam/RoamApp.swift
git commit -m "feat: wire SignificantLocationService into app launch"
```

---

## Chunk 3: Foreground Catch + Settings Diagnostic

### Task 5: Add foreground catch to ContentView

**Files:**
- Modify: `Roam/ContentView.swift`

- [ ] **Step 1: Add foreground capture attempt before backfill**

Add a new method `attemptForegroundCapture()` to `ContentView` and call it from `.onAppear` before backfill:

```swift
import os

// Add to ContentView:
private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "ForegroundCatch")

// Replace the .onAppear block with:
.task {
    await attemptForegroundCapture()
    BackfillService.backfillMissedNights(context: context)
    assignMissingColors()
}

// Add this method to ContentView:
private func attemptForegroundCapture() async {
    let nightDate = DateNormalization.normalizedNightDate(from: .now)

    let existing = try? context.fetch(
        FetchDescriptor<NightLog>(predicate: #Predicate { $0.date == nightDate })
    ).first

    let unresolvedRaw = LogStatus.unresolvedRaw
    if let existing, existing.statusRaw != unresolvedRaw {
        return // already have a confirmed/manual entry
    }

    guard locationService.authorizationStatus == .authorizedAlways else {
        return
    }

    Self.logger.info("Attempting foreground capture for \(nightDate)")
    guard let result = await locationService.captureNight() else {
        Self.logger.error("Foreground capture failed")
        return
    }

    CaptureResultSaver.save(result: result, context: context)
    Self.logger.info("Foreground capture succeeded: \(result.city)")
}
```

Note: change `.onAppear` to `.task` so the async `captureNight()` call works.

- [ ] **Step 2: Build and run full test suite**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add Roam/ContentView.swift
git commit -m "feat: add foreground catch — attempt capture on app open"
```

### Task 6: Add capture status diagnostic to Settings

**Files:**
- Modify: `Roam/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Add "Capture Status" section**

Add a `@Query` for the most recent confirmed NightLog and a new section to the Form. Insert this section between "Capture Schedule" and "Data":

```swift
// Add to SettingsView properties:
@Query(
    filter: #Predicate<NightLog> {
        $0.statusRaw != "unresolved"
    },
    sort: \NightLog.capturedAt,
    order: .reverse
) private var confirmedLogs: [NightLog]

// Add this section after "Capture Schedule" section:
Section("Capture Status") {
    if let latest = confirmedLogs.first {
        LabeledContent("Last capture") {
            VStack(alignment: .trailing) {
                Text(latest.capturedAt.formatted(date: .abbreviated, time: .shortened))
                if let city = latest.city {
                    Text(city)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    } else {
        LabeledContent("Last capture", value: "None yet")
    }
    LabeledContent("Next scheduled") {
        Text(nextScheduledTime)
    }
}

// Add this computed property:
private var nextScheduledTime: String {
    let hour = settings.primaryCheckHour
    let minute = settings.primaryCheckMinute
    let time = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
    return "Tonight, \(time.formatted(date: .omitted, time: .shortened))"
}
```

- [ ] **Step 2: Build and run full test suite**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Settings/SettingsView.swift
git commit -m "feat: add capture status diagnostic to Settings"
```

### Task 7: Regenerate Xcode project and final verification

**Files:**
- Modify: `Roam.xcodeproj/project.pbxproj` (via xcodegen)

- [ ] **Step 1: Regenerate project**

Run: `xcodegen generate`

New files (`CaptureResultSaver.swift`, `SignificantLocationService.swift`, test files) need to be picked up by the project.

- [ ] **Step 2: Build and run full test suite**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E '(Executed|TEST SUCCEEDED|TEST FAILED)'`
Expected: All tests PASS (31 existing + 10 new = 41+ tests)

- [ ] **Step 3: Commit**

```bash
git add Roam.xcodeproj/project.pbxproj
git commit -m "chore: regenerate Xcode project with new service files"
```
