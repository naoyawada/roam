import Foundation
import SwiftData
import os

enum CityColorService {
    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "CityColor")

    @MainActor
    static func assignMissingColors(context: ModelContext) {
        let allLogs = (try? context.fetch(FetchDescriptor<NightLog>())) ?? []
        let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
        let existingKeys = Set(existingColors.map(\.cityKey))
        let maxIndex = existingColors.map(\.colorIndex).max() ?? -1

        var nextIndex = maxIndex + 1
        var newKeys = Set<String>()

        for log in allLogs where log.city != nil {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            if !existingKeys.contains(key) && !newKeys.contains(key) {
                newKeys.insert(key)
                let cityColor = CityColor(cityKey: key, colorIndex: nextIndex)
                context.insert(cityColor)
                nextIndex += 1
            }
        }

        if !newKeys.isEmpty {
            try? context.save()
            logger.info("Assigned colors to \(newKeys.count) new cities")
        }
    }
}
