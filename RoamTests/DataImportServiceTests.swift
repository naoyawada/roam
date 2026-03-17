import XCTest
import SwiftData
@testable import Roam

@MainActor
final class DataImportServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let cloudConfig = ModelConfiguration(
            "cloud",
            schema: Schema([NightLog.self, CityColor.self]),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let localConfig = ModelConfiguration(
            "local",
            schema: Schema([UserSettings.self]),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        container = try ModelContainer(
            for: NightLog.self, CityColor.self, UserSettings.self,
            configurations: cloudConfig, localConfig
        )
        context = container.mainContext
    }

    // MARK: - CSV Parsing

    func testParseValidCSV() {
        let csv = [
            "date,city,state,country,latitude,longitude,source,status,captured_at,accuracy",
            "\"2026-01-15T12:00:00Z\",\"Austin\",\"TX\",\"US\",\"30.2672\",\"-97.7431\",\"automatic\",\"confirmed\",\"2026-01-15T02:00:00Z\",\"50\"",
            "\"2026-01-16T12:00:00Z\",\"NYC\",\"NY\",\"US\",\"40.7128\",\"-74.006\",\"automatic\",\"confirmed\",\"2026-01-16T02:00:00Z\",\"30\"",
            "\"2026-01-17T12:00:00Z\",\"LA\",\"CA\",\"US\",\"34.0522\",\"-118.2437\",\"manual\",\"manual\",\"2026-01-17T12:00:00Z\",\"100\"",
            "\"2026-01-18T12:00:00Z\",\"\",\"\",\"\",\"\",\"\",\"automatic\",\"unresolved\",\"2026-01-18T02:00:00Z\",\"\"",
            "\"2026-01-19T12:00:00Z\",\"Chicago\",\"IL\",\"US\",\"41.8781\",\"-87.6298\",\"automatic\",\"confirmed\",\"2026-01-19T02:00:00Z\",\"25\""
        ].joined(separator: "\n")

        let (entries, malformed) = DataImportService.parseCSV(csv)

        XCTAssertEqual(entries.count, 5)
        XCTAssertEqual(malformed, 0)

        XCTAssertEqual(entries[0].city, "Austin")
        XCTAssertEqual(entries[0].state, "TX")
        XCTAssertEqual(entries[0].country, "US")
        XCTAssertEqual(entries[0].latitude, 30.2672)
        XCTAssertEqual(entries[0].longitude, -97.7431)

        // Empty fields should be nil
        XCTAssertNil(entries[3].city)
        XCTAssertNil(entries[3].latitude)
        XCTAssertNil(entries[3].horizontalAccuracy)
    }

    func testParseCSVWithMalformedRows() {
        let csv = [
            "date,city,state,country,latitude,longitude,source,status,captured_at,accuracy",
            "\"2026-01-15T12:00:00Z\",\"Austin\",\"TX\",\"US\",\"30.2672\",\"-97.7431\",\"automatic\",\"confirmed\",\"2026-01-15T02:00:00Z\",\"50\"",
            "not a valid row",
            "\"bad-date\",\"Austin\",\"TX\",\"US\",\"30\",\"97\",\"auto\",\"confirmed\",\"2026-01-15T02:00:00Z\",\"50\""
        ].joined(separator: "\n")

        let (entries, malformed) = DataImportService.parseCSV(csv)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(malformed, 2)
    }

    func testParseCSVHeaderOnly() {
        let csv = "date,city,state,country,latitude,longitude,source,status,captured_at,accuracy"

        let (entries, malformed) = DataImportService.parseCSV(csv)

        XCTAssertEqual(entries.count, 0)
        XCTAssertEqual(malformed, 0)
    }

    func testParseCSVEmpty() {
        let (entries, malformed) = DataImportService.parseCSV("")

        XCTAssertEqual(entries.count, 0)
        XCTAssertEqual(malformed, 0)
    }

    func testParseCSVWithEscapedQuotes() {
        let csv = [
            "date,city,state,country,latitude,longitude,source,status,captured_at,accuracy",
            "\"2026-01-15T12:00:00Z\",\"City with \"\"quotes\"\"\",\"TX\",\"US\",\"30\",\"97\",\"manual\",\"confirmed\",\"2026-01-15T12:00:00Z\",\"50\""
        ].joined(separator: "\n")

        let (entries, malformed) = DataImportService.parseCSV(csv)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(malformed, 0)
        XCTAssertEqual(entries[0].city, "City with \"quotes\"")
    }

    // MARK: - JSON Parsing

    func testParseValidJSON() {
        let json = """
[
    {
        "date": "2026-01-15T12:00:00Z",
        "city": "Austin",
        "state": "TX",
        "country": "US",
        "latitude": 30.2672,
        "longitude": -97.7431,
        "source": "automatic",
        "status": "confirmed",
        "captured_at": "2026-01-15T02:00:00Z",
        "accuracy": 50.0
    },
    {
        "date": "2026-01-16T12:00:00Z",
        "city": "NYC",
        "state": "NY",
        "country": "US",
        "latitude": 40.7128,
        "longitude": -74.006,
        "source": "automatic",
        "status": "confirmed",
        "captured_at": "2026-01-16T02:00:00Z",
        "accuracy": 30.0
    },
    {
        "date": "2026-01-17T12:00:00Z",
        "source": "automatic",
        "status": "unresolved",
        "captured_at": "2026-01-17T02:00:00Z"
    },
    {
        "date": "2026-01-18T12:00:00Z",
        "city": "Chicago",
        "state": "IL",
        "country": "US",
        "source": "automatic",
        "status": "confirmed",
        "captured_at": "2026-01-18T02:00:00Z"
    },
    {
        "date": "2026-01-19T12:00:00Z",
        "city": "LA",
        "state": "CA",
        "country": "US",
        "latitude": 34.0522,
        "longitude": -118.2437,
        "source": "manual",
        "status": "manual",
        "captured_at": "2026-01-19T12:00:00Z",
        "accuracy": 100.0
    }
]
"""

        let (entries, malformed) = DataImportService.parseJSON(json)

        XCTAssertEqual(entries.count, 5)
        XCTAssertEqual(malformed, 0)

        XCTAssertEqual(entries[0].city, "Austin")
        XCTAssertEqual(entries[0].latitude, 30.2672)

        // Entry with no optional fields
        XCTAssertNil(entries[2].city)
        XCTAssertNil(entries[2].latitude)
    }

    func testParseJSONMissingDate() {
        let json = """
[
    {"city": "Austin", "source": "automatic", "status": "confirmed", "captured_at": "2026-01-15T02:00:00Z"},
    {"date": "2026-01-16T12:00:00Z", "city": "NYC", "source": "automatic", "status": "confirmed", "captured_at": "2026-01-16T02:00:00Z"}
]
"""

        let (entries, malformed) = DataImportService.parseJSON(json)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(malformed, 1)
        XCTAssertEqual(entries[0].city, "NYC")
    }

    func testParseJSONWithExtraKeys() {
        let json = """
[{"date": "2026-01-15T12:00:00Z", "city": "Austin", "source": "auto", "status": "confirmed", "captured_at": "2026-01-15T02:00:00Z", "extra_field": "ignored"}]
"""

        let (entries, malformed) = DataImportService.parseJSON(json)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(malformed, 0)
        XCTAssertEqual(entries[0].city, "Austin")
    }

    func testParseJSONEmpty() {
        let (entries, malformed) = DataImportService.parseJSON("[]")

        XCTAssertEqual(entries.count, 0)
        XCTAssertEqual(malformed, 0)
    }

    // MARK: - Import with Duplicate Detection

    func testImportSkipsDuplicates() {
        // Pre-insert a log for Jan 15
        let existingLog = NightLog(
            date: noonUTC(2026, 1, 15),
            city: "Austin",
            state: "TX",
            country: "US",
            capturedAt: noonUTC(2026, 1, 15)
        )
        context.insert(existingLog)
        try! context.save()

        let csv = [
            "date,city,state,country,latitude,longitude,source,status,captured_at,accuracy",
            "\"2026-01-15T12:00:00Z\",\"NYC\",\"NY\",\"US\",\"40\",\"74\",\"automatic\",\"confirmed\",\"2026-01-15T02:00:00Z\",\"50\"",
            "\"2026-01-16T12:00:00Z\",\"LA\",\"CA\",\"US\",\"34\",\"118\",\"automatic\",\"confirmed\",\"2026-01-16T02:00:00Z\",\"50\""
        ].joined(separator: "\n")

        let result = DataImportService.importFile(content: csv, format: .csv, into: context)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.malformed, 0)

        // Verify the existing Austin entry wasn't overwritten
        let allLogs = try! context.fetch(FetchDescriptor<NightLog>(sortBy: [SortDescriptor(\NightLog.date)]))
        XCTAssertEqual(allLogs.count, 2)
        XCTAssertEqual(allLogs[0].city, "Austin") // original preserved
        XCTAssertEqual(allLogs[1].city, "LA") // new one imported
    }

    func testImportSetsSourceToManual() {
        let csv = [
            "date,city,state,country,latitude,longitude,source,status,captured_at,accuracy",
            "\"2026-01-15T12:00:00Z\",\"Austin\",\"TX\",\"US\",\"30\",\"97\",\"automatic\",\"confirmed\",\"2026-01-15T02:00:00Z\",\"50\""
        ].joined(separator: "\n")

        let result = DataImportService.importFile(content: csv, format: .csv, into: context)

        XCTAssertEqual(result.imported, 1)

        let logs = try! context.fetch(FetchDescriptor<NightLog>())
        XCTAssertEqual(logs[0].source, .manual)
        XCTAssertEqual(logs[0].status, .confirmed)
    }

    func testImportJSONFile() {
        let json = """
[
    {"date": "2026-01-15T12:00:00Z", "city": "Austin", "state": "TX", "country": "US", "source": "automatic", "status": "confirmed", "captured_at": "2026-01-15T02:00:00Z"},
    {"date": "2026-01-16T12:00:00Z", "city": "NYC", "state": "NY", "country": "US", "source": "automatic", "status": "confirmed", "captured_at": "2026-01-16T02:00:00Z"}
]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(result.malformed, 0)

        let logs = try! context.fetch(FetchDescriptor<NightLog>(sortBy: [SortDescriptor(\NightLog.date)]))
        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs[0].city, "Austin")
        XCTAssertEqual(logs[1].city, "NYC")
    }

    func testImportCombinesMalformedAndDuplicates() {
        // Pre-insert for Jan 15
        let existing = NightLog(date: noonUTC(2026, 1, 15), capturedAt: noonUTC(2026, 1, 15))
        context.insert(existing)
        try! context.save()

        let csv = [
            "date,city,state,country,latitude,longitude,source,status,captured_at,accuracy",
            "\"2026-01-15T12:00:00Z\",\"Austin\",\"TX\",\"US\",\"30\",\"97\",\"auto\",\"confirmed\",\"2026-01-15T02:00:00Z\",\"50\"",
            "bad row",
            "\"2026-01-16T12:00:00Z\",\"NYC\",\"NY\",\"US\",\"40\",\"74\",\"auto\",\"confirmed\",\"2026-01-16T02:00:00Z\",\"30\""
        ].joined(separator: "\n")

        let result = DataImportService.importFile(content: csv, format: .csv, into: context)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.malformed, 1)
    }

    // MARK: - Helpers

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
