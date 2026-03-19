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

        let d1confirmed = NightLog(date: date1, city: "Atlanta", status: .confirmed)
        let d1unresolved = NightLog(date: date1, status: .unresolved)

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
