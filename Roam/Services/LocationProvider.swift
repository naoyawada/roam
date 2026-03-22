// Roam/Services/LocationProvider.swift
import Foundation
import CoreLocation

@MainActor
protocol LocationProvider: AnyObject {
    func startMonitoring()
    func stopMonitoring()
    var onVisitReceived: (@Sendable (VisitData) -> Void)? { get set }
}

@MainActor
final class LiveLocationProvider: NSObject, LocationProvider {
    private let manager = CLLocationManager()
    var onVisitReceived: (@Sendable (VisitData) -> Void)?

    func startMonitoring() {
        manager.delegate = self
        manager.requestAlwaysAuthorization()
        manager.allowsBackgroundLocationUpdates = true
        manager.startMonitoringVisits()
    }

    func stopMonitoring() {
        manager.stopMonitoringVisits()
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }
}

extension LiveLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let data = VisitData(
            coordinate: visit.coordinate,
            arrivalDate: visit.arrivalDate,
            departureDate: visit.departureDate,
            horizontalAccuracy: visit.horizontalAccuracy,
            source: "live"
        )
        Task { @MainActor [weak self] in
            self?.onVisitReceived?(data)
        }
    }
}

final class MockLocationProvider: LocationProvider {
    var onVisitReceived: (@Sendable (VisitData) -> Void)?

    func startMonitoring() {}
    func stopMonitoring() {}

    func injectVisit(_ visit: VisitData) {
        onVisitReceived?(visit)
    }

    func injectScenario(_ visits: [VisitData]) {
        for visit in visits {
            onVisitReceived?(visit)
        }
    }
}
