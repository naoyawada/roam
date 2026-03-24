# Local Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 8 types of local push notifications that fire from the existing VisitPipeline when entries are committed.

**Architecture:** Event-driven NotificationService receives entry-committed events from VisitPipeline, evaluates trigger conditions in priority order, deduplicates via UserDefaults date-keys, and schedules via a `NotificationScheduling` protocol (wrapping `UNUserNotificationCenter` in production, mock in tests). Monthly recap uses `UNCalendarNotificationTrigger` rescheduled on each foreground.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, UserNotifications framework, Swift Testing + XCTest

**Spec:** `docs/superpowers/specs/2026-03-24-local-notifications-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `Roam/Services/NotificationScheduling.swift` | **Create** | Protocol wrapping `UNUserNotificationCenter` + production conformance |
| `Roam/Services/NotificationService.swift` | **Create** | All notification decision logic, dedup, scheduling, copy |
| `Roam/Models/UserSettings.swift` | **Modify** | Add 8 per-type toggle fields, change `notificationsEnabled` default to `false` |
| `Roam/Services/VisitPipeline.swift` | **Modify** | Change `upsertEntry` return type, add NotificationService dependency + call sites |
| `Roam/Views/Settings/SettingsView.swift` | **Modify** | Add Notifications section with master + per-type toggles |
| `Roam/RoamApp.swift` | **Modify** | Initialize NotificationService, wire to pipeline, schedule monthly recap on foreground |
| `RoamTests/NotificationServiceTests.swift` | **Create** | All notification trigger, dedup, priority, and toggle tests |

---

## Review Checkpoints

**Checkpoint 1** — after Tasks 1-3: Foundation is in place (protocol, settings, core service scaffolding). Build and run tests before continuing.

**Checkpoint 2** — after Tasks 4-7: All 8 notification types implemented and tested. Build and run full test suite.

**Checkpoint 3** — after Tasks 8-10: Pipeline integration, Settings UI, and app wiring complete. Build and run full test suite. Feature is functionally complete.

---

## Task 1: NotificationScheduling Protocol + Mock

**Files:**
- Create: `Roam/Services/NotificationScheduling.swift`
- Create: `RoamTests/NotificationServiceTests.swift` (initial scaffolding with mock)

- [ ] **Step 1: Create the protocol file**

```swift
// Roam/Services/NotificationScheduling.swift
import Foundation
import UserNotifications

@MainActor
protocol NotificationScheduling {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

extension UNUserNotificationCenter: @retroactive NotificationScheduling {}
```

- [ ] **Step 2: Create the test file with MockNotificationCenter**

```swift
// RoamTests/NotificationServiceTests.swift
import XCTest
import SwiftData
import UserNotifications
@testable import Roam

@MainActor
final class MockNotificationCenter: NotificationScheduling {
    var addedRequests: [UNNotificationRequest] = []
    var pendingRequests: [UNNotificationRequest] = []
    var removedPendingIdentifiers: [String] = []
    var removedDeliveredIdentifiers: [String] = []
    var authorizationGranted = true

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(contentsOf: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(contentsOf: identifiers)
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationGranted
    }
}
```

- [ ] **Step 3: Build to verify protocol compiles and UNUserNotificationCenter conforms**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Roam/Services/NotificationScheduling.swift RoamTests/NotificationServiceTests.swift
git commit -m "feat: add NotificationScheduling protocol and MockNotificationCenter"
```

---

## Task 2: UserSettings Extensions

**Files:**
- Modify: `Roam/Models/UserSettings.swift`

- [ ] **Step 1: Add 8 per-type toggle fields and change notificationsEnabled default**

The current `UserSettings.swift` has `notificationsEnabled: Bool = true`. Change its default to `false` and add the 8 new fields. The init also needs updating.

```swift
// Roam/Models/UserSettings.swift
import Foundation
import SwiftData

@Model
final class UserSettings {
    var homeCityKey: String?
    var hasCompletedOnboarding: Bool = false
    var notificationsEnabled: Bool = false

    // Per-type notification toggles (active when notificationsEnabled is true)
    var notifyNewCity: Bool = true
    var notifyWelcomeBack: Bool = true
    var notifyWelcomeHome: Bool = true
    var notifyStreakMilestone: Bool = true
    var notifyTravelDay: Bool = true
    var notifyTripSummary: Bool = true
    var notifyMonthlyRecap: Bool = true
    var notifyNewYear: Bool = true

    // MARK: - Legacy (kept for SettingsView compat, will be removed in Task 11/14)
    var primaryCheckHour: Int = 2
    var primaryCheckMinute: Int = 0
    var retryCheckHour: Int = 5
    var retryCheckMinute: Int = 0

    init(
        homeCityKey: String? = nil,
        hasCompletedOnboarding: Bool = false,
        notificationsEnabled: Bool = false
    ) {
        self.homeCityKey = homeCityKey
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationsEnabled = notificationsEnabled
    }
}
```

- [ ] **Step 2: Build to verify SwiftData model compiles with new fields**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Models/UserSettings.swift
git commit -m "feat: add per-type notification toggles to UserSettings"
```

---

## Task 3: NotificationService Core Scaffolding

**Files:**
- Create: `Roam/Services/NotificationService.swift`
- Modify: `RoamTests/NotificationServiceTests.swift`

This task builds the service shell with dedup logic and the `handleEntryCommitted` entry point. No individual notification types yet — those come in Tasks 4-7.

- [ ] **Step 1: Write failing tests for dedup and propagated-entry skip**

Add to `RoamTests/NotificationServiceTests.swift`:

```swift
@MainActor
final class NotificationServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var mockCenter: MockNotificationCenter!
    var service: NotificationService!

