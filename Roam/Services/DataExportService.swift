import Foundation
import SwiftData

enum DataExportService {

    // MARK: - DailyEntry export

    static func generateCSV(from entries: [DailyEntry]) -> String {
        var lines = ["date,city,region,country,latitude,longitude,source,confidence,total_visit_hours,is_travel_day,updated_at"]
        let formatter = ISO8601DateFormatter()
        for entry in entries {
            let fields = [
                formatter.string(from: entry.date),
                csvEscape(entry.primaryCity),
                csvEscape(entry.primaryRegion),
                csvEscape(entry.primaryCountry),
                String(entry.primaryLatitude),
                String(entry.primaryLongitude),
                entry.sourceRaw,
                entry.confidenceRaw,
                String(entry.totalVisitHours),
                entry.isTravelDay ? "true" : "false",
                formatter.string(from: entry.updatedAt)
            ]
            lines.append(fields.map { "\"\($0)\"" }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func generateJSON(from entries: [DailyEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        let dicts: [[String: Any]] = entries.map { entry in
            [
                "date": formatter.string(from: entry.date),
                "city": entry.primaryCity,
                "region": entry.primaryRegion,
                "country": entry.primaryCountry,
                "latitude": entry.primaryLatitude,
                "longitude": entry.primaryLongitude,
                "source": entry.sourceRaw,
                "confidence": entry.confidenceRaw,
                "total_visit_hours": entry.totalVisitHours,
                "is_travel_day": entry.isTravelDay,
                "updated_at": formatter.string(from: entry.updatedAt)
            ]
        }
        let data = try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted, .sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    /// Deduplicate entries for export: one per calendar date, keeping most recently updated.
    static func deduplicatedEntries(_ entries: [DailyEntry]) -> [DailyEntry] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let grouped = Dictionary(grouping: entries) {
            cal.dateComponents([.year, .month, .day], from: $0.date)
        }

        return grouped.values.map { group in
            group.sorted { $0.updatedAt > $1.updatedAt }.first!
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Private helpers

    private static func csvEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
