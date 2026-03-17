import XCTest
import SwiftData
@testable import Roam

@MainActor
final class CaptureResultSaverTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([NightLog.self, CityColor.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    func testSaveResult_noExistingEntry_createsConfirmed() {
        let result = makeCaptureResult(city: "Austin", capturedAt: date(2026, 3, 17, hour: 2))
        CaptureResultSaver.save(result: result, context: context)
        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].city, "Austin")
        XCTAssertEqual(logs[0].status, .confirmed)
    }

    func testSaveResult_confirmedExists_doesNotOverwrite() {
        let nightDate = noonUTC(2026, 3, 16)
        let existing = NightLog(date: nightDate, city: "Austin", source: .automatic, status: .confirmed)
        context.insert(existing)
        try! context.save()
        let result = makeCaptureResult(city: "Houston", capturedAt: date(2026, 3, 17, hour: 2))
        CaptureResultSaver.save(result: result, context: context)
        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].city, "Austin")
    }

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

    func testSaveResult_newCity_assignsCityColor() {
        let result = makeCaptureResult(city: "Austin", state: "TX", country: "US", capturedAt: date(2026, 3, 17, hour: 2))
        CaptureResultSaver.save(result: result, context: context)
        let colors = try! context.fetch(FetchDescriptor<CityColor>())
        XCTAssertEqual(colors.count, 1)
        XCTAssertEqual(colors[0].cityKey, "Austin|TX|US")
    }

    private func makeCaptureResult(city: String, state: String? = nil, country: String? = nil, capturedAt: Date) -> CaptureResult {
        CaptureResult(city: city, state: state, country: country, latitude: 30.27, longitude: -97.74, horizontalAccuracy: 10.0, capturedAt: capturedAt)
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