    override func setUp() async throws {
        let schema = Schema([DailyEntry.self, CityRecord.self, UserSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        // Create settings with notifications enabled
        let settings = UserSettings(notificationsEnabled: true)
        context.insert(settings)
        try context.save()

        mockCenter = MockNotificationCenter()
        service = NotificationService(modelContainer: container, notificationCenter: mockCenter)
    }

    override func tearDown() {
        // Clean up dedup keys
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("notif-") }
        keys.forEach { defaults.removeObject(forKey: $0) }
    }

    func testPropagatedEntriesSkipped() async {
        let entry = makeEntry(city: "Portland", region: "OR", country: "US", source: .propagated)
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: false)

        XCTAssertTrue(mockCenter.addedRequests.isEmpty, "Propagated entries should not fire notifications")
    }

    func testNotificationsDisabledSkipsAll() async {
        // Disable master toggle
        let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
        settings.notificationsEnabled = false
        try! context.save()

        let entry = makeEntry(city: "Portland", region: "OR", country: "US")
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: false)

        XCTAssertTrue(mockCenter.addedRequests.isEmpty, "Disabled master toggle should skip all")
    }

    func testDeduplication() async {
        let entry = makeEntry(city: "Denver", region: "CO", country: "US")
        context.insert(entry)
        try! context.save()

        // Fire twice for the same entry
        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: false)
        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: false)

        XCTAssertEqual(mockCenter.addedRequests.count, 1, "Dedup should prevent second notification")
    }

    // MARK: - Helpers

    func makeEntry(
        city: String,
        region: String,
        country: String,
        date: Date? = nil,
        source: EntrySource = .visit,
        confidence: EntryConfidence = .high,
        isTravelDay: Bool = false,
        citiesVisitedJSON: String = "[]"
    ) -> DailyEntry {
        let entry = DailyEntry()
        entry.date = date ?? noonUTC(2026, 3, 24)
        entry.primaryCity = city
        entry.primaryRegion = region
        entry.primaryCountry = country
        entry.source = source
        entry.confidence = confidence
        entry.isTravelDay = isTravelDay
        entry.citiesVisitedJSON = citiesVisitedJSON
        entry.createdAt = Date()
        entry.updatedAt = Date()
        return entry
    }

    func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/NotificationServiceTests -quiet`
Expected: FAIL (NotificationService not defined)

- [ ] **Step 3: Implement NotificationService core**

```swift
// Roam/Services/NotificationService.swift
import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationService {
    private let modelContainer: ModelContainer
    private let notificationCenter: NotificationScheduling

    init(modelContainer: ModelContainer, notificationCenter: NotificationScheduling) {
        self.modelContainer = modelContainer
        self.notificationCenter = notificationCenter
    }

    func handleEntryCommitted(entry: DailyEntry, previousCityKey: String?, isNewEntry: Bool, isNewCity: Bool) async {
        let context = ModelContext(modelContainer)

        // Gate: master toggle
        guard let settings = try? context.fetch(FetchDescriptor<UserSettings>()).first,
              settings.notificationsEnabled else { return }

        // Gate: skip propagated entries
        if entry.source == .propagated { return }

        // Prune old dedup keys (>30 days)
        pruneOldDedupKeys()

        // Evaluate notification types in priority order
        let dateString = dedupDateString(for: entry.date)

        // Priority 1-6 evaluated here (Tasks 4-7 will add the actual evaluations)
        // Each type returns a UNNotificationRequest? — first non-nil wins
        let evaluators: [() -> UNNotificationRequest?] = [
            // Will be populated in Tasks 4-7
        ]

        for evaluate in evaluators {
            if let request = evaluate() {
                // Check dedup
                let dedupKey = request.identifier
                guard !isDuplicate(key: dedupKey) else { return }
                markFired(key: dedupKey)
                try? await notificationCenter.add(request)
                return
            }
        }
    }

    // MARK: - Deduplication

    private func isDuplicate(key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) != nil
    }

    private func markFired(key: String) {
        UserDefaults.standard.set(Date(), forKey: key)
    }

    private func dedupDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private func pruneOldDedupKeys() {
        let defaults = UserDefaults.standard
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let allKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("notif-") }
        for key in allKeys {
            if let date = defaults.object(forKey: key) as? Date, date < cutoff {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/NotificationServiceTests -quiet`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/NotificationService.swift RoamTests/NotificationServiceTests.swift
git commit -m "feat: add NotificationService core with dedup and gating logic"
```

---

## **>> REVIEW CHECKPOINT 1 <<**

Build the full project and run all tests before continuing:

```bash
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: BUILD SUCCEEDED, all existing tests still pass, 3 new NotificationService tests pass.

---

## Task 4: Welcome Home + Trip Summary Notifications

**Files:**
- Modify: `Roam/Services/NotificationService.swift`
- Modify: `RoamTests/NotificationServiceTests.swift`

These are priority 1 and 2, and mutually exclusive: Welcome Home fires for exactly 1 day away, Trip Summary for 2+ days away.

- [ ] **Step 1: Write failing tests**

Add to `NotificationServiceTests`:

```swift
func testWelcomeHomeNotification() async {
    // Set up home city
    let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
    settings.homeCityKey = "Portland|OR|US"
    try! context.save()

    // Yesterday was away
    let yesterday = makeEntry(city: "Seattle", region: "WA", country: "US", date: noonUTC(2026, 3, 23))
    context.insert(yesterday)
    try! context.save()

    // Today: back home (1 day away)
    let entry = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, 24))
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Seattle|WA|US", isNewEntry: true, isNewCity: false)

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    XCTAssertTrue(mockCenter.addedRequests.first?.content.body.contains("Welcome home") == true)
}

func testTripSummaryNotification() async {
    let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
    settings.homeCityKey = "Portland|OR|US"
    try! context.save()

    // 3 days away in Denver
    for day in 21...23 {
        let away = makeEntry(city: "Denver", region: "CO", country: "US", date: noonUTC(2026, 3, day))
        context.insert(away)
    }
    try! context.save()

    // Today: back home (3 days away → trip summary, not welcome home)
    let entry = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, 24))
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Denver|CO|US", isNewEntry: true, isNewCity: false)

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    XCTAssertTrue(mockCenter.addedRequests.first?.content.body.contains("Back from") == true)
}

