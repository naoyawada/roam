import XCTest
@testable import Roam

final class SignificantLocationServiceTests: XCTestCase {

    func testIsInCaptureWindow_2AM_returnsTrue() {
        let date = makeDate(hour: 2, minute: 0)
        XCTAssertTrue(SignificantLocationService.isInCaptureWindow(date: date))
    }

    func testIsInCaptureWindow_559AM_returnsTrue() {
        let date = makeDate(hour: 5, minute: 59)
        XCTAssertTrue(SignificantLocationService.isInCaptureWindow(date: date))
    }

    func testIsInCaptureWindow_midnight_returnsTrue() {
        let date = makeDate(hour: 0, minute: 0)
        XCTAssertTrue(SignificantLocationService.isInCaptureWindow(date: date))
    }

    func testIsInCaptureWindow_6AM_returnsFalse() {
        let date = makeDate(hour: 6, minute: 0)
        XCTAssertFalse(SignificantLocationService.isInCaptureWindow(date: date))
    }

    func testIsInCaptureWindow_10PM_returnsFalse() {
        let date = makeDate(hour: 22, minute: 0)
        XCTAssertFalse(SignificantLocationService.isInCaptureWindow(date: date))
    }

    func testIsInCaptureWindow_noon_returnsFalse() {
        let date = makeDate(hour: 12, minute: 0)
        XCTAssertFalse(SignificantLocationService.isInCaptureWindow(date: date))
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: 2026, month: 3, day: 17, hour: hour, minute: minute, second: 0))!
    }
}
