# Fix Unresolved Banner Counting Future Nights — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent the "X nights need your input" banner from showing entries for nights that haven't happened yet (today or future).

**Architecture:** Two-sided fix. Read side: filter `unresolvedLogs` in `ContentView` to exclude entries dated >= today. Write side: guard `BackgroundTaskService.handleCapture` with `isInCaptureWindow` so late-firing background tasks don't create entries for the wrong date.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `Roam/ContentView.swift` | Add date guard to `unresolvedLogs` filter |
| Modify | `Roam/Services/BackgroundTaskService.swift` | Add capture window guard to `handleCapture` |
| Create | `RoamTests/UnresolvedFilterTests.swift` | Test unresolved filter excludes today/future |

---

### Task 1: Create feature branch

- [ ] **Step 1: Create and switch to feature branch**

```bash
git checkout -b fix/unresolved-banner-future-night
```

---

### Task 2: Test unresolved filter excludes today-dated entries

**Files:**
- Create: `RoamTests/UnresolvedFilterTests.swift`

The filter logic in `ContentView` uses `@Query` and computed properties, which can't be unit tested directly. Extract the filter logic into a static function that can be tested independently.

- [ ] **Step 1: Write failing tests**

Create `RoamTests/UnresolvedFilterTests.swift`:

```swift
import XCTest
@testable import Roam

final class UnresolvedFilterTests: XCTestCase {

    // MARK: - actionableUnresolvedLogs tests

    func testExcludesTodayDatedUnresolved() {
        let today = noonUTC(2026, 3, 19)
        let todayLog = makeLog(date: today, status: .unresolved)
        let result = UnresolvedFilter.actionable([todayLog], today: today)
        XCTAssertTrue(result.isEmpty, "Today's unresolved entry should be excluded")
    }

    func testExcludesFutureDatedUnresolved() {
        let today = noonUTC(2026, 3, 19)
        let futureLog = makeLog(date: noonUTC(2026, 3, 20), status: .unresolved)
        let result = UnresolvedFilter.actionable([futureLog], today: today)
        XCTAssertTrue(result.isEmpty, "Future unresolved entry should be excluded")
    }

    func testIncludesYesterdayDatedUnresolved() {
        let today = noonUTC(2026, 3, 19)
        let yesterdayLog = makeLog(date: noonUTC(2026, 3, 18), status: .unresolved)
        let result = UnresolvedFilter.actionable([yesterdayLog], today: today)
        XCTAssertEqual(result.count, 1, "Yesterday's unresolved entry should be included")
    }

    func testExcludesConfirmedEntries() {
        let today = noonUTC(2026, 3, 19)
        let confirmedLog = makeLog(date: noonUTC(2026, 3, 17), status: .confirmed)
        let result = UnresolvedFilter.actionable([confirmedLog], today: today)
        XCTAssertTrue(result.isEmpty, "Confirmed entries should be excluded")
    }

    func testMixedEntries() {
        let today = noonUTC(2026, 3, 19)
        let logs = [
            makeLog(date: noonUTC(2026, 3, 15), status: .unresolved),  // past unresolved — include
            makeLog(date: noonUTC(2026, 3, 16), status: .confirmed),   // confirmed — exclude
            makeLog(date: noonUTC(2026, 3, 19), status: .unresolved),  // today — exclude
            makeLog(date: noonUTC(2026, 3, 20), status: .unresolved),  // future — exclude
        ]
        let result = UnresolvedFilter.actionable(logs, today: today)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.date, noonUTC(2026, 3, 15))
    }

    // MARK: - Helpers

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func makeLog(date: Date, status: LogStatus) -> NightLog {
        NightLog(date: date, status: status)
    }
}
```

- [ ] **Step 2: Regenerate Xcode project to pick up new test file**

```bash
xcodegen generate
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/UnresolvedFilterTests -quiet
```

Expected: FAIL — `UnresolvedFilter` does not exist yet.

---

### Task 3: Implement UnresolvedFilter and update ContentView

**Files:**
- Create: `Roam/Services/UnresolvedFilter.swift`
- Modify: `Roam/ContentView.swift:16-18`

- [ ] **Step 1: Create `Roam/Services/UnresolvedFilter.swift`**

```swift
import Foundation

enum UnresolvedFilter {

    /// Returns unresolved NightLogs that represent completed nights (before today).
    /// `today` should be the current calendar date at noon UTC (from `BackfillService.calendarTodayNoonUTC()`).
    static func actionable(_ logs: [NightLog], today: Date) -> [NightLog] {
        logs.filter { $0.status == .unresolved && $0.date < today }
    }
}
```

- [ ] **Step 2: Regenerate Xcode project to pick up new source file**

```bash
xcodegen generate
```

- [ ] **Step 3: Run tests to verify they pass**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/UnresolvedFilterTests -quiet
```

Expected: All 5 tests PASS.

- [ ] **Step 4: Update `ContentView.unresolvedLogs` to use `UnresolvedFilter`**

In `Roam/ContentView.swift`, replace lines 16-18:

```swift
// BEFORE
private var unresolvedLogs: [NightLog] {
    allLogs.filter { $0.status == .unresolved }
}

// AFTER
private var unresolvedLogs: [NightLog] {
    UnresolvedFilter.actionable(allLogs, today: BackfillService.calendarTodayNoonUTC())
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
git add Roam/Services/UnresolvedFilter.swift RoamTests/UnresolvedFilterTests.swift Roam/ContentView.swift
git commit -m "fix: exclude today/future nights from unresolved banner (closes #15)"
```

---

### Task 4: Guard BackgroundTaskService against late-firing tasks

**Files:**
- Modify: `Roam/Services/BackgroundTaskService.swift:70-117`

- [ ] **Step 1: Add capture window guard to `handleCapture`**

In `Roam/Services/BackgroundTaskService.swift`, add the guard at the top of `handleCapture` (after the label and reschedule lines, before the auth check):

```swift
// BEFORE (line 75-79)
let label = isRetry ? "retry" : "primary"
logger.info("[\(label)] Background capture starting")

// Schedule next primary capture regardless of outcome
schedulePrimaryCapture()

// AFTER
let label = isRetry ? "retry" : "primary"
logger.info("[\(label)] Background capture starting")

// Schedule next primary capture regardless of outcome
schedulePrimaryCapture()

// If the task fired outside the capture window (iOS delayed it past 6 AM),
// skip capture to avoid creating entries for the wrong date.
guard SignificantLocationService.isInCaptureWindow(date: .now) else {
    logger.warning("[\(label)] Outside capture window, skipping")
    task.setTaskCompleted(success: false)
    return
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run all tests**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add Roam/Services/BackgroundTaskService.swift
git commit -m "fix: skip background capture when task fires outside capture window"
```

---

### Task 5: Final verification

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: All tests pass, no regressions.

- [ ] **Step 2: Manual verification in simulator**

Open the app in the simulator. Verify:
- If no past unresolved entries exist, the banner does not appear
- The Timeline view shows today with a dashed border but no unresolved indicator
