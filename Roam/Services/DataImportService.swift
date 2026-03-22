import Foundation
import SwiftData

enum DataImportService {

    enum ImportFormat {
        case csv
        case json
    }

    struct ImportResult {
        let imported: Int
        let updated: Int
        let skipped: Int
        let malformed: Int
    }

    struct ParsedEntry {
        let date: Date
        let city: String
        let region: String
        let country: String
        let latitude: Double
        let longitude: Double
        let totalVisitHours: Double
        let isTravelDay: Bool
        let confidence: String
        let updatedAt: Date?
    }

    // MARK: - Public API

    static func importFile(content: String, format: ImportFormat, into context: ModelContext) -> ImportResult {
        let (entries, malformed) = switch format {
        case .csv: parseCSV(content)
        case .json: parseJSON(content)
        }

        let existingEntries = (try? context.fetch(FetchDescriptor<DailyEntry>())) ?? []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var existingByDate: [DateComponents: DailyEntry] = [:]
        for entry in existingEntries {
            let comps = cal.dateComponents([.year, .month, .day], from: entry.date)
            if let current = existingByDate[comps] {
                // Keep the more recently updated entry in our lookup
                if entry.updatedAt > current.updatedAt {
                    existingByDate[comps] = entry
                }
            } else {
                existingByDate[comps] = entry
            }
        }

        var imported = 0
        var updated = 0
        var skipped = 0

        for parsed in entries {
            let normalizedDate = DateHelpers.noonUTC(from: parsed.date)
            let dateComps = cal.dateComponents([.year, .month, .day], from: normalizedDate)

            if let existing = existingByDate[dateComps] {
                // Date already present — update only if imported data is newer or existing has no city
                let importedUpdatedAt = parsed.updatedAt ?? .now
                if existing.primaryCity.isEmpty && !parsed.city.isEmpty {
                    existing.primaryCity = parsed.city
                    existing.primaryRegion = parsed.region
                    existing.primaryCountry = parsed.country
                    existing.primaryLatitude = parsed.latitude
                    existing.primaryLongitude = parsed.longitude
                    existing.totalVisitHours = parsed.totalVisitHours
                    existing.isTravelDay = parsed.isTravelDay
                    existing.confidenceRaw = parsed.confidence
                    existing.sourceRaw = EntrySource.manualRaw
                    existing.updatedAt = importedUpdatedAt
                    updated += 1
                } else {
                    skipped += 1
                }
                continue
            }

            let entry = DailyEntry()
            entry.date = normalizedDate
            entry.primaryCity = parsed.city
            entry.primaryRegion = parsed.region
            entry.primaryCountry = parsed.country
            entry.primaryLatitude = parsed.latitude
            entry.primaryLongitude = parsed.longitude
            entry.totalVisitHours = parsed.totalVisitHours
            entry.isTravelDay = parsed.isTravelDay
            entry.confidenceRaw = parsed.confidence
            entry.sourceRaw = EntrySource.manualRaw
            entry.createdAt = .now
            entry.updatedAt = parsed.updatedAt ?? .now
            context.insert(entry)
            existingByDate[dateComps] = entry
            imported += 1
        }

        try? context.save()

        // Ensure CityRecords exist for all imported cities (for color assignment)
        buildMissingCityRecords(context: context)

        return ImportResult(imported: imported, updated: updated, skipped: skipped, malformed: malformed)
    }

    // MARK: - CityRecord Builder

    /// Create CityRecords for any cities in DailyEntry that don't have one yet.
    /// Assigns colorIndex sequentially starting from the highest existing index.
    static func buildMissingCityRecords(context: ModelContext) {
        let allEntries = (try? context.fetch(FetchDescriptor<DailyEntry>())) ?? []
        let existingRecords = (try? context.fetch(FetchDescriptor<CityRecord>())) ?? []
        let existingKeys = Set(existingRecords.map(\.cityKey))
        var maxColorIndex = existingRecords.map(\.colorIndex).max() ?? -1

        // Group entries by city key to build stats
        var cityGroups: [String: (city: String, region: String, country: String, lat: Double, lng: Double, count: Int, firstDate: Date, lastDate: Date)] = [:]

        for entry in allEntries {
            let key = entry.cityKey
            guard !existingKeys.contains(key), !entry.primaryCity.isEmpty else { continue }
            if var group = cityGroups[key] {
                group.count += 1
                if entry.date < group.firstDate { group.firstDate = entry.date }
                if entry.date > group.lastDate { group.lastDate = entry.date }
                cityGroups[key] = group
            } else {
                cityGroups[key] = (
                    city: entry.primaryCity,
                    region: entry.primaryRegion,
                    country: entry.primaryCountry,
                    lat: entry.primaryLatitude,
                    lng: entry.primaryLongitude,
                    count: 1,
                    firstDate: entry.date,
                    lastDate: entry.date
                )
            }
        }

        for (_, group) in cityGroups.sorted(by: { $0.value.firstDate < $1.value.firstDate }) {
            maxColorIndex += 1
            let record = CityRecord()
            record.cityName = group.city
            record.region = group.region
            record.country = group.country
            record.canonicalLatitude = group.lat
            record.canonicalLongitude = group.lng
            record.colorIndex = maxColorIndex
            record.totalDays = group.count
            record.firstVisitedDate = group.firstDate
            record.lastVisitedDate = group.lastDate
            record.updatedAt = Date()
            context.insert(record)
        }

        try? context.save()
    }

