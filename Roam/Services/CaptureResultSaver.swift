import Foundation
import os
import SwiftData

enum CaptureResultSaver {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "CaptureResultSaver")

    @MainActor
    static func save(result: CaptureResult, context: ModelContext) {
        let nightDate = DateNormalization.normalizedNightDate(from: result.capturedAt)
        let existing = try? context.fetch(
            FetchDescriptor<NightLog>(predicate: #Predicate { $0.date == nightDate })
        ).first

        let unresolvedRaw = LogStatus.unresolvedRaw
        if let existing, existing.statusRaw != unresolvedRaw {
            logger.info("Entry already exists for \(nightDate), skipping")
            return
        }

        if let existing {
            existing.city = result.city
            existing.state = result.state
            existing.country = result.country
            existing.latitude = result.latitude
            existing.longitude = result.longitude
            existing.capturedAt = result.capturedAt
            existing.horizontalAccuracy = result.horizontalAccuracy
            existing.source = .automatic
            existing.status = .confirmed
        } else {
            let log = NightLog(
                date: nightDate,
                city: result.city,
                state: result.state,
                country: result.country,
                latitude: result.latitude,
                longitude: result.longitude,
                capturedAt: result.capturedAt,
                horizontalAccuracy: result.horizontalAccuracy,
                source: .automatic,
                status: .confirmed
            )
            context.insert(log)
        }

        let cityKey = CityDisplayFormatter.cityKey(city: result.city, state: result.state, country: result.country)
        let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
        if !existingColors.contains(where: { $0.cityKey == cityKey }) {
            let nextIndex = (existingColors.map(\.colorIndex).max() ?? -1) + 1
            context.insert(CityColor(cityKey: cityKey, colorIndex: nextIndex))
        }

        do {
            try context.save()
            logger.info("Saved confirmed entry: \(result.city) for \(nightDate)")
        } catch {
            logger.error("Failed to save entry: \(error.localizedDescription)")
        }
    }
}