func testWelcomeHomeVsTripSummaryMutualExclusion() async {
    let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
    settings.homeCityKey = "Portland|OR|US"
    try! context.save()

    // 2 days away → should be Trip Summary (not Welcome Home)
    for day in 22...23 {
        let away = makeEntry(city: "Denver", region: "CO", country: "US", date: noonUTC(2026, 3, day))
        context.insert(away)
    }
    try! context.save()

    let entry = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, 24))
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Denver|CO|US", isNewEntry: true, isNewCity: false)

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    let body = mockCenter.addedRequests.first?.content.body ?? ""
    XCTAssertTrue(body.contains("Back from"), "2+ days away should trigger Trip Summary, got: \(body)")
    XCTAssertFalse(body.contains("Welcome home"), "Welcome Home should not fire for 2+ days away")
}

func testWelcomeHomeNoOpWithoutHomeCity() async {
    // No home city set
    let entry = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, 24))
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Seattle|WA|US", isNewEntry: true, isNewCity: false)

    // Should NOT fire welcome home (no home city). Might fire New City instead.
    let welcomeHome = mockCenter.addedRequests.filter { $0.content.body.contains("Welcome home") }
    XCTAssertTrue(welcomeHome.isEmpty, "Welcome Home should no-op without home city")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/NotificationServiceTests -quiet`
Expected: FAIL

- [ ] **Step 3: Implement Welcome Home and Trip Summary evaluators**

Add these private methods to `NotificationService` and wire them into the `evaluators` array in `handleEntryCommitted`:

```swift
// In handleEntryCommitted, replace the empty evaluators array with:
let evaluators: [() -> UNNotificationRequest?] = [
    { self.evaluateWelcomeHome(entry: entry, settings: settings, dateString: dateString, context: context) },
    { self.evaluateTripSummary(entry: entry, settings: settings, dateString: dateString, context: context) },
    // Tasks 5-7 will add more here
]

// MARK: - Welcome Home (Priority 1)

private func evaluateWelcomeHome(entry: DailyEntry, settings: UserSettings, dateString: String, context: ModelContext) -> UNNotificationRequest? {
    guard settings.notifyWelcomeHome,
          let homeCityKey = settings.homeCityKey,
          entry.cityKey == homeCityKey else { return nil }

    let daysAway = countConsecutiveDaysAway(before: entry.date, homeCityKey: homeCityKey, context: context)
    guard daysAway == 1 else { return nil }

    let content = UNMutableNotificationContent()
    content.title = "Roam"
    content.body = "Welcome home. Good to be back."
    content.sound = .default
    content.threadIdentifier = "welcomeHome"
    return UNNotificationRequest(identifier: "notif-welcomeHome-\(dateString)", content: content, trigger: nil)
}

// MARK: - Trip Summary (Priority 2)

private func evaluateTripSummary(entry: DailyEntry, settings: UserSettings, dateString: String, context: ModelContext) -> UNNotificationRequest? {
    guard settings.notifyTripSummary,
          let homeCityKey = settings.homeCityKey,
          entry.cityKey == homeCityKey else { return nil }

    let daysAway = countConsecutiveDaysAway(before: entry.date, homeCityKey: homeCityKey, context: context)
    guard daysAway >= 2 else { return nil }

    // Get trip count for enrichment
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let year = cal.component(.year, from: entry.date)
    let analytics = AnalyticsService(context: context)
    let tripInfo = analytics.tripCount(year: year, homeCityKey: homeCityKey)

    let content = UNMutableNotificationContent()
    content.title = "Roam"
    // Find the most-visited away city during this trip for the copy
    let tripCityName = lastAwayCityName(before: entry.date, homeCityKey: homeCityKey, context: context)
    let tripCityDisplay = tripCityName ?? "your trip"
    content.body = "Back from \(daysAway) days away — your \(ordinal(tripInfo.count)) trip to \(tripCityDisplay) this year."
    content.sound = .default
    content.threadIdentifier = "tripSummary"
    return UNNotificationRequest(identifier: "notif-tripSummary-\(dateString)", content: content, trigger: nil)
}

// MARK: - Helpers

