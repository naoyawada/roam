import XCTest
@testable import Roam

final class BackfillServiceTests: XCTestCase {

    func testMissedNightsCalculation_noGaps() {
        let today = noonUTC(2026, 3, 16)
        let existingDates = [noonUTC(2026, 3, 14), noonUTC(2026, 3, 15)]
        let missed = BackfillService.missedNights(existingDates: existingDates, today: today, maxDays: 30)
        XCTAssertTrue(missed.isEmpty)
    }

    func testMissedNightsCalculation_withGap() {
        let today = noonUTC(2026, 3, 16)
        let existingDates = [noonUTC(2026, 3, 13)]
        let missed = BackfillService.missedNights(existingDates: existingDates, today: today, maxDays: 30)
        XCTAssertEqual(missed.count, 2)
        XCTAssertEqual(missed[0], noonUTC(2026, 3, 14))
        XCTAssertEqual(missed[1], noonUTC(2026, 3, 15))
    }

    func testMissedNightsCappedAt30Days() {
        let today = noonUTC(2026, 3, 16)
        let existingDates: [Date] = []  // no entries at all
        let missed = BackfillService.missedNights(existingDates: existingDates, today: today, maxDays: 30)
        XCTAssertEqual(missed.count, 30)
    }

    func testMissedNightsExcludesToday() {
        let today = noonUTC(2026, 3, 16)
        let existingDates = [noonUTC(2026, 3, 15)]
        let missed = BackfillService.missedNights(existingDates: existingDates, today: today, maxDays: 30)
        // Today (March 16) should NOT be in missed — the night hasn't happened yet
        XCTAssertTrue(missed.isEmpty)
    }

    // MARK: - calendarTodayNoonUTC tests

    /// At 2 AM local, calendarTodayNoonUTC should return today's date (March 17),
    /// NOT roll back to March 16 like normalizedNightDate would.
    func testCalendarTodayAt2AM_doesNotRollBack() {
        let twoAM = dateInTZ(2026, 3, 17, hour: 2, minute: 0, timeZone: .current)
        let result = BackfillService.calendarTodayNoonUTC(now: twoAM, timeZone: .current)
        assertNoonUTC(result, year: 2026, month: 3, day: 17)
    }

    /// At 8 AM local, calendarTodayNoonUTC should return today's date.
    func testCalendarTodayAt8AM() {
        let eightAM = dateInTZ(2026, 3, 17, hour: 8, minute: 0, timeZone: .current)
        let result = BackfillService.calendarTodayNoonUTC(now: eightAM, timeZone: .current)
        assertNoonUTC(result, year: 2026, month: 3, day: 17)
    }

    /// Backfill at 2 AM should detect last night (March 16) as missing.
    /// This was the original bug: normalizedNightDate(2AM Mar 17) = Mar 16,
    /// then the loop skipped Mar 16 because it treated it as "today".
    func testBackfillAt2AM_detectsLastNightMissing() {
        // Simulate: it's 2 AM on March 17, no entry for March 16
        let today = BackfillService.calendarTodayNoonUTC(
            now: dateInTZ(2026, 3, 17, hour: 2, minute: 0, timeZone: .current),
            timeZone: .current
        )
        let existingDates = [noonUTC(2026, 3, 15)]
        let missed = BackfillService.missedNights(existingDates: existingDates, today: today, maxDays: 30)
        XCTAssertEqual(missed.count, 1)
        XCTAssertEqual(missed.first, noonUTC(2026, 3, 16))
    }

    // MARK: - Helpers

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func dateInTZ(_ year: Int, _ month: Int, _ day: Int,
                           hour: Int, minute: Int, timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.date(from: DateComponents(
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: 0
        ))!
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
