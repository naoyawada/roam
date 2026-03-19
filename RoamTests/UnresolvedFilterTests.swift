import XCTest
@testable import Roam

final class UnresolvedFilterTests: XCTestCase {

    // MARK: - actionableUnresolvedLogs tests

    func testExcludesTodayDatedUnresolved() {
        let today = noonUTC(2026, 3, 19)
        let todayLog = makeLog(date: today, status: .unresolved)
        let result = UnresolvedFilter.actionable([todayLog], today: today)
        XCTAssertTrue(result.isEmpty, "Today's unresolved entry should be excluded")
    }

    func testExcludesFutureDatedUnresolved() {
        let today = noonUTC(2026, 3, 19)
        let futureLog = makeLog(date: noonUTC(2026, 3, 20), status: .unresolved)
        let result = UnresolvedFilter.actionable([futureLog], today: today)
        XCTAssertTrue(result.isEmpty, "Future unresolved entry should be excluded")
    }

    func testIncludesYesterdayDatedUnresolved() {
        let today = noonUTC(2026, 3, 19)
        let yesterdayLog = makeLog(date: noonUTC(2026, 3, 18), status: .unresolved)
        let result = UnresolvedFilter.actionable([yesterdayLog], today: today)
        XCTAssertEqual(result.count, 1, "Yesterday's unresolved entry should be included")
    }

    func testExcludesConfirmedEntries() {
        let today = noonUTC(2026, 3, 19)
        let confirmedLog = makeLog(date: noonUTC(2026, 3, 17), status: .confirmed)
        let result = UnresolvedFilter.actionable([confirmedLog], today: today)
        XCTAssertTrue(result.isEmpty, "Confirmed entries should be excluded")
    }

    func testMixedEntries() {
        let today = noonUTC(2026, 3, 19)
        let logs = [
            makeLog(date: noonUTC(2026, 3, 15), status: .unresolved),  // past unresolved — include
            makeLog(date: noonUTC(2026, 3, 16), status: .confirmed),   // confirmed — exclude
            makeLog(date: noonUTC(2026, 3, 17), status: .manual),      // manual — exclude
            makeLog(date: noonUTC(2026, 3, 19), status: .unresolved),  // today — exclude
            makeLog(date: noonUTC(2026, 3, 20), status: .unresolved),  // future — exclude
        ]
        let result = UnresolvedFilter.actionable(logs, today: today)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.date, noonUTC(2026, 3, 15))
    }

    // MARK: - Helpers

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func makeLog(date: Date, status: LogStatus) -> NightLog {
        NightLog(date: date, status: status)
    }
}
