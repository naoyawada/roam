import XCTest
@testable import Roam

final class DateNormalizationTests: XCTestCase {

    // Capture at 2 AM on March 17 → logs as March 16 (the night of the 16th)
    func testCaptureAt2AMRollsBackToYesterday() {
        let capture = date(2026, 3, 17, hour: 2, minute: 0)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 3, day: 16)
    }

    // Capture at 5:59 AM → still rolls back
    func testCaptureAt559AMRollsBack() {
        let capture = date(2026, 3, 17, hour: 5, minute: 59)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 3, day: 16)
    }

    // Capture at 6:00 AM → does NOT roll back (same calendar day)
    func testCaptureAt6AMDoesNotRollBack() {
        let capture = date(2026, 3, 17, hour: 6, minute: 0)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 3, day: 17)
    }

    // Capture at 11 PM → same calendar day
    func testCaptureAt11PMSameDay() {
        let capture = date(2026, 3, 16, hour: 23, minute: 0)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 3, day: 16)
    }

    // Midnight capture → rolls back to previous day
    func testCaptureAtMidnightRollsBack() {
        let capture = date(2026, 3, 17, hour: 0, minute: 0)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 3, day: 16)
    }

    // New Year's edge: 2 AM on Jan 1 → logs as Dec 31 of previous year
    func testNewYearsEdge() {
        let capture = date(2027, 1, 1, hour: 2, minute: 0)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        assertNoonUTC(normalized, year: 2026, month: 12, day: 31)
    }

    // Result is always noon UTC
    func testResultIsNoonUTC() {
        let capture = date(2026, 6, 15, hour: 14, minute: 30)
        let normalized = DateNormalization.normalizedNightDate(from: capture)
        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(identifier: "UTC")!,
            from: normalized
        )
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = TimeZone.current
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func assertNoonUTC(_ date: Date, year: Int, month: Int, day: Int,
                                file: StaticString = #filePath, line: UInt = #line) {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
        XCTAssertEqual(comps.year, year, "Year mismatch", file: file, line: line)
        XCTAssertEqual(comps.month, month, "Month mismatch", file: file, line: line)
        XCTAssertEqual(comps.day, day, "Day mismatch", file: file, line: line)
        XCTAssertEqual(comps.hour, 12, "Should be noon UTC", file: file, line: line)
    }
}
