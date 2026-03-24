// Roam/Services/LocationProvider.swift
import Foundation
import CoreLocation
import UIKit

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
    /// Called when significant location change is detected — use as a pipeline trigger
    var onSignificantLocationChange: (@Sendable () -> Void)?

    func startMonitoring() {
        manager.delegate = self
        manager.requestAlwaysAuthorization()
        manager.allowsBackgroundLocationUpdates = true
        manager.startMonitoringVisits()
        manager.startMonitoringSignificantLocationChanges()
    }

    func stopMonitoring() {
        manager.stopMonitoringVisits()
        manager.stopMonitoringSignificantLocationChanges()
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

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Only expected from significant location changes. Do NOT call requestLocation()
        // or startUpdatingLocation() on this manager — those would also trigger this callback.
        Task { @MainActor [weak self] in
            self?.onSignificantLocationChange?()
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
