import Foundation
import os
import SwiftData

enum DeduplicationService {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "Deduplication")

    /// Remove duplicate NightLog entries that share the same date.
    /// Keeps the best entry per priority: confirmed > manual > unresolved,
    /// then most recent capturedAt as tiebreaker.
    @MainActor
    static func deduplicateNightLogs(context: ModelContext) {
        let allLogs = (try? context.fetch(FetchDescriptor<NightLog>())) ?? []

        let grouped = Dictionary(grouping: allLogs) { $0.date }

        var deletedCount = 0
        for (_, logs) in grouped where logs.count > 1 {
            let sorted = logs.sorted { a, b in
                let aPriority = statusPriority(a.status)
                let bPriority = statusPriority(b.status)
                if aPriority != bPriority {
                    return aPriority < bPriority
                }
                return a.capturedAt > b.capturedAt
            }

            for log in sorted.dropFirst() {
                context.delete(log)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try? context.save()
            logger.info("Deduplicated \(deletedCount) NightLog entries")
        }
    }

    private static func statusPriority(_ status: LogStatus) -> Int {
        switch status {
        case .confirmed: return 0
        case .manual: return 1
        case .unresolved: return 2
        }
    }
}
