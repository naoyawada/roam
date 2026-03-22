import XCTest
import SwiftData
@testable import Roam

@MainActor
final class DataImportServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([DailyEntry.self, CityRecord.self, UserSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    // MARK: - CSV Parsing

    func testParseValidCSV() {
        let csv = [
            "date,city,region,country,latitude,longitude,source,confidence,total_visit_hours,is_travel_day,updated_at",
            "\"2026-01-15T12:00:00Z\",\"Austin\",\"TX\",\"US\",\"30.2672\",\"-97.7431\",\"visit\",\"high\",\"8.0\",\"false\",\"2026-01-15T12:00:00Z\"",
            "\"2026-01-16T12:00:00Z\",\"NYC\",\"NY\",\"US\",\"40.7128\",\"-74.006\",\"visit\",\"high\",\"12.0\",\"false\",\"2026-01-16T12:00:00Z\"",
            "\"2026-01-17T12:00:00Z\",\"LA\",\"CA\",\"US\",\"34.0522\",\"-118.2437\",\"manual\",\"medium\",\"6.0\",\"true\",\"2026-01-17T12:00:00Z\"",
            "\"2026-01-18T12:00:00Z\",\"\",\"\",\"\",\"\",\"\",\"visit\",\"low\",\"0.0\",\"false\",\"2026-01-18T12:00:00Z\"",
            "\"2026-01-19T12:00:00Z\",\"Chicago\",\"IL\",\"US\",\"41.8781\",\"-87.6298\",\"visit\",\"high\",\"10.0\",\"false\",\"2026-01-19T12:00:00Z\""
        ].joined(separator: "\n")

        let (entries, malformed) = DataImportService.parseCSV(csv)

        XCTAssertEqual(entries.count, 5)
        XCTAssertEqual(malformed, 0)

        XCTAssertEqual(entries[0].city, "Austin")
        XCTAssertEqual(entries[0].region, "TX")
        XCTAssertEqual(entries[0].country, "US")
        XCTAssertEqual(entries[0].latitude, 30.2672)
        XCTAssertEqual(entries[0].longitude, -97.7431)

        // Empty fields should produce empty strings for city
        XCTAssertEqual(entries[3].city, "")
        XCTAssertEqual(entries[3].latitude, 0.0)
    }

    func testParseCSVWithMalformedRows() {
        let csv = [
            "date,city,region,country,latitude,longitude,source,confidence,total_visit_hours,is_travel_day,updated_at",
            "\"2026-01-15T12:00:00Z\",\"Austin\",\"TX\",\"US\",\"30.2672\",\"-97.7431\",\"visit\",\"high\",\"8.0\",\"false\",\"2026-01-15T12:00:00Z\"",
            "not a valid row",
            "\"bad-date\",\"Austin\",\"TX\",\"US\",\"30\",\"97\",\"visit\",\"high\",\"8.0\",\"false\",\"2026-01-15T12:00:00Z\""
        ].joined(separator: "\n")

        let (entries, malformed) = DataImportService.parseCSV(csv)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(malformed, 2)
    }

    func testParseCSVHeaderOnly() {
        let csv = "date,city,region,country,latitude,longitude,source,confidence,total_visit_hours,is_travel_day,updated_at"

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
            "date,city,region,country,latitude,longitude,source,confidence,total_visit_hours,is_travel_day,updated_at",
            "\"2026-01-15T12:00:00Z\",\"City with \"\"quotes\"\"\",\"TX\",\"US\",\"30\",\"97\",\"manual\",\"high\",\"8.0\",\"false\",\"2026-01-15T12:00:00Z\""
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
        "region": "TX",
        "country": "US",
        "latitude": 30.2672,
        "longitude": -97.7431,
        "source": "visit",
        "confidence": "high",
        "total_visit_hours": 8.0,
        "is_travel_day": false,
        "updated_at": "2026-01-15T12:00:00Z"
    },
    {
        "date": "2026-01-16T12:00:00Z",
        "city": "NYC",
        "region": "NY",
        "country": "US",
        "latitude": 40.7128,
        "longitude": -74.006,
        "source": "visit",
        "confidence": "high",
        "total_visit_hours": 12.0,
        "is_travel_day": false,
        "updated_at": "2026-01-16T12:00:00Z"
    },
    {
        "date": "2026-01-17T12:00:00Z",
        "city": "",
        "source": "visit",
        "confidence": "low",
        "updated_at": "2026-01-17T12:00:00Z"
    },
    {
        "date": "2026-01-18T12:00:00Z",
        "city": "Chicago",
        "region": "IL",
        "country": "US",
        "source": "visit",
        "confidence": "high",
        "updated_at": "2026-01-18T12:00:00Z"
    },
    {
        "date": "2026-01-19T12:00:00Z",
        "city": "LA",
        "region": "CA",
        "country": "US",
        "latitude": 34.0522,
        "longitude": -118.2437,
        "source": "manual",
        "confidence": "medium",
        "total_visit_hours": 6.0,
        "is_travel_day": true,
        "updated_at": "2026-01-19T12:00:00Z"
    }
]
"""

        let (entries, malformed) = DataImportService.parseJSON(json)

        XCTAssertEqual(entries.count, 5)
        XCTAssertEqual(malformed, 0)

        XCTAssertEqual(entries[0].city, "Austin")
        XCTAssertEqual(entries[0].latitude, 30.2672)
        XCTAssertEqual(entries[4].isTravelDay, true)

        // Entry with no optional fields
        XCTAssertEqual(entries[2].city, "")
        XCTAssertEqual(entries[2].latitude, 0.0)
    }

    func testParseJSONMissingDate() {
        let json = """
[
    {"city": "Austin", "source": "visit", "confidence": "high"},
    {"date": "2026-01-16T12:00:00Z", "city": "NYC", "source": "visit", "confidence": "high"}
]
"""

        let (entries, malformed) = DataImportService.parseJSON(json)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(malformed, 1)
        XCTAssertEqual(entries[0].city, "NYC")
    }

    func testParseJSONWithExtraKeys() {
        let json = """
[{"date": "2026-01-15T12:00:00Z", "city": "Austin", "source": "visit", "confidence": "high", "extra_field": "ignored"}]
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
        // Pre-insert an entry for Jan 15
        let existing = makeDailyEntry(date: noonUTC(2026, 1, 15), city: "Austin")
        context.insert(existing)
        try! context.save()

        let csv = [
            "date,city,region,country,latitude,longitude,source,confidence,total_visit_hours,is_travel_day,updated_at",
            "\"2026-01-15T12:00:00Z\",\"NYC\",\"NY\",\"US\",\"40\",\"74\",\"visit\",\"high\",\"8.0\",\"false\",\"2026-01-15T12:00:00Z\"",
            "\"2026-01-16T12:00:00Z\",\"LA\",\"CA\",\"US\",\"34\",\"118\",\"visit\",\"high\",\"8.0\",\"false\",\"2026-01-16T12:00:00Z\""
        ].joined(separator: "\n")

        let result = DataImportService.importFile(content: csv, format: .csv, into: context)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.malformed, 0)

        let allEntries = try! context.fetch(FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\DailyEntry.date)]))
        XCTAssertEqual(allEntries.count, 2)
        XCTAssertEqual(allEntries[0].primaryCity, "Austin") // original preserved
        XCTAssertEqual(allEntries[1].primaryCity, "LA")     // new one imported
    }

    func testImportSetsSourceToManual() {
        let csv = [
            "date,city,region,country,latitude,longitude,source,confidence,total_visit_hours,is_travel_day,updated_at",
            "\"2026-01-15T12:00:00Z\",\"Austin\",\"TX\",\"US\",\"30\",\"97\",\"visit\",\"high\",\"8.0\",\"false\",\"2026-01-15T12:00:00Z\""
        ].joined(separator: "\n")

        let result = DataImportService.importFile(content: csv, format: .csv, into: context)

        XCTAssertEqual(result.imported, 1)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries[0].source, .manual)
    }

    func testImportJSONFile() {
        let json = """
[
    {"date": "2026-01-15T12:00:00Z", "city": "Austin", "region": "TX", "country": "US", "source": "visit", "confidence": "high"},
    {"date": "2026-01-16T12:00:00Z", "city": "NYC", "region": "NY", "country": "US", "source": "visit", "confidence": "high"}
]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(result.malformed, 0)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\DailyEntry.date)]))
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].primaryCity, "Austin")
        XCTAssertEqual(entries[1].primaryCity, "NYC")
    }

    func testImportCombinesMalformedAndDuplicates() {
        // Pre-insert for Jan 15
        let existing = makeDailyEntry(date: noonUTC(2026, 1, 15), city: "Austin")
        context.insert(existing)
        try! context.save()

        let csv = [
            "date,city,region,country,latitude,longitude,source,confidence,total_visit_hours,is_travel_day,updated_at",
            "\"2026-01-15T12:00:00Z\",\"Austin\",\"TX\",\"US\",\"30\",\"97\",\"visit\",\"high\",\"8.0\",\"false\",\"2026-01-15T12:00:00Z\"",
            "bad row",
            "\"2026-01-16T12:00:00Z\",\"NYC\",\"NY\",\"US\",\"40\",\"74\",\"visit\",\"high\",\"8.0\",\"false\",\"2026-01-16T12:00:00Z\""
        ].joined(separator: "\n")

        let result = DataImportService.importFile(content: csv, format: .csv, into: context)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.malformed, 1)
    }

    // MARK: - Import Upsert

    func testImportUpdatesExistingEmptyCityEntry() {
        // Pre-insert an entry with no city for Jan 15
        let existing = makeDailyEntry(date: noonUTC(2026, 1, 15), city: "")
        context.insert(existing)
        try! context.save()

        let json = """
[{"date": "2026-01-15T12:00:00Z", "city": "Austin", "region": "TX", "country": "US", "source": "visit", "confidence": "high"}]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(result.malformed, 0)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].primaryCity, "Austin")
        XCTAssertEqual(entries[0].primaryRegion, "TX")
        XCTAssertEqual(entries[0].source, .manual)
    }

    func testImportDoesNotOverwriteExistingCityEntry() {
        // Pre-insert a confirmed entry with city for Jan 15
        let existing = makeDailyEntry(date: noonUTC(2026, 1, 15), city: "Austin")
        context.insert(existing)
        try! context.save()

        let json = """
[{"date": "2026-01-15T12:00:00Z", "city": "NYC", "region": "NY", "country": "US", "source": "visit", "confidence": "high"}]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.malformed, 0)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].primaryCity, "Austin") // original preserved
    }

    func testImportSkipsWhenIncomingHasNoCity() {
        // Pre-insert an entry with no city
        let existing = makeDailyEntry(date: noonUTC(2026, 1, 15), city: "")
        context.insert(existing)
        try! context.save()

        let json = """
[{"date": "2026-01-15T12:00:00Z", "city": "", "source": "visit", "confidence": "low"}]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.malformed, 0)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries[0].primaryCity, "") // unchanged
    }

    // MARK: - Within-File Dedup

    func testImportDedupesWithinFile() {
        let json = """
[
    {"date": "2026-01-15T12:00:00Z", "city": "Austin", "region": "TX", "country": "US", "source": "visit", "confidence": "high"},
    {"date": "2026-01-15T12:00:00Z", "city": "NYC", "region": "NY", "country": "US", "source": "manual", "confidence": "high"}
]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.malformed, 0)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].primaryCity, "Austin") // first entry wins
    }

    func testImportNormalizesNonNoonDates() {
        // Import a date that is already noon UTC — should match an existing entry at noon UTC
        let existing = makeDailyEntry(date: noonUTC(2026, 1, 15), city: "")
        context.insert(existing)
        try! context.save()

        let json = """
[{"date": "2026-01-15T12:00:00Z", "city": "Austin", "region": "TX", "country": "US", "source": "visit", "confidence": "high"}]
"""

        let result = DataImportService.importFile(content: json, format: .json, into: context)

        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.malformed, 0)

        let entries = try! context.fetch(FetchDescriptor<DailyEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].primaryCity, "Austin")
    }

    // MARK: - Helpers

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func makeDailyEntry(date: Date, city: String) -> DailyEntry {
        let entry = DailyEntry()
        entry.date = date
        entry.primaryCity = city
        entry.primaryRegion = ""
        entry.primaryCountry = ""
        entry.primaryLatitude = 0.0
        entry.primaryLongitude = 0.0
        entry.source = .visit
        entry.confidence = .high
        entry.createdAt = date
        entry.updatedAt = date
        return entry
    }
}
