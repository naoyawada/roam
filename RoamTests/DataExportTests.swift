import XCTest
@testable import Roam

final class DataExportTests: XCTestCase {

    // MARK: - CSV Tests

    func testCSVHeaderRow() {
        let csv = DataExportService.generateCSV(from: [])
        XCTAssertEqual(csv, "date,city,state,country,latitude,longitude,source,status,captured_at,accuracy")
    }

    func testCSVConfirmedLog() {
        let date = noonUTC(2026, 1, 15)
        let log = NightLog(
            date: date,
            city: "Austin",
            state: "TX",
            country: "US",
            latitude: 30.2672,
            longitude: -97.7431,
            capturedAt: date,
            horizontalAccuracy: 50,
            source: .automatic,
            status: .confirmed
        )

        let csv = DataExportService.generateCSV(from: [log])
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2)

        let row = lines[1]
        XCTAssertTrue(row.contains("\"Austin\""))
        XCTAssertTrue(row.contains("\"TX\""))
        XCTAssertTrue(row.contains("\"US\""))
        XCTAssertTrue(row.contains("\"30.2672\""))
        XCTAssertTrue(row.contains("\"-97.7431\""))
        XCTAssertTrue(row.contains("\"automatic\""))
        XCTAssertTrue(row.contains("\"confirmed\""))
        XCTAssertTrue(row.contains("\"50\""))
    }

    func testCSVUnresolvedLogHasEmptyFields() {
        let date = noonUTC(2026, 2, 1)
        let log = NightLog(
            date: date,
            capturedAt: date,
            source: .automatic,
            status: .unresolved
        )

        let csv = DataExportService.generateCSV(from: [log])
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2)

        let row = lines[1]
        // City, state, country, lat, lon, accuracy should be empty
        XCTAssertTrue(row.contains("\"\""))
        XCTAssertTrue(row.contains("\"unresolved\""))
    }

    func testCSVEscapesDoubleQuotes() {
        let date = noonUTC(2026, 3, 1)
        let log = NightLog(
            date: date,
            city: "City with \"quotes\"",
            capturedAt: date,
            source: .manual,
            status: .manual
        )

        let csv = DataExportService.generateCSV(from: [log])
        // Double quotes inside should be escaped as ""
        XCTAssertTrue(csv.contains("City with \"\"quotes\"\""))
    }

    func testCSVMultipleLogs() {
        let logs = [
            NightLog(date: noonUTC(2026, 1, 1), city: "Austin", capturedAt: noonUTC(2026, 1, 1)),
            NightLog(date: noonUTC(2026, 1, 2), city: "NYC", capturedAt: noonUTC(2026, 1, 2)),
            NightLog(date: noonUTC(2026, 1, 3), city: "LA", capturedAt: noonUTC(2026, 1, 3))
        ]

        let csv = DataExportService.generateCSV(from: logs)
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 4) // header + 3 rows
    }

    // MARK: - JSON Tests

    func testJSONEmptyLogs() {
        let json = DataExportService.generateJSON(from: [])
        XCTAssertEqual(json.trimmingCharacters(in: .whitespacesAndNewlines), "[\n\n]")
    }

    func testJSONConfirmedLog() {
        let date = noonUTC(2026, 1, 15)
        let log = NightLog(
            date: date,
            city: "Austin",
            state: "TX",
            country: "US",
            latitude: 30.2672,
            longitude: -97.7431,
            capturedAt: date,
            horizontalAccuracy: 50,
            source: .automatic,
            status: .confirmed
        )

        let json = DataExportService.generateJSON(from: [log])
        let data = json.data(using: .utf8)!
        let array = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]

        XCTAssertEqual(array.count, 1)
        let entry = array[0]
        XCTAssertEqual(entry["city"] as? String, "Austin")
        XCTAssertEqual(entry["state"] as? String, "TX")
        XCTAssertEqual(entry["country"] as? String, "US")
        XCTAssertEqual(entry["latitude"] as? Double, 30.2672)
        XCTAssertEqual(entry["longitude"] as? Double, -97.7431)
        XCTAssertEqual(entry["accuracy"] as? Double, 50)
        XCTAssertEqual(entry["source"] as? String, "automatic")
        XCTAssertEqual(entry["status"] as? String, "confirmed")
        XCTAssertNotNil(entry["date"])
        XCTAssertNotNil(entry["captured_at"])
    }

    func testJSONOmitsNilFields() {
        let date = noonUTC(2026, 2, 1)
        let log = NightLog(
            date: date,
            capturedAt: date,
            source: .automatic,
            status: .unresolved
        )

        let json = DataExportService.generateJSON(from: [log])
        let data = json.data(using: .utf8)!
        let array = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]

        let entry = array[0]
        XCTAssertNil(entry["city"])
        XCTAssertNil(entry["state"])
        XCTAssertNil(entry["country"])
        XCTAssertNil(entry["latitude"])
        XCTAssertNil(entry["longitude"])
        XCTAssertNil(entry["accuracy"])
        XCTAssertEqual(entry["status"] as? String, "unresolved")
    }

    func testJSONSortedKeys() {
        let date = noonUTC(2026, 1, 1)
        let log = NightLog(
            date: date,
            city: "Austin",
            state: "TX",
            country: "US",
            capturedAt: date,
            source: .automatic,
            status: .confirmed
        )

        let json = DataExportService.generateJSON(from: [log])
        // With sortedKeys, "captured_at" should appear before "city"
        let capturedAtRange = json.range(of: "captured_at")!
        let cityRange = json.range(of: "city")!
        XCTAssertTrue(capturedAtRange.lowerBound < cityRange.lowerBound)
    }

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

    // MARK: - Helpers

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
