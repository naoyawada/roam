import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NightLog.date) private var allLogs: [NightLog]

    @State private var exportFormat: ExportFormat = .csv
    @State private var filterYear: Int? = nil
    @State private var showingShareSheet = false
    @State private var exportURL: URL?

    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
    }

    private var filteredLogs: [NightLog] {
        guard let year = filterYear else { return Array(allLogs) }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return allLogs.filter { cal.component(.year, from: $0.date) == year }
    }

    private var availableYears: [Int] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let years = Set(allLogs.map { cal.component(.year, from: $0.date) })
        return years.sorted().reversed()
    }

    var body: some View {
        Form {
            Section("Scope") {
                Picker("Year", selection: $filterYear) {
                    Text("All Time").tag(nil as Int?)
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year)).tag(year as Int?)
                    }
                }
            }

            Section("Format") {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button("Export \(filteredLogs.count) entries") {
                    exportData()
                }
            }
        }
        .navigationTitle("Export Data")
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareLink(item: url)
            }
        }
    }

    private func exportData() {
        let tempDir = FileManager.default.temporaryDirectory

        switch exportFormat {
        case .csv:
            let csv = generateCSV()
            let url = tempDir.appendingPathComponent("roam-export.csv")
            try? csv.write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
        case .json:
            let json = generateJSON()
            let url = tempDir.appendingPathComponent("roam-export.json")
            try? json.write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
        }
        showingShareSheet = true
    }

    private func generateCSV() -> String {
        var lines = ["date,city,state,country,latitude,longitude,source,status,captured_at,accuracy"]
        let formatter = ISO8601DateFormatter()
        for log in filteredLogs {
            let fields = [
                formatter.string(from: log.date),
                log.city ?? "",
                log.state ?? "",
                log.country ?? "",
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

    private func generateJSON() -> String {
        let formatter = ISO8601DateFormatter()
        let entries = filteredLogs.map { log -> [String: Any] in
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
        let data = try? JSONSerialization.data(withJSONObject: entries, options: .prettyPrinted)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}