    // MARK: - CSV Parsing

    static func parseCSV(_ content: String) -> (entries: [ParsedEntry], malformed: Int) {
        let lines = content.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else { return ([], 0) }

        let formatter = ISO8601DateFormatter()
        var entries: [ParsedEntry] = []
        var malformed = 0

        // Parse header to find column indices
        let headers = parseCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespaces) }
        let idx = buildColumnIndex(headers)

        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            guard let dateIdx = idx["date"],
                  dateIdx < fields.count,
                  let date = formatter.date(from: fields[dateIdx]) else {
                malformed += 1
                continue
            }

            let city = field(fields, idx["city"]) ?? ""
            let region = field(fields, idx["region"]) ?? field(fields, idx["state"]) ?? ""
            let country = field(fields, idx["country"]) ?? ""
            let latitude = field(fields, idx["latitude"]).flatMap { Double($0) } ?? 0.0
            let longitude = field(fields, idx["longitude"]).flatMap { Double($0) } ?? 0.0
            let totalVisitHours = field(fields, idx["total_visit_hours"]).flatMap { Double($0) } ?? 0.0
            let isTravelDay = field(fields, idx["is_travel_day"]) == "true"
            let confidence = field(fields, idx["confidence"]) ?? EntryConfidence.highRaw
            let updatedAt = field(fields, idx["updated_at"]).flatMap { formatter.date(from: $0) }

            let entry = ParsedEntry(
                date: date,
                city: city,
                region: region,
                country: country,
                latitude: latitude,
                longitude: longitude,
                totalVisitHours: totalVisitHours,
                isTravelDay: isTravelDay,
                confidence: confidence,
                updatedAt: updatedAt
            )
            entries.append(entry)
        }

        return (entries, malformed)
    }

    // MARK: - JSON Parsing

    static func parseJSON(_ content: String) -> (entries: [ParsedEntry], malformed: Int) {
        guard let data = content.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return ([], content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
        }

        let formatter = ISO8601DateFormatter()
        var entries: [ParsedEntry] = []
        var malformed = 0

        for dict in array {
            guard let dateString = dict["date"] as? String,
                  let date = formatter.date(from: dateString) else {
                malformed += 1
                continue
            }

            let city = dict["city"] as? String ?? ""
            let region = dict["region"] as? String ?? dict["state"] as? String ?? ""
            let country = dict["country"] as? String ?? ""
            let latitude = dict["latitude"] as? Double ?? 0.0
            let longitude = dict["longitude"] as? Double ?? 0.0
            let totalVisitHours = dict["total_visit_hours"] as? Double ?? 0.0
            let isTravelDay = dict["is_travel_day"] as? Bool ?? false
            let confidence = dict["confidence"] as? String ?? EntryConfidence.highRaw
            let updatedAt = (dict["updated_at"] as? String).flatMap { formatter.date(from: $0) }

            let entry = ParsedEntry(
                date: date,
                city: city,
                region: region,
                country: country,
                latitude: latitude,
                longitude: longitude,
                totalVisitHours: totalVisitHours,
                isTravelDay: isTravelDay,
                confidence: confidence,
                updatedAt: updatedAt
            )
            entries.append(entry)
        }

        return (entries, malformed)
    }

    // MARK: - CSV Line Parser

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]
            if inQuotes {
                if char == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }

    private static func buildColumnIndex(_ headers: [String]) -> [String: Int] {
        var index: [String: Int] = [:]
        for (i, header) in headers.enumerated() {
            index[header] = i
        }
        return index
    }

    private static func field(_ fields: [String], _ idx: Int?) -> String? {
        guard let idx, idx < fields.count else { return nil }
        let value = fields[idx]
        return value.isEmpty ? nil : value
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
