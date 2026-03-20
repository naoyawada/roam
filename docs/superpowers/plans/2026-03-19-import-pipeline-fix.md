# Import Pipeline Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three bugs in the import/export pipeline that cause data loss when importing on a fresh install with iCloud sync (#27).

**Architecture:** Single-pass upsert import with a mutable `[DateComponents: NightLog]` dictionary replaces the current `Set<DateComponents>`. Export dedup via a new `DataExportService.deduplicatedLogs()` method reusing `DeduplicationService.statusPriority`. UI updated to show "updated" count.

**Tech Stack:** Swift 6, SwiftData, XCTest

**Spec:** `docs/superpowers/specs/2026-03-19-import-pipeline-fix-design.md`

**Build/test commands:**
```bash
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DataImportServiceTests -quiet
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DataExportTests -quiet
```

---

### Task 1: Make `DeduplicationService.statusPriority` internal

**Files:**
- Modify: `Roam/Services/DeduplicationService.swift:64`

- [ ] **Step 1: Change access level from `private` to `static`**

In `Roam/Services/DeduplicationService.swift`, change line 64 from:

```swift
    private static func statusPriority(_ status: LogStatus) -> Int {
```

to:

```swift
    static func statusPriority(_ status: LogStatus) -> Int {
```

This removes the `private` keyword, making it internal (default access in Swift). The function is already `static`.

- [ ] **Step 2: Build to verify no regressions**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Roam/Services/DeduplicationService.swift
git commit -m "refactor: make DeduplicationService.statusPriority internal for reuse"
```

---

### Task 2: Add `ImportResult.updated` field and update existing tests

**Files:**
- Modify: `Roam/Services/DataImportService.swift:11-14`
- Modify: `RoamTests/DataImportServiceTests.swift` (existing assertions)
- Modify: `Roam/Views/Settings/DataImportView.swift:77-83`

- [ ] **Step 1: Add `updated` field to `ImportResult`**

In `Roam/Services/DataImportService.swift`, change:

```swift
    struct ImportResult {
        let imported: Int
        let skipped: Int
        let malformed: Int
    }
```

to:

```swift
    struct ImportResult {
        let imported: Int
        let updated: Int
        let skipped: Int
        let malformed: Int
    }
```

- [ ] **Step 2: Update the `importFile` return statement**

In the same file, change line 69:

```swift
        return ImportResult(imported: imported, skipped: skipped, malformed: malformed)
```

to:

```swift
        return ImportResult(imported: imported, updated: 0, skipped: skipped, malformed: malformed)
```

(Hardcode `updated: 0` for now — the actual upsert logic comes in Task 4.)

- [ ] **Step 3: Update `importSummary` in `DataImportView.swift`**

In `Roam/Views/Settings/DataImportView.swift`, replace the `importSummary` method:

```swift
    private func importSummary(_ result: DataImportService.ImportResult) -> String {
        var parts = ["\(result.imported) entries imported", "\(result.skipped) skipped (duplicates)"]
        if result.malformed > 0 {
            parts.append("\(result.malformed) malformed rows")
        }
        return parts.joined(separator: ", ")
    }
