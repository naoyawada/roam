// Roam/Services/LegacyMigrator.swift
import Foundation
import SwiftData

struct LegacyMigrator {

    static let migrationCompleteKey = "legacyMigrationComplete"

    static var isMigrationComplete: Bool {
        UserDefaults.standard.bool(forKey: migrationCompleteKey)
    }

    /// Known city coordinates for entries missing lat/lng
    static let cityCoordinates: [String: (lat: Double, lng: Double)] = [
        "Atlanta|GA|US":       (33.7490, -84.3880),
        "Asheville|NC|US":     (35.5951, -82.5515),
        "San Francisco|CA|US": (37.7749, -122.4194),
    ]

    func migrate(context: ModelContext) {
        guard !Self.isMigrationComplete else { return }

        let logs = (try? context.fetch(
            FetchDescriptor<NightLog>(sortBy: [SortDescriptor(\.date)])
        )) ?? []

        guard !logs.isEmpty else {
            UserDefaults.standard.set(true, forKey: Self.migrationCompleteKey)
            return
        }

        // Load existing CityColor mappings
        let cityColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
        let colorMap = Dictionary(uniqueKeysWithValues: cityColors.map { ($0.cityKey, $0.colorIndex) })

        var previousCityKey: String? = nil
        var cityStats: [String: (count: Int, firstDate: Date, lastDate: Date, lat: Double, lng: Double)] = [:]

        for log in logs {
            let city = log.city ?? "Unknown"
            let state = log.state ?? ""
            let country = log.country ?? "US"
            let cityKey = CityDisplayFormatter.cityKey(city: city, state: state, country: country)

            // Resolve coordinates
            let lat: Double
            let lng: Double
            if let logLat = log.latitude, let logLng = log.longitude, logLat != 0 {
                lat = logLat
                lng = logLng
            } else {
                let pipeKey = "\(city)|\(state)|\(country)"
                let coords = Self.cityCoordinates[pipeKey]
                lat = coords?.lat ?? 0.0
                lng = coords?.lng ?? 0.0
            }

            // Determine travel day
            let isTravelDay = previousCityKey != nil && previousCityKey != cityKey

            // Build citiesVisitedJSON as structured objects
            var cityObjects: [[String: String]] = [["city": city, "region": state, "country": country]]
            if isTravelDay, let prev = previousCityKey {
                let parts = prev.components(separatedBy: "|")
                if parts.count >= 3 {
                    cityObjects.insert(["city": parts[0], "region": parts[1], "country": parts[2]], at: 0)
                }
            }
            let citiesJSON = (try? JSONEncoder().encode(cityObjects))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

            // Create DailyEntry
            let entry = DailyEntry()
            entry.date = log.date
            entry.primaryCity = city
            entry.primaryRegion = state
            entry.primaryCountry = country
            entry.primaryLatitude = lat
            entry.primaryLongitude = lng
            entry.isTravelDay = isTravelDay
            entry.citiesVisitedJSON = citiesJSON
            entry.totalVisitHours = 24.0
            entry.sourceRaw = EntrySource.migratedRaw
            entry.confidenceRaw = EntryConfidence.mediumRaw
            entry.createdAt = log.capturedAt
            entry.updatedAt = Date()
            context.insert(entry)

            // Track city stats
            if var stats = cityStats[cityKey] {
                stats.count += 1
                stats.lastDate = log.date
                cityStats[cityKey] = stats
            } else {
                cityStats[cityKey] = (count: 1, firstDate: log.date, lastDate: log.date, lat: lat, lng: lng)
            }

            previousCityKey = cityKey
        }

        // Build CityRecords
        var maxColorIndex = colorMap.values.max() ?? -1
        for (cityKey, stats) in cityStats {
            let parts = cityKey.components(separatedBy: "|")
            let record = CityRecord()
            record.cityName = parts.count > 0 ? parts[0] : ""
            record.region = parts.count > 1 ? parts[1] : ""
            record.country = parts.count > 2 ? parts[2] : ""
            record.canonicalLatitude = stats.lat
            record.canonicalLongitude = stats.lng
            record.totalDays = stats.count
            record.firstVisitedDate = stats.firstDate
            record.lastVisitedDate = stats.lastDate

            if let existingColor = colorMap[cityKey] {
                record.colorIndex = existingColor
            } else {
                maxColorIndex += 1
                record.colorIndex = maxColorIndex
            }

            record.updatedAt = Date()
            context.insert(record)
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: Self.migrationCompleteKey)
    }
}
