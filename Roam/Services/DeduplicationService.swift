import Foundation
import os
import SwiftData

enum DeduplicationService {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "Deduplication")

    // MARK: - DailyEntry deduplication

    /// Remove duplicate DailyEntry records that share the same noon-UTC date.
    /// Keeps the most recently updated entry as the winner.
    @MainActor
    static func deduplicateDailyEntries(context: ModelContext) {
        let allEntries = (try? context.fetch(FetchDescriptor<DailyEntry>())) ?? []

        let grouped = Dictionary(grouping: allEntries) { $0.date }

        var deletedCount = 0
        for (_, entries) in grouped where entries.count > 1 {
            let sorted = entries.sorted { $0.updatedAt > $1.updatedAt }
            for entry in sorted.dropFirst() {
                context.delete(entry)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try? context.save()
            logger.info("Deduplicated \(deletedCount) DailyEntry records")
        }
    }

    // MARK: - CityRecord deduplication

    /// Remove duplicate CityRecord entries that share the same cityName + region + country.
    /// Keeps the entry with the lowest colorIndex (earliest assigned color).
    @MainActor
    static func deduplicateCityRecords(context: ModelContext) {
        let allRecords = (try? context.fetch(FetchDescriptor<CityRecord>())) ?? []

        let grouped = Dictionary(grouping: allRecords) { $0.cityKey }

        var deletedCount = 0
        for (_, records) in grouped where records.count > 1 {
            let sorted = records.sorted { $0.colorIndex < $1.colorIndex }
            for record in sorted.dropFirst() {
                context.delete(record)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try? context.save()
            logger.info("Deduplicated \(deletedCount) CityRecord entries")
        }
    }

}