```

with:

```swift
    private func importSummary(_ result: DataImportService.ImportResult) -> String {
        var parts = ["\(result.imported) entries imported"]
        if result.updated > 0 {
            parts.append("\(result.updated) updated")
        }
        parts.append("\(result.skipped) skipped (duplicates)")
        if result.malformed > 0 {
            parts.append("\(result.malformed) malformed rows")
        }
        return parts.joined(separator: ", ")
    }
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run existing tests**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DataImportServiceTests -quiet`
Expected: All existing tests PASS (the `updated` field is 0 which doesn't affect existing assertions)

- [ ] **Step 6: Commit**

```bash
git add Roam/Services/DataImportService.swift Roam/Views/Settings/DataImportView.swift
git commit -m "feat: add updated count to ImportResult and import summary"
```

---

### Task 3: Write failing tests for import upsert and within-file dedup (Bugs 1 & 2)

**Files:**
- Modify: `RoamTests/DataImportServiceTests.swift`

All tests use the existing `container`/`context` setup and `noonUTC` helper already in the file.

- [ ] **Step 1: Add test for merging into existing unresolved entry**

Add to `RoamTests/DataImportServiceTests.swift` after the existing `testImportCombinesMalformedAndDuplicates` test:

```swift
    // MARK: - Import Upsert (Bug 1)

    func testImportUpdatesExistingUnresolvedEntry() {
        // Pre-insert an unresolved entry for Jan 15
        let existing = NightLog(
            date: noonUTC(2026, 1, 15),
            capturedAt: noonUTC(2026, 1, 15),
            source: .automatic,
            status: .unresolved
        )
        context.insert(existing)
        try! context.save()
        let originalID = existing.id

        let json = """
[{"date": "2026-01-15T12:00:00Z", "city": "Austin", "state": "TX", "country": "US", "source": "automatic", "status": "confirmed", "captured_at": "2026-01-15T02:00:00Z"}]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(result.malformed, 0)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].city, "Austin")
        XCTAssertEqual(logs[0].state, "TX")
        XCTAssertEqual(logs[0].country, "US")
        XCTAssertEqual(logs[0].status, .confirmed)
        XCTAssertEqual(logs[0].source, .manual)
        XCTAssertEqual(logs[0].id, originalID) // UUID preserved
    }

    func testImportDoesNotOverwriteConfirmedEntry() {
        // Pre-insert a confirmed entry for Jan 15
        let existing = NightLog(
            date: noonUTC(2026, 1, 15),
            city: "Austin",
            state: "TX",
            country: "US",
            capturedAt: noonUTC(2026, 1, 15),
            source: .automatic,
            status: .confirmed
        )
        context.insert(existing)
        try! context.save()

        let json = """
[{"date": "2026-01-15T12:00:00Z", "city": "NYC", "state": "NY", "country": "US", "source": "automatic", "status": "confirmed", "captured_at": "2026-01-15T02:00:00Z"}]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.malformed, 0)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].city, "Austin") // original preserved
    }

    func testImportSkipsUnresolvedWhenIncomingHasNoCity() {
        // Pre-insert an unresolved entry
        let existing = NightLog(
            date: noonUTC(2026, 1, 15),
            capturedAt: noonUTC(2026, 1, 15),
            source: .automatic,
            status: .unresolved
        )
        context.insert(existing)
        try! context.save()

        let json = """
[{"date": "2026-01-15T12:00:00Z", "source": "automatic", "status": "unresolved", "captured_at": "2026-01-15T02:00:00Z"}]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.malformed, 0)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs[0].status, .unresolved) // unchanged
    }
```

- [ ] **Step 2: Add test for within-file dedup**

Add below the previous tests:

```swift
    // MARK: - Within-File Dedup (Bug 2)

    func testImportDedupesWithinFile() {
        let json = """
[
    {"date": "2026-01-15T12:00:00Z", "city": "Austin", "state": "TX", "country": "US", "source": "automatic", "status": "confirmed", "captured_at": "2026-01-15T02:00:00Z"},
    {"date": "2026-01-15T12:00:00Z", "city": "NYC", "state": "NY", "country": "US", "source": "manual", "status": "manual", "captured_at": "2026-01-15T12:00:00Z"}
]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.malformed, 0)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].city, "Austin") // first entry wins
    }

    func testImportNormalizesNonNoonDates() {
        // Import a date that is already noon UTC — should match an existing entry at noon UTC
        let existing = NightLog(
            date: noonUTC(2026, 1, 15),
            capturedAt: noonUTC(2026, 1, 15),
            source: .automatic,
            status: .unresolved
        )
        context.insert(existing)
        try! context.save()

        // The date in the JSON is noon UTC, matching the existing entry
        let json = """
[{"date": "2026-01-15T12:00:00Z", "city": "Austin", "state": "TX", "country": "US", "source": "automatic", "status": "confirmed", "captured_at": "2026-01-15T02:00:00Z"}]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.malformed, 0)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].city, "Austin")
    }
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DataImportServiceTests -quiet`
Expected: `testImportUpdatesExistingUnresolvedEntry` FAILS (updated is 0, not 1). `testImportDedupesWithinFile` FAILS (logs.count is 2, not 1). Other new tests may fail similarly.

- [ ] **Step 4: Commit failing tests**

```bash
git add RoamTests/DataImportServiceTests.swift
git commit -m "test: add failing tests for import upsert and within-file dedup (#27)"
```

---

### Task 4: Implement import upsert and within-file dedup (Bugs 1 & 2)

**Files:**
- Modify: `Roam/Services/DataImportService.swift:30-69`

- [ ] **Step 1: Replace the import loop with upsert logic**

In `Roam/Services/DataImportService.swift`, replace the entire `importFile` method body (lines 30-69) with:

```swift
    static func importFile(content: String, format: ImportFormat, into context: ModelContext) -> ImportResult {
        let (entries, malformed) = switch format {
        case .csv: parseCSV(content)
        case .json: parseJSON(content)
        }

        let existingLogs = (try? context.fetch(FetchDescriptor<NightLog>())) ?? []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var existingEntries: [DateComponents: NightLog] = [:]
        for log in existingLogs {
            let comps = cal.dateComponents([.year, .month, .day], from: log.date)
            // If multiple exist for same date, keep the best one for our lookup
            if let current = existingEntries[comps] {
                if DeduplicationService.statusPriority(log.status) < DeduplicationService.statusPriority(current.status) {
                    existingEntries[comps] = log
                }
            } else {
                existingEntries[comps] = log
            }
        }

        var imported = 0
        var updated = 0
        var skipped = 0

        for entry in entries {
            let normalizedDate = DateNormalization.normalizedNightDate(from: entry.date)
            let dateComps = cal.dateComponents([.year, .month, .day], from: normalizedDate)

            if let existing = existingEntries[dateComps] {
                // Date already seen — check if we should update
                if existing.status == .unresolved && entry.city != nil {
                    existing.city = entry.city
                    existing.state = entry.state
                    existing.country = entry.country
                    existing.latitude = entry.latitude
                    existing.longitude = entry.longitude
                    existing.horizontalAccuracy = entry.horizontalAccuracy
                    existing.capturedAt = entry.capturedAt ?? .now
                    existing.source = .manual
                    existing.status = .confirmed
                    updated += 1
                } else {
                    skipped += 1
                }
                continue
            }

            let log = NightLog(
                date: normalizedDate,
                city: entry.city,
                state: entry.state,
                country: entry.country,
                latitude: entry.latitude,
                longitude: entry.longitude,
                capturedAt: entry.capturedAt ?? .now,
                horizontalAccuracy: entry.horizontalAccuracy,
                source: .manual,
                status: .confirmed
            )
            context.insert(log)
            existingEntries[dateComps] = log
            imported += 1
        }

        try? context.save()
        return ImportResult(imported: imported, updated: updated, skipped: skipped, malformed: malformed)
    }
```

Key changes from the original:
- `existingDates: Set` → `existingEntries: [DateComponents: NightLog]` dictionary
- 3-way branch: insert / update-unresolved / skip
- `existingEntries[dateComps] = log` after insert (fixes within-file dedup)
- When building initial dictionary from DB, if multiple exist for same date, keep the one with best status priority

- [ ] **Step 2: Run all import tests**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DataImportServiceTests -quiet`
Expected: ALL tests PASS (existing + new)

- [ ] **Step 3: Build the full project**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Roam/Services/DataImportService.swift
git commit -m "fix: import upserts unresolved entries and dedupes within-file (#27)"
```

---

### Task 5: Write failing tests for export dedup (Bug 3)

**Files:**
- Modify: `RoamTests/DataExportTests.swift`

- [ ] **Step 1: Add export dedup tests**

Add to `RoamTests/DataExportTests.swift` before the `// MARK: - Helpers` section:

```swift
    // MARK: - Export Dedup

    func testDeduplicatedLogsKeepsBestPerDate() {
        let date = noonUTC(2026, 1, 15)
        let confirmed = NightLog(
            date: date,
            city: "Austin",
            state: "TX",
            country: "US",
            capturedAt: date,
            source: .automatic,
            status: .confirmed
        )
        let unresolved = NightLog(
            date: date,
            capturedAt: date,
            source: .automatic,
            status: .unresolved
        )

        let result = DataExportService.deduplicatedLogs([unresolved, confirmed])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].city, "Austin")
        XCTAssertEqual(result[0].status, .confirmed)
    }

    func testDeduplicatedLogsPreservesUniqueEntries() {
        let log1 = NightLog(
            date: noonUTC(2026, 1, 15),
            city: "Austin",
            capturedAt: noonUTC(2026, 1, 15),
            source: .automatic,
            status: .confirmed
        )
        let log2 = NightLog(
            date: noonUTC(2026, 1, 16),
            city: "NYC",
            capturedAt: noonUTC(2026, 1, 16),
            source: .automatic,
            status: .confirmed
        )

        let result = DataExportService.deduplicatedLogs([log1, log2])

        XCTAssertEqual(result.count, 2)
    }

    func testDeduplicatedLogsSortsByDate() {
        let log1 = NightLog(
            date: noonUTC(2026, 1, 16),
            city: "NYC",
            capturedAt: noonUTC(2026, 1, 16)
        )
        let log2 = NightLog(
            date: noonUTC(2026, 1, 15),
            city: "Austin",
            capturedAt: noonUTC(2026, 1, 15)
        )

        let result = DataExportService.deduplicatedLogs([log1, log2])

        XCTAssertEqual(result[0].city, "Austin")
        XCTAssertEqual(result[1].city, "NYC")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DataExportTests -quiet`
Expected: FAIL — `deduplicatedLogs` method does not exist

- [ ] **Step 3: Commit failing tests**

```bash
git add RoamTests/DataExportTests.swift
git commit -m "test: add failing tests for export dedup (#27)"
```

---

### Task 6: Implement export dedup and wire into view (Bug 3)

**Files:**
- Modify: `Roam/Services/DataExportService.swift`
- Modify: `Roam/Views/Settings/DataExportView.swift:26-31`

- [ ] **Step 1: Add `deduplicatedLogs` to `DataExportService`**

In `Roam/Services/DataExportService.swift`, add before the closing `}` of the enum:

```swift

    static func deduplicatedLogs(_ logs: [NightLog]) -> [NightLog] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let grouped = Dictionary(grouping: logs) {
            cal.dateComponents([.year, .month, .day], from: $0.date)
        }

        return grouped.values.map { group in
            group.sorted { a, b in
                let aPriority = DeduplicationService.statusPriority(a.status)
                let bPriority = DeduplicationService.statusPriority(b.status)
                if aPriority != bPriority {
                    return aPriority < bPriority
                }
                return a.capturedAt > b.capturedAt
            }.first!
        }.sorted { $0.date < $1.date }
    }
```

- [ ] **Step 2: Run export tests**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DataExportTests -quiet`
Expected: ALL tests PASS

- [ ] **Step 3: Wire dedup into `DataExportView.filteredLogs`**

In `Roam/Views/Settings/DataExportView.swift`, replace:

```swift
    private var filteredLogs: [NightLog] {
        guard let year = filterYear else { return Array(allLogs) }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return allLogs.filter { cal.component(.year, from: $0.date) == year }
    }
```

with:

```swift
    private var filteredLogs: [NightLog] {
        let logs: [NightLog]
        if let year = filterYear {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            logs = allLogs.filter { cal.component(.year, from: $0.date) == year }
        } else {
            logs = Array(allLogs)
        }
        return DataExportService.deduplicatedLogs(logs)
    }
```

- [ ] **Step 4: Build the full project**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run all tests**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: ALL tests PASS

- [ ] **Step 6: Commit**

```bash
git add Roam/Services/DataExportService.swift Roam/Views/Settings/DataExportView.swift
git commit -m "fix: export deduplicates entries by date, keeping best per date (#27)"
```

---

### Task 7: Final verification

**Files:** None (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: ALL tests PASS

- [ ] **Step 2: Verify no unintended changes**

Run: `git diff HEAD` to confirm no uncommitted changes remain.

Run: `git log --oneline -7` to confirm the commit history looks clean.
