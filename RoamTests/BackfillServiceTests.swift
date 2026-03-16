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

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
