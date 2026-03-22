// Roam/Services/CityResolver.swift
import Foundation
import CoreLocation
import SwiftData

struct CachedCity {
    let city: String
    let region: String
    let country: String
}

final class CoordinateCache: @unchecked Sendable {
    private var entries: [(latitude: Double, longitude: Double, city: CachedCity)] = []
    private let thresholdMeters: Double = 5000.0  // 5.0 km

    func store(latitude: Double, longitude: Double, city: String, region: String, country: String) {
        entries.append((latitude, longitude, CachedCity(city: city, region: region, country: country)))
    }

    func lookup(latitude: Double, longitude: Double) -> CachedCity? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        for entry in entries {
            let entryLocation = CLLocation(latitude: entry.latitude, longitude: entry.longitude)
            if location.distance(from: entryLocation) <= thresholdMeters {
                return entry.city
            }
        }
        return nil
    }

    func clear() {
        entries.removeAll()
    }
}

/// Non-actor class — called from VisitPipeline which owns the ModelContext.
final class CityResolver {
    private let geocoder = CLGeocoder()
    let cache = CoordinateCache()
    private let maxAttempts = 5

    @MainActor
    func resolve(visit: RawVisit, context: ModelContext) async -> Bool {
        // Check cache first
        if let cached = cache.lookup(latitude: visit.latitude, longitude: visit.longitude) {
            visit.resolvedCity = cached.city
            visit.resolvedRegion = cached.region
            visit.resolvedCountry = cached.country
            visit.isCityResolved = true
            try? context.save()
            return true
        }

        // Geocode
        do {
            let location = CLLocation(latitude: visit.latitude, longitude: visit.longitude)
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return false }

            let city = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown"
            let region = placemark.administrativeArea ?? ""
            let country = placemark.isoCountryCode ?? ""

            visit.resolvedCity = city
            visit.resolvedRegion = region
            visit.resolvedCountry = country
            visit.isCityResolved = true

            cache.store(latitude: visit.latitude, longitude: visit.longitude,
                       city: city, region: region, country: country)

            try? context.save()
            return true
        } catch {
            visit.geocodeAttempts += 1
            try? context.save()
            return false
        }
    }

    func shouldRetry(visit: RawVisit) -> Bool {
        !visit.isCityResolved && visit.geocodeAttempts < maxAttempts
    }

    func rebuildCache(from visits: [RawVisit]) {
        cache.clear()
        for visit in visits where visit.isCityResolved {
            if let city = visit.resolvedCity, let region = visit.resolvedRegion, let country = visit.resolvedCountry {
                cache.store(latitude: visit.latitude, longitude: visit.longitude,
                           city: city, region: region, country: country)
            }
        }
    }
}
