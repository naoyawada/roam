import XCTest
import SwiftData
@testable import Roam

@MainActor
final class DeduplicationServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([DailyEntry.self, CityRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    // MARK: - DailyEntry deduplication

    func testNoDuplicateDailyEntries_noChanges() {
        let e1 = makeDailyEntry(date: noonUTC(2026, 3, 15), city: "Atlanta", updatedAt: date(hour: 2))
        let e2 = makeDailyEntry(date: noonUTC(2026, 3, 16), city: "Asheville", updatedAt: date(hour: 3))
        context.insert(e1)
        context.insert(e2)
        try! context.save()

        DeduplicationService.deduplicateDailyEntries(context: context)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 2)
    }

    func testTwoDuplicateDailyEntries_keepsMostRecentUpdatedAt() {
        let d = noonUTC(2026, 3, 15)
        let older = makeDailyEntry(date: d, city: "Atlanta", updatedAt: date(hour: 2))
        let newer = makeDailyEntry(date: d, city: "Atlanta", updatedAt: date(hour: 5))
        context.insert(older)
        context.insert(newer)
        try! context.save()

        DeduplicationService.deduplicateDailyEntries(context: context)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].updatedAt, newer.updatedAt)
    }

    func testThreeDuplicateDailyEntries_keepsOnlyMostRecent() {
        let d = noonUTC(2026, 3, 15)
        let e1 = makeDailyEntry(date: d, city: "Atlanta", updatedAt: date(hour: 1))
        let e2 = makeDailyEntry(date: d, city: "Atlanta", updatedAt: date(hour: 3))
        let e3 = makeDailyEntry(date: d, city: "Atlanta", updatedAt: date(hour: 6))
        context.insert(e1)
        context.insert(e2)
        context.insert(e3)
        try! context.save()

        DeduplicationService.deduplicateDailyEntries(context: context)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].updatedAt, e3.updatedAt)
    }

    func testMixedDuplicateAndUniqueDates_correctCount() {
        let d1 = noonUTC(2026, 3, 15)
        let d2 = noonUTC(2026, 3, 16)
        let e1a = makeDailyEntry(date: d1, city: "Atlanta", updatedAt: date(hour: 2))
        let e1b = makeDailyEntry(date: d1, city: "Atlanta", updatedAt: date(hour: 5))
        let e2 = makeDailyEntry(date: d2, city: "Asheville", updatedAt: date(hour: 3))
        context.insert(e1a)
        context.insert(e1b)
        context.insert(e2)
        try! context.save()

        DeduplicationService.deduplicateDailyEntries(context: context)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].date, d1)
        XCTAssertEqual(entries[0].updatedAt, e1b.updatedAt)
        XCTAssertEqual(entries[1].date, d2)
    }

    // MARK: - CityRecord deduplication

    func testNoDuplicateCityRecords_noChanges() {
        let r1 = makeCityRecord(key: "Atlanta|GA|US", colorIndex: 0)
        let r2 = makeCityRecord(key: "Asheville|NC|US", colorIndex: 1)
        context.insert(r1)
        context.insert(r2)
        try! context.save()

        DeduplicationService.deduplicateCityRecords(context: context)

        let records = try! context.fetch(FetchDescriptor<CityRecord>())
        XCTAssertEqual(records.count, 2)
    }

    func testDuplicateCityRecords_keepsLowestColorIndex() {
        let r1 = makeCityRecord(key: "Atlanta|GA|US", colorIndex: 3)
        let r2 = makeCityRecord(key: "Atlanta|GA|US", colorIndex: 0)
        context.insert(r1)
        context.insert(r2)
        try! context.save()

        DeduplicationService.deduplicateCityRecords(context: context)

        let records = try! context.fetch(FetchDescriptor<CityRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].colorIndex, 0)
    }

    func testThreeDuplicateCityRecords_keepsLowest() {
        let r1 = makeCityRecord(key: "Atlanta|GA|US", colorIndex: 5)
        let r2 = makeCityRecord(key: "Atlanta|GA|US", colorIndex: 2)
        let r3 = makeCityRecord(key: "Atlanta|GA|US", colorIndex: 0)
        context.insert(r1)
        context.insert(r2)
        context.insert(r3)
        try! context.save()

        DeduplicationService.deduplicateCityRecords(context: context)

        let records = try! context.fetch(FetchDescriptor<CityRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].colorIndex, 0)
    }

    // MARK: - Helpers

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func date(hour: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: 2026, month: 3, day: 16, hour: hour))!
    }

    private func makeDailyEntry(date: Date, city: String, updatedAt: Date) -> DailyEntry {
        let entry = DailyEntry()
        entry.date = date
        entry.primaryCity = city
        entry.primaryRegion = ""
        entry.primaryCountry = "US"
        entry.createdAt = updatedAt
        entry.updatedAt = updatedAt
        return entry
    }

    private func makeCityRecord(key: String, colorIndex: Int) -> CityRecord {
        let parts = key.split(separator: "|")
        let record = CityRecord()
        record.cityName = parts.count > 0 ? String(parts[0]) : ""
        record.region = parts.count > 1 ? String(parts[1]) : ""
        record.country = parts.count > 2 ? String(parts[2]) : ""
        record.colorIndex = colorIndex
        return record
    }
}
