import CoreLocation
@preconcurrency import MapKit
import os
import SwiftData

@MainActor
final class LocationCaptureService: NSObject, ObservableObject {

    private let locationManager = CLLocationManager()
    private var captureCompletion: ((CLLocation?) -> Void)?
    private nonisolated static let logger = Logger(subsystem: "com.naoyawada.roam", category: "LocationCapture")

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }

    /// Validate whether a location reading meets quality thresholds.
    nonisolated static func isValidReading(_ location: CLLocation) -> Bool {
        let maxAccuracy: CLLocationDistance = 1000  // meters
        let maxSpeed: CLLocationSpeed = 55.6        // m/s (~200 km/h)

        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy < maxAccuracy else {
            return false
        }
        if location.speed >= 0, location.speed > maxSpeed {
            return false
        }
        return true
    }

    /// Request a single location reading.
    func requestLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            captureCompletion = { location in
                continuation.resume(returning: location)
            }
            locationManager.requestLocation()
        }
    }

    /// Reverse geocode a location into a map item.
    func reverseGeocode(_ location: CLLocation) async -> MKMapItem? {
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        let mapItems = try? await request.mapItems
        return mapItems?.first
    }

    /// Full capture flow: get location, validate, geocode, return result.
    func captureNight() async -> CaptureResult? {
        guard let location = await requestLocation() else {
            Self.logger.error("captureNight: requestLocation returned nil")
            return nil
        }
        guard Self.isValidReading(location) else {
            Self.logger.error("captureNight: invalid reading (accuracy=\(location.horizontalAccuracy), speed=\(location.speed))")
            return nil
        }
        guard let mapItem = await reverseGeocode(location) else {
            Self.logger.error("captureNight: reverse geocode failed for (\(location.coordinate.latitude), \(location.coordinate.longitude))")
            return nil
        }
        guard let reps = mapItem.addressRepresentations else {
            Self.logger.error("captureNight: no address representations")
            return nil
        }
        guard let city = reps.cityName else {
            Self.logger.error("captureNight: no city name in address representations")
            return nil
        }

        // Extract state from cityWithContext by removing the city prefix
        // e.g. "Austin, TX" -> "TX", "Tokyo, Tokyo" -> "Tokyo"
        let state: String? = {
            guard let ctx = reps.cityWithContext else { return nil }
            let prefix = "\(city), "
            guard ctx.hasPrefix(prefix) else { return nil }
            return String(ctx.dropFirst(prefix.count))
        }()

        let country = reps.region?.identifier

        return CaptureResult(
            city: city,
            state: state,
            country: country,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            capturedAt: location.timestamp
        )
    }

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
}

extension LocationCaptureService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            captureCompletion?(locations.last)
            captureCompletion = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        LocationCaptureService.logger.error("CLLocationManager error: \(error.localizedDescription)")
        Task { @MainActor in
            captureCompletion?(nil)
            captureCompletion = nil
        }
    }
}

struct CaptureResult: Sendable {
    let city: String
    let state: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let capturedAt: Date
}
