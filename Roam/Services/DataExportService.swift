import Foundation
import SwiftData

enum DataExportService {
    static func generateCSV(from logs: [NightLog]) -> String {
        var lines = ["date,city,state,country,latitude,longitude,source,status,captured_at,accuracy"]
        let formatter = ISO8601DateFormatter()
        for log in logs {
            let fields = [
                formatter.string(from: log.date),
                csvEscape(log.city ?? ""),
                csvEscape(log.state ?? ""),
                csvEscape(log.country ?? ""),
                log.latitude.map { String($0) } ?? "",
                log.longitude.map { String($0) } ?? "",
                log.source.rawValue,
                log.status.rawValue,
                formatter.string(from: log.capturedAt),
                log.horizontalAccuracy.map { String(Int($0)) } ?? ""
            ]
            lines.append(fields.map { "\"\($0)\"" }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func generateJSON(from logs: [NightLog]) -> String {
        let formatter = ISO8601DateFormatter()
        let entries: [[String: Any]] = logs.map { log in
            var dict: [String: Any] = [
                "date": formatter.string(from: log.date),
                "source": log.source.rawValue,
                "status": log.status.rawValue,
                "captured_at": formatter.string(from: log.capturedAt)
            ]
            if let city = log.city { dict["city"] = city }
            if let state = log.state { dict["state"] = state }
            if let country = log.country { dict["country"] = country }
            if let lat = log.latitude { dict["latitude"] = lat }
            if let lon = log.longitude { dict["longitude"] = lon }
            if let acc = log.horizontalAccuracy { dict["accuracy"] = acc }
            return dict
        }
        let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    private static func csvEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
