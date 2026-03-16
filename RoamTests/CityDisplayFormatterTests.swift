import XCTest
@testable import Roam

final class CityDisplayFormatterTests: XCTestCase {

    func testUSCity() {
        let result = CityDisplayFormatter.format(city: "Austin", state: "TX", country: "US", deviceRegion: "US")
        XCTAssertEqual(result, "Austin, TX")
    }

    func testInternationalCity() {
        let result = CityDisplayFormatter.format(city: "Tokyo", state: "Tokyo", country: "JP", deviceRegion: "US")
        XCTAssertEqual(result, "Tokyo, Japan")
    }

    func testSameCountryAsDevice() {
        let result = CityDisplayFormatter.format(city: "Osaka", state: "Osaka", country: "JP", deviceRegion: "JP")
        XCTAssertEqual(result, "Osaka, Osaka")
    }

    func testCityOnly() {
        let result = CityDisplayFormatter.format(city: "Unknown", state: nil, country: nil, deviceRegion: "US")
        XCTAssertEqual(result, "Unknown")
    }

    func testNilCity() {
        let result = CityDisplayFormatter.format(city: nil, state: nil, country: nil, deviceRegion: "US")
        XCTAssertEqual(result, "Unknown location")
    }

    func testCityKey() {
        let key = CityDisplayFormatter.cityKey(city: "Austin", state: "TX", country: "US")
        XCTAssertEqual(key, "Austin|TX|US")
    }
}
