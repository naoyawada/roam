import XCTest
import CoreLocation
@testable import Roam

final class LocationValidationTests: XCTestCase {

    func testValidLocation() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74),
            altitude: 0,
            horizontalAccuracy: 50,
            verticalAccuracy: 0,
            course: 0,
            speed: 0,
            timestamp: Date()
        )
        XCTAssertTrue(LocationCaptureService.isValidReading(location))
    }

    func testInvalidAccuracy() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74),
            altitude: 0,
            horizontalAccuracy: 1500,
            verticalAccuracy: 0,
            course: 0,
            speed: 0,
            timestamp: Date()
        )
        XCTAssertFalse(LocationCaptureService.isValidReading(location))
    }

    func testTooFast() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74),
            altitude: 0,
            horizontalAccuracy: 50,
            verticalAccuracy: 0,
            course: 0,
            speed: 60.0,  // ~216 km/h, above 55.6 m/s threshold
            timestamp: Date()
        )
        XCTAssertFalse(LocationCaptureService.isValidReading(location))
    }

    func testNegativeSpeedIsValid() {
        // CLLocation reports -1 when speed is unavailable — should not reject
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74),
            altitude: 0,
            horizontalAccuracy: 50,
            verticalAccuracy: 0,
            course: 0,
            speed: -1.0,
            timestamp: Date()
        )
        XCTAssertTrue(LocationCaptureService.isValidReading(location))
    }

    func testNegativeAccuracyIsInvalid() {
        // CLLocation reports -1 when accuracy is unavailable
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 30.27, longitude: -97.74),
            altitude: 0,
            horizontalAccuracy: -1,
            verticalAccuracy: 0,
            course: 0,
            speed: 0,
            timestamp: Date()
        )
        XCTAssertFalse(LocationCaptureService.isValidReading(location))
    }
}