private func countConsecutiveDaysAway(before date: Date, homeCityKey: String, context: ModelContext) -> Int {
    let descriptor = FetchDescriptor<DailyEntry>(
        predicate: #Predicate<DailyEntry> { $0.date < date },
        sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    guard let entries = try? context.fetch(descriptor) else { return 0 }
    var count = 0
    for entry in entries {
        if entry.cityKey == homeCityKey { break }
        count += 1
    }
    return count
}

private func lastAwayCityName(before date: Date, homeCityKey: String, context: ModelContext) -> String? {
    let descriptor = FetchDescriptor<DailyEntry>(
        predicate: #Predicate<DailyEntry> { $0.date < date },
        sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    guard let entries = try? context.fetch(descriptor) else { return nil }
    // Return the most recent away city (first non-home entry)
    for entry in entries {
        if entry.cityKey == homeCityKey { break }
        return CityDisplayFormatter.format(city: entry.primaryCity, state: entry.primaryRegion, country: entry.primaryCountry)
    }
    return nil
}

private func ordinal(_ n: Int) -> String {
    let suffix: String
    let ones = n % 10
    let tens = (n / 10) % 10
    if tens == 1 {
        suffix = "th"
    } else {
        switch ones {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
    }
    return "\(n)\(suffix)"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/NotificationServiceTests -quiet`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/NotificationService.swift RoamTests/NotificationServiceTests.swift
git commit -m "feat: add Welcome Home and Trip Summary notification types"
```

---

## Task 5: New City + Welcome Back Notifications

**Files:**
- Modify: `Roam/Services/NotificationService.swift`
- Modify: `RoamTests/NotificationServiceTests.swift`

Priority 3 (New City) and 4 (Welcome Back). New City fires when no CityRecord exists. Welcome Back fires when CityRecord exists and city is not home.

- [ ] **Step 1: Write failing tests**

```swift
func testNewCityNotification() async {
    // Denver is a new city (flag passed from pipeline)
    let entry = makeEntry(city: "Denver", region: "CO", country: "US")
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: true)

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    let body = mockCenter.addedRequests.first?.content.body ?? ""
    XCTAssertTrue(body.contains("First time in"), "Expected new city notification, got: \(body)")
}

func testWelcomeBackNotification() async {
    // Create CityRecord for Denver (visited before)
    let record = CityRecord()
    record.cityName = "Denver"
    record.region = "CO"
    record.country = "US"
    record.totalDays = 3
    context.insert(record)
    try! context.save()

    let entry = makeEntry(city: "Denver", region: "CO", country: "US")
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: false)

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    let body = mockCenter.addedRequests.first?.content.body ?? ""
    XCTAssertTrue(body.contains("Welcome back"), "Expected welcome back notification, got: \(body)")
}

func testWelcomeBackDoesNotFireForHomeCity() async {
    let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
    settings.homeCityKey = "Portland|OR|US"
    try! context.save()

    // CityRecord exists for Portland (home)
    let record = CityRecord()
    record.cityName = "Portland"
    record.region = "OR"
    record.country = "US"
    record.totalDays = 50
    context.insert(record)
    try! context.save()

    let entry = makeEntry(city: "Portland", region: "OR", country: "US")
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Denver|CO|US", isNewEntry: true, isNewCity: false)

    // Should fire Welcome Home, not Welcome Back
    let welcomeBack = mockCenter.addedRequests.filter { $0.content.body.contains("Welcome back") }
    XCTAssertTrue(welcomeBack.isEmpty, "Welcome Back should not fire for home city")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/NotificationServiceTests -quiet`
Expected: FAIL

- [ ] **Step 3: Implement New City and Welcome Back evaluators**

Add to `NotificationService` and wire into the evaluators array (after Trip Summary):

```swift
// Add to evaluators array in handleEntryCommitted:
{ self.evaluateNewCity(entry: entry, settings: settings, dateString: dateString, isNewCity: isNewCity) },
{ self.evaluateWelcomeBack(entry: entry, settings: settings, dateString: dateString, previousCityKey: previousCityKey, isNewCity: isNewCity, context: context) },

// MARK: - New City (Priority 3)

private func evaluateNewCity(entry: DailyEntry, settings: UserSettings, dateString: String, isNewCity: Bool) -> UNNotificationRequest? {
    guard settings.notifyNewCity, isNewCity else { return nil }

    let displayName = CityDisplayFormatter.format(city: entry.primaryCity, state: entry.primaryRegion, country: entry.primaryCountry)
    let content = UNMutableNotificationContent()
    content.title = "Roam"
    content.body = "First time in \(displayName)! Welcome."
    content.sound = .default
    content.threadIdentifier = "newCity"
    return UNNotificationRequest(identifier: "notif-newCity-\(dateString)", content: content, trigger: nil)
}

// MARK: - Welcome Back (Priority 4)

private func evaluateWelcomeBack(entry: DailyEntry, settings: UserSettings, dateString: String, previousCityKey: String?, isNewCity: Bool, context: ModelContext) -> UNNotificationRequest? {
    guard settings.notifyWelcomeBack,
          !isNewCity,  // Must be a previously visited city
          previousCityKey != entry.cityKey,
          entry.cityKey != settings.homeCityKey else { return nil }

    // Fetch CityRecord for visit count enrichment
    let cityName = entry.primaryCity
    let region = entry.primaryRegion
    let country = entry.primaryCountry
    let descriptor = FetchDescriptor<CityRecord>(
        predicate: #Predicate<CityRecord> {
            $0.cityName == cityName && $0.region == region && $0.country == country
        }
    )
    guard let record = try? context.fetch(descriptor).first else { return nil }

    let displayName = CityDisplayFormatter.format(city: entry.primaryCity, state: entry.primaryRegion, country: entry.primaryCountry)
    let visitCount = record.totalDays + 1  // Including this visit
    let content = UNMutableNotificationContent()
    content.title = "Roam"
    content.body = "Welcome back to \(displayName)! Your \(ordinal(visitCount)) visit."
    content.sound = .default
    content.threadIdentifier = "welcomeBack"
    return UNNotificationRequest(identifier: "notif-welcomeBack-\(dateString)", content: content, trigger: nil)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/NotificationServiceTests -quiet`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/NotificationService.swift RoamTests/NotificationServiceTests.swift
git commit -m "feat: add New City and Welcome Back notification types"
```

---

## Task 6: Travel Day + Streak Milestone Notifications

**Files:**
- Modify: `Roam/Services/NotificationService.swift`
- Modify: `RoamTests/NotificationServiceTests.swift`

Priority 5 (Travel Day) and 6 (Streak Milestone).

- [ ] **Step 1: Write failing tests**

```swift
func testTravelDayNotification() async {
    let entry = makeEntry(
        city: "Seattle",
        region: "WA",
        country: "US",
        isTravelDay: true,
        citiesVisitedJSON: "[{\"city\":\"Portland\",\"region\":\"OR\",\"country\":\"US\"},{\"city\":\"Seattle\",\"region\":\"WA\",\"country\":\"US\"}]"
    )
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: false)

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    let body = mockCenter.addedRequests.first?.content.body ?? ""
    XCTAssertTrue(body.contains("Travel day"), "Expected travel day notification, got: \(body)")
}

func testStreakMilestoneNotification() async {
    // Build a 7-day streak in Portland
    for day in 18...24 {
        let e = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, day))
        context.insert(e)
    }
    try! context.save()

    let targetDate = noonUTC(2026, 3, 24)
    let entry = try! context.fetch(
        FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { $0.date == targetDate }
        )
    ).first!

    // The streak evaluator checks currentStreak, which should be 7
    await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: false, isNewCity: false)

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    let body = mockCenter.addedRequests.first?.content.body ?? ""
    XCTAssertTrue(body.contains("streak") || body.contains("7 days"), "Expected streak notification, got: \(body)")
}

