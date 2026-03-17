import Foundation
import SwiftData

enum DataImportService {

    enum ImportFormat {
        case csv
        case json
    }

    struct ImportResult {
        let imported: Int
        let skipped: Int
        let malformed: Int
    }

    struct ParsedEntry {
        let date: Date
        let city: String?
        let state: String?
        let country: String?
        let latitude: Double?
        let longitude: Double?
        let capturedAt: Date?
        let horizontalAccuracy: Double?
    }

    // MARK: - Public API

    static func importFile(content: String, format: ImportFormat, into context: ModelContext) -> ImportResult {
        let (entries, malformed) = switch format {
        case .csv: parseCSV(content)
        case .json: parseJSON(content)
        }

        let existingLogs = (try? context.fetch(FetchDescriptor<NightLog>())) ?? []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let existingDates = Set(existingLogs.map { cal.dateComponents([.year, .month, .day], from: $0.date) })

        var imported = 0
        var skipped = 0

        for entry in entries {
            let normalizedDate = DateNormalization.normalizedNightDate(from: entry.date)
            let dateComps = cal.dateComponents([.year, .month, .day], from: normalizedDate)
            if existingDates.contains(dateComps) {
                skipped += 1
                continue
            }

            let log = NightLog(
                date: normalizedDate,
                city: entry.city,
                state: entry.state,
                country: entry.country,
                latitude: entry.latitude,
                longitude: entry.longitude,
                capturedAt: entry.capturedAt ?? .now,
                horizontalAccuracy: entry.horizontalAccuracy,
                source: .manual,
                status: .confirmed
            )
            context.insert(log)
            imported += 1
        }

        try? context.save()
        return ImportResult(imported: imported, skipped: skipped, malformed: malformed)
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

        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            guard fields.count >= 10,
                  let date = formatter.date(from: fields[0]) else {
                malformed += 1
                continue
            }

            let entry = ParsedEntry(
                date: date,
                city: fields[1].nilIfEmpty,
                state: fields[2].nilIfEmpty,
                country: fields[3].nilIfEmpty,
                latitude: Double(fields[4]),
                longitude: Double(fields[5]),
                capturedAt: formatter.date(from: fields[8]),
                horizontalAccuracy: Double(fields[9])
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

            let entry = ParsedEntry(
                date: date,
                city: dict["city"] as? String,
                state: dict["state"] as? String,
                country: dict["country"] as? String,
                latitude: dict["latitude"] as? Double,
                longitude: dict["longitude"] as? Double,
                capturedAt: (dict["captured_at"] as? String).flatMap { formatter.date(from: $0) },
                horizontalAccuracy: dict["accuracy"] as? Double
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
