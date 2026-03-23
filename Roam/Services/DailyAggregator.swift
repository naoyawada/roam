// Roam/Services/DailyAggregator.swift
import Foundation

struct DailyAggregator {
    static let minimumVisitHours: Double = 2.0

    func aggregate(visits: [RawVisit], for date: Date, timeZone: TimeZone = .current) -> DailyEntry? {
        let dayStart = DateHelpers.startOfDay(for: date, timeZone: timeZone)
        let dayEnd = DateHelpers.endOfDay(for: date, timeZone: timeZone)
        let now = Date()

        let relevantVisits = visits.filter { visit in
            visit.isCityResolved &&
            visit.arrivalDate < dayEnd &&
            (visit.departureDate == .distantFuture ? now : visit.departureDate) > dayStart
        }

        guard !relevantVisits.isEmpty else { return nil }

        var cityHours: [String: Double] = [:]
        var cityDetails: [String: (region: String, country: String, lat: Double, lng: Double)] = [:]

        for visit in relevantVisits {
            let effectiveDeparture = visit.departureDate == .distantFuture ? min(now, dayEnd) : visit.departureDate
            let overlapStart = max(visit.arrivalDate, dayStart)
            let overlapEnd = min(effectiveDeparture, dayEnd)
            let hours = max(0, overlapEnd.timeIntervalSince(overlapStart) / 3600.0)

            let key = "\(visit.resolvedCity ?? ""), \(visit.resolvedRegion ?? "")"
            cityHours[key, default: 0] += hours

            if cityDetails[key] == nil {
                cityDetails[key] = (
                    region: visit.resolvedRegion ?? "",
                    country: visit.resolvedCountry ?? "",
                    lat: visit.latitude,
                    lng: visit.longitude
                )
            }
        }

        let meaningfulCities = cityHours.filter { $0.value >= Self.minimumVisitHours }
        let allBelowThreshold = meaningfulCities.isEmpty
        let citiesToConsider = allBelowThreshold ? cityHours : meaningfulCities

        guard let (primaryKey, _) = citiesToConsider.max(by: { $0.value < $1.value }),
              let details = cityDetails[primaryKey] else {
            return nil
        }

        let isTravelDay = citiesToConsider.count > 1

        let orderedCities = citiesToConsider.keys.sorted { a, b in
            let aVisit = relevantVisits.first { "\($0.resolvedCity ?? ""), \($0.resolvedRegion ?? "")" == a }
            let bVisit = relevantVisits.first { "\($0.resolvedCity ?? ""), \($0.resolvedRegion ?? "")" == b }
            return (aVisit?.arrivalDate ?? .distantPast) < (bVisit?.arrivalDate ?? .distantPast)
        }

        let cityObjects = orderedCities.compactMap { key -> [String: String]? in
            guard let detail = cityDetails[key] else { return nil }
            let cityName = key.components(separatedBy: ", ").first ?? key
            return ["city": cityName, "region": detail.region, "country": detail.country]
        }
        let citiesJSON = (try? JSONEncoder().encode(cityObjects))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let entry = DailyEntry()
        entry.date = DateHelpers.noonUTC(from: date, timeZone: timeZone)
        entry.primaryCity = primaryKey.components(separatedBy: ", ").first ?? primaryKey
        entry.primaryRegion = details.region
        entry.primaryCountry = details.country
        entry.primaryLatitude = details.lat
        entry.primaryLongitude = details.lng
        entry.isTravelDay = isTravelDay
        entry.citiesVisitedJSON = citiesJSON
        entry.totalVisitHours = citiesToConsider.values.reduce(0, +)
        entry.sourceRaw = EntrySource.visitRaw
        entry.confidenceRaw = allBelowThreshold ? EntryConfidence.lowRaw : EntryConfidence.highRaw
        entry.updatedAt = Date()

        return entry
    }

    /// Propagate the last known city when no visits exist for a date.
    /// Returns nil if a departure was detected (visit at a different city exists).
    func propagate(
        for date: Date,
        lastEntry: DailyEntry,
        recentVisits: [RawVisit]
    ) -> DailyEntry? {
        let departureDetected = recentVisits.contains { visit in
            visit.isCityResolved &&
            (visit.resolvedCity != lastEntry.primaryCity ||
             visit.resolvedRegion != lastEntry.primaryRegion)
        }

        if departureDetected {
            return nil
        }

        let entry = DailyEntry()
        entry.date = date
        entry.primaryCity = lastEntry.primaryCity
        entry.primaryRegion = lastEntry.primaryRegion
        entry.primaryCountry = lastEntry.primaryCountry
        entry.primaryLatitude = lastEntry.primaryLatitude
        entry.primaryLongitude = lastEntry.primaryLongitude
        entry.isTravelDay = false
        entry.citiesVisitedJSON = "[]"
        entry.totalVisitHours = 0
        entry.sourceRaw = EntrySource.propagatedRaw
        entry.confidenceRaw = EntryConfidence.mediumRaw
        entry.updatedAt = Date()

        return entry
    }
}