func testStreakDoesNotFireAtNonMilestone() async {
    // Build a 5-day streak (not a milestone)
    for day in 20...24 {
        let e = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, day))
        context.insert(e)
    }
    try! context.save()

    let targetDate = noonUTC(2026, 3, 24)
    let entry = try! context.fetch(
        FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { $0.date == targetDate }
        )
    ).first!

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: false, isNewCity: false)

    let streakNotifs = mockCenter.addedRequests.filter { $0.content.body.lowercased().contains("streak") }
    XCTAssertTrue(streakNotifs.isEmpty, "5 days is not a milestone — should not fire streak notification")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/NotificationServiceTests -quiet`
Expected: FAIL

- [ ] **Step 3: Implement Travel Day and Streak Milestone evaluators**

```swift
// Add to evaluators array:
{ self.evaluateTravelDay(entry: entry, settings: settings, dateString: dateString) },
{ self.evaluateStreakMilestone(entry: entry, settings: settings, dateString: dateString, context: context) },

// MARK: - Travel Day (Priority 5)

private func evaluateTravelDay(entry: DailyEntry, settings: UserSettings, dateString: String) -> UNNotificationRequest? {
    guard settings.notifyTravelDay, entry.isTravelDay else { return nil }

    // Parse citiesVisitedJSON for departure/arrival
    var body = "Travel day."
    if let data = entry.citiesVisitedJSON.data(using: .utf8),
       let cities = try? JSONDecoder().decode([[String: String]].self, from: data),
       cities.count >= 2,
       let first = cities.first?["city"],
       let last = cities.last?["city"] {
        body = "Travel day: \(first) → \(last)."
    }

    let content = UNMutableNotificationContent()
    content.title = "Roam"
    content.body = body
    content.sound = .default
    content.threadIdentifier = "travelDay"
    return UNNotificationRequest(identifier: "notif-travelDay-\(dateString)", content: content, trigger: nil)
}

// MARK: - Streak Milestone (Priority 6)

private static let streakMilestones: Set<Int> = [7, 14, 30, 60, 90]

