# NightLog Deduplication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove duplicate NightLog entries created by CloudKit sync so analytics show correct counts.

**Architecture:** A `DeduplicationService` runs on every app launch (in `ContentView.task`), groups NightLogs by date, keeps the best entry per priority rule (confirmed > manual > unresolved, then most recent capturedAt), and deletes the rest.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `Roam/Services/DeduplicationService.swift` | Dedup logic: group by date, keep best, delete rest |
| Create | `RoamTests/DeduplicationServiceTests.swift` | Unit tests with in-memory SwiftData container |
| Modify | `Roam/ContentView.swift:80-84` | Add dedup call in `.task` |

---

### Task 1: Create feature branch

- [ ] **Step 1: Create and switch to feature branch**

```bash
git checkout -b fix/nightlog-deduplication
```

---

### Task 2: Write failing tests for DeduplicationService

**Files:**
- Create: `RoamTests/DeduplicationServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Create `RoamTests/DeduplicationServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Roam

@MainActor
final class DeduplicationServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([NightLog.self, CityColor.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    func testNoDuplicates_noChanges() {
        let log1 = NightLog(date: noonUTC(2026, 3, 15), city: "Atlanta", status: .confirmed)
        let log2 = NightLog(date: noonUTC(2026, 3, 16), city: "Atlanta", status: .confirmed)
        context.insert(log1)
        context.insert(log2)
        try! context.save()

        DeduplicationService.deduplicateNightLogs(context: context)

        let logs = try! context.fetch(FetchDescriptor<NightLog>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(logs.count, 2)
    }

    func testTwoConfirmedSameDate_keepsMostRecentCapturedAt() {
        let date = noonUTC(2026, 3, 15)
        let older = NightLog(date: date, city: "Atlanta", capturedAt: captureDate(2026, 3, 16, hour: 2), status: .confirmed)
        let newer = NightLog(date: date, city: "Atlanta", capturedAt: captureDate(2026, 3, 16, hour: 5), status: .confirmed)
        context.insert(older)
        context.insert(newer)
        try! context.save()

        DeduplicationService.deduplicateNightLogs(context: context)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].capturedAt, newer.capturedAt)
    }

    func testConfirmedBeatsUnresolved() {
        let date = noonUTC(2026, 3, 15)
        let unresolved = NightLog(date: date, status: .unresolved)
        let confirmed = NightLog(date: date, city: "Atlanta", status: .confirmed)
        context.insert(unresolved)
        context.insert(confirmed)
        try! context.save()

        DeduplicationService.deduplicateNightLogs(context: context)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].status, .confirmed)
        XCTAssertEqual(logs[0].city, "Atlanta")
    }

    func testManualBeatsUnresolved() {
        let date = noonUTC(2026, 3, 15)
        let unresolved = NightLog(date: date, status: .unresolved)
        let manual = NightLog(date: date, city: "Asheville", status: .manual)
        context.insert(unresolved)
        context.insert(manual)
        try! context.save()

        DeduplicationService.deduplicateNightLogs(context: context)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].status, .manual)
        XCTAssertEqual(logs[0].city, "Asheville")
    }

    func testThreeDuplicates_keepsOnlyOne() {
        let date = noonUTC(2026, 3, 15)
        let log1 = NightLog(date: date, city: "Atlanta", capturedAt: captureDate(2026, 3, 16, hour: 2), status: .confirmed)
        let log2 = NightLog(date: date, city: "Atlanta", capturedAt: captureDate(2026, 3, 16, hour: 3), status: .confirmed)
        let log3 = NightLog(date: date, city: "Atlanta", capturedAt: captureDate(2026, 3, 16, hour: 5), status: .confirmed)
        context.insert(log1)
        context.insert(log2)
        context.insert(log3)
        try! context.save()

        DeduplicationService.deduplicateNightLogs(context: context)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].capturedAt, log3.capturedAt)
    }

    func testMultipleDatesWithMixedDuplicates() {
        let date1 = noonUTC(2026, 3, 15)
        let date2 = noonUTC(2026, 3, 16)

        // Date 1: confirmed + unresolved → keep confirmed
        let d1confirmed = NightLog(date: date1, city: "Atlanta", status: .confirmed)
        let d1unresolved = NightLog(date: date1, status: .unresolved)

        // Date 2: two confirmed → keep most recent capturedAt
        let d2older = NightLog(date: date2, city: "Asheville", capturedAt: captureDate(2026, 3, 17, hour: 2), status: .confirmed)
        let d2newer = NightLog(date: date2, city: "Asheville", capturedAt: captureDate(2026, 3, 17, hour: 5), status: .confirmed)

        context.insert(d1confirmed)
        context.insert(d1unresolved)
        context.insert(d2older)
        context.insert(d2newer)
        try! context.save()

        DeduplicationService.deduplicateNightLogs(context: context)

        let logs = try! context.fetch(FetchDescriptor<NightLog>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs[0].date, date1)
        XCTAssertEqual(logs[0].status, .confirmed)
        XCTAssertEqual(logs[1].date, date2)
        XCTAssertEqual(logs[1].capturedAt, d2newer.capturedAt)
    }

    // MARK: - Helpers

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func captureDate(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
```

- [ ] **Step 2: Regenerate Xcode project**

```bash
xcodegen generate
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DeduplicationServiceTests -quiet
```

Expected: FAIL — `DeduplicationService` does not exist yet.

---

### Task 3: Implement DeduplicationService and wire into ContentView

**Files:**
- Create: `Roam/Services/DeduplicationService.swift`
- Modify: `Roam/ContentView.swift:80-84`

- [ ] **Step 1: Create `Roam/Services/DeduplicationService.swift`**

```swift
import Foundation
import os
import SwiftData

enum DeduplicationService {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "Deduplication")

    /// Remove duplicate NightLog entries that share the same date.
    /// Keeps the best entry per priority: confirmed > manual > unresolved,
    /// then most recent capturedAt as tiebreaker.
    @MainActor
    static func deduplicateNightLogs(context: ModelContext) {
        let allLogs = (try? context.fetch(FetchDescriptor<NightLog>())) ?? []

        let grouped = Dictionary(grouping: allLogs) { $0.date }

        var deletedCount = 0
        for (_, logs) in grouped where logs.count > 1 {
            let sorted = logs.sorted { a, b in
                let aPriority = statusPriority(a.status)
                let bPriority = statusPriority(b.status)
                if aPriority != bPriority {
                    return aPriority < bPriority
                }
                return a.capturedAt > b.capturedAt
            }

            for log in sorted.dropFirst() {
                context.delete(log)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try? context.save()
            logger.info("Deduplicated \(deletedCount) NightLog entries")
        }
    }

    private static func statusPriority(_ status: LogStatus) -> Int {
        switch status {
        case .confirmed: return 0
        case .manual: return 1
        case .unresolved: return 2
        }
    }
}
```

- [ ] **Step 2: Regenerate Xcode project**

```bash
xcodegen generate
```

- [ ] **Step 3: Run tests to verify they pass**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DeduplicationServiceTests -quiet
```

Expected: All 6 tests PASS.

- [ ] **Step 4: Update `ContentView.task` to call dedup**

In `Roam/ContentView.swift`, replace lines 80-84:

```swift
// BEFORE
.task {
    await attemptForegroundCapture()
    BackfillService.backfillMissedNights(context: context)
    assignMissingColors()
}

// AFTER
.task {
    await attemptForegroundCapture()
    BackfillService.backfillMissedNights(context: context)
    DeduplicationService.deduplicateNightLogs(context: context)
    assignMissingColors()
}
```

- [ ] **Step 5: Build to verify compilation**

```bash
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Run all tests**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add Roam/Services/DeduplicationService.swift RoamTests/DeduplicationServiceTests.swift Roam/ContentView.swift
git commit -m "fix: deduplicate NightLog entries after CloudKit sync (closes #17)"
```

---

### Task 4: Final verification

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: All tests pass, no regressions.

- [ ] **Step 2: Manual verification in simulator**

Open the app in the simulator. Verify:
- Dashboard shows correct day counts (not doubled)
- Insights shows correct chart values and highlights
- Longest streak is calculated correctly
