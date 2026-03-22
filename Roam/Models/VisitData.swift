// Roam/Models/VisitData.swift
import Foundation
import CoreLocation

struct VisitData: Sendable {
    let latitude: Double
    let longitude: Double
    let arrivalDate: Date
    let departureDate: Date
    let horizontalAccuracy: Double
    let source: String  // "live" | "debug" | "fallback"

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(coordinate: CLLocationCoordinate2D, arrivalDate: Date, departureDate: Date,
         horizontalAccuracy: Double, source: String) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.horizontalAccuracy = horizontalAccuracy
        self.source = source
    }
}