private func evaluateStreakMilestone(entry: DailyEntry, settings: UserSettings, dateString: String, context: ModelContext) -> UNNotificationRequest? {
    guard settings.notifyStreakMilestone else { return nil }

    let analytics = AnalyticsService(context: context)
    let streak = analytics.currentStreak(asOf: entry.date)
    guard Self.streakMilestones.contains(streak.days) else { return nil }

    let displayName = CityDisplayFormatter.format(city: entry.primaryCity, state: entry.primaryRegion, country: entry.primaryCountry)
    let content = UNMutableNotificationContent()
    content.title = "Roam"
    content.body = "\(streak.days) days in \(displayName) — nice streak."
    content.sound = .default
    content.threadIdentifier = "streakMilestone"
    return UNNotificationRequest(identifier: "notif-streak-\(dateString)-\(streak.days)", content: content, trigger: nil)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/NotificationServiceTests -quiet`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/NotificationService.swift RoamTests/NotificationServiceTests.swift
git commit -m "feat: add Travel Day and Streak Milestone notification types"
```

---

## Task 7: New Year Milestone + Monthly Recap + Priority Test

**Files:**
- Modify: `Roam/Services/NotificationService.swift`
- Modify: `RoamTests/NotificationServiceTests.swift`

New Year is reactive (entry-driven). Monthly Recap uses `UNCalendarNotificationTrigger`. Also adds the priority order test.

- [ ] **Step 1: Write failing tests**

```swift
func testNewYearNotification() async {
    // Last entry of 2025
    let dec31 = makeEntry(city: "Tokyo", region: "Tokyo", country: "JP", date: noonUTC(2025, 12, 31))
    context.insert(dec31)
    try! context.save()

    // First entry of 2026
    let jan1 = makeEntry(city: "Tokyo", region: "Tokyo", country: "JP", date: noonUTC(2026, 1, 1))
    context.insert(jan1)
    try! context.save()

    await service.handleEntryCommitted(entry: jan1, previousCityKey: "Tokyo|Tokyo|JP", isNewEntry: true, isNewCity: false)

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    let body = mockCenter.addedRequests.first?.content.body ?? ""
    XCTAssertTrue(body.contains("First city of 2026"), "Expected new year notification, got: \(body)")
}

func testNewYearNoOpForFirstTimeUser() async {
    // No prior entries at all
    let entry = makeEntry(city: "Denver", region: "CO", country: "US", date: noonUTC(2026, 1, 1))
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: false)

    // Should fire New City, not New Year
    let newYear = mockCenter.addedRequests.filter { $0.content.body.contains("First city of") }
    XCTAssertTrue(newYear.isEmpty, "New year should not fire for first-time user with no prior entries")
}

func testMonthlyRecapScheduling() async {
    // Insert some data for March
    for day in 1...20 {
        let e = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, day))
        context.insert(e)
    }
    try! context.save()

    let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
    settings.homeCityKey = "Portland|OR|US"
    try! context.save()

    await service.scheduleMonthlyRecap()

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    let request = mockCenter.addedRequests.first!
    XCTAssertEqual(request.identifier, "notif-monthlyRecap")
    XCTAssertNotNil(request.trigger as? UNCalendarNotificationTrigger)
}

func testPriorityOrder() async {
    // Set up a scenario where both New City AND Travel Day could trigger
    // New City is priority 3, Travel Day is priority 5 → New City should win
    let entry = makeEntry(
        city: "Denver",
        region: "CO",
        country: "US",
        isTravelDay: true,
        citiesVisitedJSON: "[{\"city\":\"Portland\",\"region\":\"OR\",\"country\":\"US\"},{\"city\":\"Denver\",\"region\":\"CO\",\"country\":\"US\"}]"
    )
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: true)

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    let body = mockCenter.addedRequests.first?.content.body ?? ""
    XCTAssertTrue(body.contains("First time in"), "New City (priority 3) should win over Travel Day (priority 5), got: \(body)")
}

func testToggleRespected() async {
    // Disable new city toggle specifically
    let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
    settings.notifyNewCity = false
    try! context.save()

    let entry = makeEntry(city: "Denver", region: "CO", country: "US")
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: true)

    // New City is disabled and isNewCity is true, so Welcome Back won't fire (isNewCity blocks it).
    // No other type triggers either. No notification should fire.
    XCTAssertTrue(mockCenter.addedRequests.isEmpty, "Disabled toggle should suppress that type")
}

func testCatchupOnlyNotifiesToday() async {
    // Simulate catchup: entries for past dates should not trigger notifications.
    // The NotificationService itself doesn't enforce this — the pipeline does
    // by only calling handleEntryCommitted for today. But we can verify that
    // if the service IS called for a past entry, dedup works per date.
    let pastEntry = makeEntry(city: "Denver", region: "CO", country: "US", date: noonUTC(2026, 3, 20))
    context.insert(pastEntry)
    let todayEntry = makeEntry(city: "Seattle", region: "WA", country: "US", date: noonUTC(2026, 3, 24))
    context.insert(todayEntry)
    try! context.save()

    // Only today's entry should produce a notification (pipeline contract)
    await service.handleEntryCommitted(entry: todayEntry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: true)

    XCTAssertEqual(mockCenter.addedRequests.count, 1)
    let body = mockCenter.addedRequests.first?.content.body ?? ""
    XCTAssertTrue(body.contains("Seattle") || body.contains("First time"), "Notification should be for today's city")
}

func testMultiDateVisitSingleNotification() async {
    // When a visit spans multiple dates, only one notification should fire.
    // This is enforced by the pipeline (aggregateDates fires for last date only).
    // We verify that calling handleEntryCommitted once = one notification.
    let entry = makeEntry(city: "Denver", region: "CO", country: "US")
    context.insert(entry)
    try! context.save()

    await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: true)

    XCTAssertEqual(mockCenter.addedRequests.count, 1, "Single handleEntryCommitted call should produce at most one notification")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/NotificationServiceTests -quiet`
Expected: FAIL

- [ ] **Step 3: Implement New Year evaluator and Monthly Recap scheduler**

Add to `NotificationService`:

```swift
// New Year is evaluated OUTSIDE the priority array (it doesn't compete).
// Add this check in handleEntryCommitted, after the priority loop but before returning:
// Also evaluate new year (does not compete with entry-driven priority types)
if let request = evaluateNewYear(entry: entry, settings: settings, context: context) {
    let dedupKey = request.identifier
    if !isDuplicate(key: dedupKey) {
        markFired(key: dedupKey)
        try? await notificationCenter.add(request)
    }
}

// MARK: - New Year Milestone

private func evaluateNewYear(entry: DailyEntry, settings: UserSettings, context: ModelContext) -> UNNotificationRequest? {
    guard settings.notifyNewYear else { return nil }

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let entryYear = cal.component(.year, from: entry.date)

    // Find the most recent entry before this one
    let entryDate = entry.date
    var descriptor = FetchDescriptor<DailyEntry>(
        predicate: #Predicate<DailyEntry> { $0.date < entryDate },
        sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    descriptor.fetchLimit = 1
    guard let previousEntry = try? context.fetch(descriptor).first else { return nil } // No prior entries → no-op
    let previousYear = cal.component(.year, from: previousEntry.date)

    guard entryYear > previousYear else { return nil }

    let displayName = CityDisplayFormatter.format(city: entry.primaryCity, state: entry.primaryRegion, country: entry.primaryCountry)
    let content = UNMutableNotificationContent()
    content.title = "Roam"
    content.body = "First city of \(entryYear): \(displayName). Happy new year."
    content.sound = .default
    content.threadIdentifier = "newYear"
    return UNNotificationRequest(identifier: "notif-newYear-\(entryYear)", content: content, trigger: nil)
}

// MARK: - Monthly Recap Scheduling

func scheduleMonthlyRecap() async {
    let context = ModelContext(modelContainer)
    guard let settings = try? context.fetch(FetchDescriptor<UserSettings>()).first,
          settings.notificationsEnabled,
          settings.notifyMonthlyRecap else { return }

    // Cancel existing
    notificationCenter.removePendingNotificationRequests(withIdentifiers: ["notif-monthlyRecap"])

    // Compute stats for previous month
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let now = Date()
    let currentMonth = cal.component(.month, from: now)
    let currentYear = cal.component(.year, from: now)
    let prevMonth = currentMonth == 1 ? 12 : currentMonth - 1
    let prevYear = currentMonth == 1 ? currentYear - 1 : currentYear

    let analytics = AnalyticsService(context: context)
    let breakdown = analytics.monthlyBreakdown(year: prevYear)
    guard prevMonth >= 1, prevMonth <= 12 else { return }
    let monthData = breakdown[prevMonth - 1]
    let uniqueCities = monthData.cityDays.count
    let monthName = cal.monthSymbols[prevMonth - 1]

    // Count travel days for the specific month by fetching entries directly
    let monthStart = cal.date(from: DateComponents(year: prevYear, month: prevMonth, day: 1, hour: 0))!
    let monthEnd = cal.date(from: DateComponents(year: prevMonth == 12 ? prevYear + 1 : prevYear, month: prevMonth == 12 ? 1 : prevMonth + 1, day: 1, hour: 0))!
    let monthDescriptor = FetchDescriptor<DailyEntry>(
        predicate: #Predicate<DailyEntry> {
            $0.date >= monthStart && $0.date < monthEnd
        }
    )
    let monthEntries = (try? context.fetch(monthDescriptor)) ?? []
    let travelDays = monthEntries.filter { $0.isTravelDay }.count
    let totalMonthDays = monthEntries.count

    var bodyParts = ["\(monthName): \(uniqueCities) \(uniqueCities == 1 ? "city" : "cities")"]
    if travelDays > 0 {
        bodyParts.append("\(travelDays) travel \(travelDays == 1 ? "day" : "days")")
    }
    if let homeCityKey = settings.homeCityKey, totalMonthDays > 0 {
        let homeDays = monthEntries.filter { $0.cityKey == homeCityKey }.count
        let awayPct = Int(Double(totalMonthDays - homeDays) / Double(totalMonthDays) * 100)
        if awayPct > 0 {
            bodyParts.append("\(awayPct)% away")
        }
    }

    let content = UNMutableNotificationContent()
    content.title = "Roam"
    content.body = bodyParts.joined(separator: ", ") + "."
    content.sound = .default
    content.threadIdentifier = "monthlyRecap"

    // Schedule for 1st of next month at 9 AM local
    var triggerComponents = DateComponents()
    triggerComponents.day = 1
    triggerComponents.hour = 9
    triggerComponents.minute = 0
    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

    let request = UNNotificationRequest(identifier: "notif-monthlyRecap", content: content, trigger: trigger)
    try? await notificationCenter.add(request)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/NotificationServiceTests -quiet`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/NotificationService.swift RoamTests/NotificationServiceTests.swift
git commit -m "feat: add New Year, Monthly Recap, priority order, and toggle tests"
```

---

## **>> REVIEW CHECKPOINT 2 <<**

All 8 notification types are now implemented. Build the full project and run all tests:

```bash
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: BUILD SUCCEEDED, all tests pass. Review the complete `NotificationService.swift` for correctness before proceeding to pipeline integration.

---

## Task 8: VisitPipeline Integration

**Files:**
- Modify: `Roam/Services/VisitPipeline.swift`

Changes: (1) Add `NotificationService?` dependency, (2) modify `upsertEntry` to return `UpsertResult` with `oldCityKey` and `wasInsert`, (3) call `handleEntryCommitted` from `aggregateDates` and `runCatchup`, (4) detect `isNewCity` by checking CityRecord **before** `updateCityRecord` creates it.

- [ ] **Step 1: Add NotificationService dependency to VisitPipeline**

In `VisitPipeline.swift`, add the property and update init:

```swift
private let notificationService: NotificationService?

init(modelContainer: ModelContainer, logger: PipelineLogger, notificationService: NotificationService? = nil) {
    self.modelContainer = modelContainer
    self.logger = logger
    self.notificationService = notificationService
}
```

- [ ] **Step 2: Change upsertEntry return type**

Change the return type from `String?` to a tuple. Update the existing method:

```swift
private struct UpsertResult {
    let oldCityKey: String?
    let wasInsert: Bool
}

@discardableResult
private func upsertEntry(_ entry: DailyEntry, context: ModelContext) -> UpsertResult {
    let targetDate = entry.date
    let descriptor = FetchDescriptor<DailyEntry>(
        predicate: #Predicate<DailyEntry> { $0.date == targetDate }
    )
    var oldCityKey: String? = nil
    var wasInsert = false
    if let existing = try? context.fetch(descriptor).first {
        if existing.primaryCity != entry.primaryCity || existing.primaryRegion != entry.primaryRegion {
            oldCityKey = existing.cityKey
        }
        existing.primaryCity = entry.primaryCity
        existing.primaryRegion = entry.primaryRegion
        existing.primaryCountry = entry.primaryCountry
        existing.primaryLatitude = entry.primaryLatitude
        existing.primaryLongitude = entry.primaryLongitude
        existing.isTravelDay = entry.isTravelDay
        existing.citiesVisitedJSON = entry.citiesVisitedJSON
        existing.totalVisitHours = entry.totalVisitHours
        existing.sourceRaw = entry.sourceRaw
        existing.confidenceRaw = entry.confidenceRaw
        existing.updatedAt = Date()
    } else {
        wasInsert = true
        context.insert(entry)
    }
    try? context.save()
    return UpsertResult(oldCityKey: oldCityKey, wasInsert: wasInsert)
}
```

- [ ] **Step 3: Update all callers of upsertEntry**

Update `aggregateDates` to fire notifications for the **last** affected date only:

```swift
private func aggregateDates(for visit: RawVisit, context: ModelContext) {
    let affectedDates = determineDates(for: visit)
    var lastEntry: DailyEntry?
    var lastResult: UpsertResult?
    var lastOldCityKey: String?
    var lastIsNewCity = false
    for date in affectedDates {
        let allVisits = fetchVisits(for: date, context: context)
        if let entry = aggregator.aggregate(visits: allVisits, for: date) {
            let result = upsertEntry(entry, context: context)
            // Check if this is a new city BEFORE updateCityRecord creates the CityRecord
            let isNewCity = !cityRecordExists(for: entry, context: context)
            updateCityRecord(for: entry, context: context)
            if let oldKey = result.oldCityKey {
                decrementCityRecord(cityKey: oldKey, context: context)
            }
            lastEntry = entry
            lastResult = result
            lastIsNewCity = isNewCity
            if result.oldCityKey != nil {
                lastOldCityKey = result.oldCityKey
            }
        }
    }
    // Fire notification only for the last (most recent) affected date
    if let entry = lastEntry, let result = lastResult {
        Task {
            await notificationService?.handleEntryCommitted(
                entry: entry,
                previousCityKey: lastOldCityKey,
                isNewEntry: result.wasInsert,
                isNewCity: lastIsNewCity
            )
        }
    }
}

/// Check if a CityRecord already exists for this entry's city (before creating one).
private func cityRecordExists(for entry: DailyEntry, context: ModelContext) -> Bool {
    let cityName = entry.primaryCity
    let region = entry.primaryRegion
    let country = entry.primaryCountry
    let descriptor = FetchDescriptor<CityRecord>(
        predicate: #Predicate<CityRecord> {
            $0.cityName == cityName && $0.region == region && $0.country == country
        }
    )
    return ((try? context.fetch(descriptor))?.isEmpty == false)
}
```

Update `runCatchup` — only notify for today's date. In the today-aggregation block (around line 117-124), add the notification call:

```swift
// For today: only aggregate if we have actual RawVisit data (no propagation)
let todayVisits = fetchVisits(for: today, context: context)
if !todayVisits.isEmpty {
    if let entry = aggregator.aggregate(visits: todayVisits, for: today) {
        let result = upsertEntry(entry, context: context)
        let isNewCity = !cityRecordExists(for: entry, context: context)
        updateCityRecord(for: entry, context: context)
        await logger.log(category: "aggregation", event: "entry_created",
                       detail: "today: \(entry.primaryCity)", dailyEntryID: entry.id)
        // Only fire notifications for today's entries during catchup
        await notificationService?.handleEntryCommitted(
            entry: entry,
            previousCityKey: result.oldCityKey,
            isNewEntry: result.wasInsert,
            isNewCity: isNewCity
        )
    }
}
```

Also update the other `upsertEntry` call sites in `runCatchup` to use the new return type (lines 80, 90, 108). These are for past dates, so no notification call — just destructure the result:

```swift
let _ = upsertEntry(entry, context: context)
// becomes:
upsertEntry(entry, context: context)
```

(The `@discardableResult` attribute allows this.)

- [ ] **Step 4: Build and run existing tests to verify nothing broke**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Roam/Services/VisitPipeline.swift
git commit -m "feat: integrate NotificationService into VisitPipeline"
```

---

## Task 9: Settings UI — Notifications Section

**Files:**
- Modify: `Roam/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Add Notifications section to SettingsView**

Insert a new section between "Appearance" and "Tracking Status" in `SettingsView.body`. Add state for permission tracking:

```swift
// Add state property:
@State private var systemNotificationsdenied = false

// Add section after the "Appearance" Section and before "Tracking Status":
Section("Notifications") {
    Toggle("Notifications", isOn: Binding(
        get: { settings.notificationsEnabled },
        set: { newValue in
            settings.notificationsEnabled = newValue
            try? context.save()
            if newValue {
                Task {
                    let center = UNUserNotificationCenter.current()
                    let granted = try? await center.requestAuthorization(options: [.alert, .sound])
                    if granted == false {
                        await MainActor.run {
                            systemNotificationsdenied = true
                        }
                    }
                }
            }
        }
    ))

    if systemNotificationsdenied {
        Text("Notifications are disabled in System Settings.")
            .font(.caption)
            .foregroundStyle(.secondary)
        Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        .font(.caption)
    }

    if settings.notificationsEnabled {
        Toggle("New City", isOn: Binding(
            get: { settings.notifyNewCity },
            set: { settings.notifyNewCity = $0; try? context.save() }
        ))
        Toggle("Welcome Back", isOn: Binding(
            get: { settings.notifyWelcomeBack },
            set: { settings.notifyWelcomeBack = $0; try? context.save() }
        ))
        Toggle("Welcome Home", isOn: Binding(
            get: { settings.notifyWelcomeHome },
            set: { settings.notifyWelcomeHome = $0; try? context.save() }
        ))
        Toggle("Streak Milestones", isOn: Binding(
            get: { settings.notifyStreakMilestone },
            set: { settings.notifyStreakMilestone = $0; try? context.save() }
        ))
        Toggle("Travel Day", isOn: Binding(
            get: { settings.notifyTravelDay },
            set: { settings.notifyTravelDay = $0; try? context.save() }
        ))
        Toggle("Trip Summary", isOn: Binding(
            get: { settings.notifyTripSummary },
            set: { settings.notifyTripSummary = $0; try? context.save() }
        ))
        Toggle("Monthly Recap", isOn: Binding(
            get: { settings.notifyMonthlyRecap },
            set: { settings.notifyMonthlyRecap = $0; try? context.save() }
        ))
        Toggle("New Year", isOn: Binding(
            get: { settings.notifyNewYear },
            set: { settings.notifyNewYear = $0; try? context.save() }
        ))
    }
}
```

Also add `import UserNotifications` at the top of the file.

- [ ] **Step 2: Build to verify UI compiles**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Views/Settings/SettingsView.swift
git commit -m "feat: add Notifications section to Settings with per-type toggles"
```

---

## Task 10: RoamApp Wiring

**Files:**
- Modify: `Roam/RoamApp.swift`

Wire up NotificationService: create it in init, pass to VisitPipeline, schedule monthly recap on foreground.

- [ ] **Step 1: Add NotificationService to RoamApp**

In `RoamApp`, add a property and update init + foreground handler:

```swift
// Add property:
let notificationService: NotificationService

// In init(), after creating the pipeline (line 67-68), create NotificationService:
let notifService = NotificationService(
    modelContainer: modelContainer,
    notificationCenter: UNUserNotificationCenter.current()
)
notificationService = notifService

// Update pipeline creation to pass notificationService:
let pipeline = VisitPipeline(modelContainer: modelContainer, logger: logger, notificationService: notifService)

// In the .onChange(of: scenePhase) block, after the existing Task, add monthly recap scheduling:
// Inside the `if newPhase == .active` block, add:
Task { @MainActor in
    await notificationService.scheduleMonthlyRecap()
}
```

Also add `import UserNotifications` at the top.

- [ ] **Step 2: Build and run all tests**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet && xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED, all tests pass

- [ ] **Step 3: Commit**

```bash
git add Roam/RoamApp.swift
git commit -m "feat: wire NotificationService into RoamApp with monthly recap scheduling"
```

---

## **>> REVIEW CHECKPOINT 3 <<**

Feature is functionally complete. Run full build + test suite:

```bash
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Review the full diff against the spec to verify all requirements are met:

```bash
git diff main..HEAD --stat
git log main..HEAD --oneline
```

Expected: ~7 commits, 2 new files created, 4 existing files modified, all tests passing.

---

## Task 11: Final Verification

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

- [ ] **Step 2: Verify all spec requirements are met**

Check against the spec checklist:
- [ ] NotificationService schedules local UNUserNotificationCenter notifications from the pipeline
- [ ] All notification categories are off by default (master toggle defaults to false)
- [ ] Each category can be toggled independently in Settings
- [ ] Notification permission is requested on first toggle-on in Settings
- [ ] Deduplication prevents re-firing for the same day
- [ ] Unit tests cover trigger-condition logic for each notification type
- [ ] Propagated entries are skipped
- [ ] Priority order is enforced (only highest-priority type fires)
- [ ] Welcome Home (1 day) and Trip Summary (2+ days) are mutually exclusive
- [ ] Monthly recap scheduled on foreground with repeats: false
- [ ] Catchup only notifies for today's date

- [ ] **Step 3: Clean build to ensure no warnings**

```bash
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "warning:|error:"
```
