// Roam/Models/RawVisit.swift
import Foundation
import SwiftData
import CoreLocation

@Model
final class RawVisit {
    var id: UUID = UUID()
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var horizontalAccuracy: Double = 0.0
    var arrivalDate: Date = Date.distantPast
    var departureDate: Date = Date.distantFuture

    // City resolution
    var resolvedCity: String? = nil
    var resolvedRegion: String? = nil
    var resolvedCountry: String? = nil
    var isCityResolved: Bool = false
    var geocodeAttempts: Int = 0

    // Pipeline tracking
    var isProcessed: Bool = false
    var source: String = "live"
    var createdAt: Date = Date()

    // Computed
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var durationHours: Double {
        let end = departureDate == .distantFuture ? Date() : departureDate
        return end.timeIntervalSince(arrivalDate) / 3600.0
    }

    init(from visitData: VisitData) {
        self.latitude = visitData.latitude
        self.longitude = visitData.longitude
        self.horizontalAccuracy = visitData.horizontalAccuracy
        self.arrivalDate = visitData.arrivalDate
        self.departureDate = visitData.departureDate
        self.source = visitData.source
    }

    init() {}
}
