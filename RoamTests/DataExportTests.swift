import XCTest
@testable import Roam

final class DataExportTests: XCTestCase {

    // MARK: - CSV Tests

    func testCSVHeaderRow() {
        let csv = DataExportService.generateCSV(from: [])
        XCTAssertEqual(csv, "date,city,region,country,latitude,longitude,source,confidence,total_visit_hours,is_travel_day,updated_at")
    }

    func testCSVEntryRow() {
        let date = noonUTC(2026, 1, 15)
        let entry = makeDailyEntry(
            date: date,
            city: "Austin",
            region: "TX",
            country: "US",
            latitude: 30.2672,
            longitude: -97.7431,
            source: .visit,
            confidence: .high
        )

        let csv = DataExportService.generateCSV(from: [entry])
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2)

        let row = lines[1]
        XCTAssertTrue(row.contains("\"Austin\""))
        XCTAssertTrue(row.contains("\"TX\""))
        XCTAssertTrue(row.contains("\"US\""))
        XCTAssertTrue(row.contains("\"30.2672\""))
        XCTAssertTrue(row.contains("\"-97.7431\""))
        XCTAssertTrue(row.contains("\"visit\""))
        XCTAssertTrue(row.contains("\"high\""))
    }

    func testCSVEmptyCity() {
        let date = noonUTC(2026, 2, 1)
        let entry = makeDailyEntry(date: date, city: "", region: "", country: "")

        let csv = DataExportService.generateCSV(from: [entry])
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2)
        // Empty city fields should be empty quoted strings
        XCTAssertTrue(lines[1].contains("\"\""))
    }

    func testCSVEscapesDoubleQuotes() {
        let date = noonUTC(2026, 3, 1)
        let entry = makeDailyEntry(date: date, city: "City with \"quotes\"", region: "", country: "")

        let csv = DataExportService.generateCSV(from: [entry])
        // Double quotes inside should be escaped as ""
        XCTAssertTrue(csv.contains("City with \"\"quotes\"\""))
    }

    func testCSVMultipleEntries() {
        let entries = [
            makeDailyEntry(date: noonUTC(2026, 1, 1), city: "Austin"),
            makeDailyEntry(date: noonUTC(2026, 1, 2), city: "NYC"),
            makeDailyEntry(date: noonUTC(2026, 1, 3), city: "LA")
        ]

        let csv = DataExportService.generateCSV(from: entries)
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 4) // header + 3 rows
    }

    // MARK: - JSON Tests

    func testJSONEmptyEntries() {
        let json = DataExportService.generateJSON(from: [])
        XCTAssertEqual(json.trimmingCharacters(in: .whitespacesAndNewlines), "[\n\n]")
    }

    func testJSONEntry() {
        let date = noonUTC(2026, 1, 15)
        let entry = makeDailyEntry(
            date: date,
            city: "Austin",
            region: "TX",
            country: "US",
            latitude: 30.2672,
            longitude: -97.7431,
            source: .visit,
            confidence: .high
        )

        let json = DataExportService.generateJSON(from: [entry])
        let data = json.data(using: .utf8)!
        let array = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]

        XCTAssertEqual(array.count, 1)
        let dict = array[0]
        XCTAssertEqual(dict["city"] as? String, "Austin")
        XCTAssertEqual(dict["region"] as? String, "TX")
        XCTAssertEqual(dict["country"] as? String, "US")
        XCTAssertEqual(dict["latitude"] as? Double, 30.2672)
        XCTAssertEqual(dict["longitude"] as? Double, -97.7431)
        XCTAssertEqual(dict["source"] as? String, "visit")
        XCTAssertEqual(dict["confidence"] as? String, "high")
        XCTAssertNotNil(dict["date"])
        XCTAssertNotNil(dict["updated_at"])
    }

    func testJSONSortedKeys() {
        let date = noonUTC(2026, 1, 1)
        let entry = makeDailyEntry(date: date, city: "Austin", region: "TX", country: "US")

        let json = DataExportService.generateJSON(from: [entry])
        // With sortedKeys, "city" should appear before "country"
        let cityRange = json.range(of: "\"city\"")!
        let countryRange = json.range(of: "\"country\"")!
        XCTAssertTrue(cityRange.lowerBound < countryRange.lowerBound)
    }

    // MARK: - Export Dedup

    func testDeduplicatedEntriesKeepsMostRecentPerDate() {
        let date = noonUTC(2026, 1, 15)
        let older = makeDailyEntry(date: date, city: "Austin")
        older.updatedAt = Date(timeIntervalSince1970: 1000)
        let newer = makeDailyEntry(date: date, city: "Austin Updated")
        newer.updatedAt = Date(timeIntervalSince1970: 2000)

        let result = DataExportService.deduplicatedEntries([older, newer])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].primaryCity, "Austin Updated")
    }

    func testDeduplicatedEntriesPreservesUniqueEntries() {
        let entry1 = makeDailyEntry(date: noonUTC(2026, 1, 15), city: "Austin")
        let entry2 = makeDailyEntry(date: noonUTC(2026, 1, 16), city: "NYC")

        let result = DataExportService.deduplicatedEntries([entry1, entry2])

        XCTAssertEqual(result.count, 2)
    }

    func testDeduplicatedEntriesSortsByDate() {
        let entry1 = makeDailyEntry(date: noonUTC(2026, 1, 16), city: "NYC")
        let entry2 = makeDailyEntry(date: noonUTC(2026, 1, 15), city: "Austin")

        let result = DataExportService.deduplicatedEntries([entry1, entry2])

        XCTAssertEqual(result[0].primaryCity, "Austin")
        XCTAssertEqual(result[1].primaryCity, "NYC")
    }

    // MARK: - Helpers

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func makeDailyEntry(
        date: Date,
        city: String = "",
        region: String = "",
        country: String = "",
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        source: EntrySource = .visit,
        confidence: EntryConfidence = .high
    ) -> DailyEntry {
        let entry = DailyEntry()
        entry.date = date
        entry.primaryCity = city
        entry.primaryRegion = region
        entry.primaryCountry = country
        entry.primaryLatitude = latitude
        entry.primaryLongitude = longitude
        entry.source = source
        entry.confidence = confidence
        entry.createdAt = date
        entry.updatedAt = date
        return entry
    }
}
