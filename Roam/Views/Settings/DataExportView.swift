import SwiftUI
import SwiftData

struct DataExportView: View {
    @Query(sort: \DailyEntry.date) private var allEntries: [DailyEntry]

    @State private var exportFormat: ExportFormat = .csv
    @State private var filterYear: Int? = nil
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingError = false
    @State private var exportFileURL: URL?

    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"

        var fileExtension: String {
            switch self {
            case .csv: "csv"
            case .json: "json"
            }
        }
    }

    private var filteredEntries: [DailyEntry] {
        let entries: [DailyEntry]
        if let year = filterYear {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            entries = allEntries.filter { cal.component(.year, from: $0.date) == year }
        } else {
            entries = Array(allEntries)
        }
        return DataExportService.deduplicatedEntries(entries)
    }

    private var availableYears: [Int] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let years = Set(allEntries.map { cal.component(.year, from: $0.date) })
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
                Button {
                    exportData()
                } label: {
                    HStack {
                        Text("Export \(filteredEntries.count) entries")
                        if isExporting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(filteredEntries.isEmpty || isExporting)
            }
        }
        .navigationTitle("Export Data")
        .sheet(item: $exportFileURL) { url in
            ActivityView(activityItems: [url])
        }
        .alert("Export Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError ?? "An unknown error occurred.")
        }
    }

    private func exportData() {
        isExporting = true
        let entries = filteredEntries
        let format = exportFormat

        let content: String
        switch format {
        case .csv:
            content = DataExportService.generateCSV(from: entries)
        case .json:
            content = DataExportService.generateJSON(from: entries)
        }

        let fileName = "roam-export.\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFileURL = tempURL
        } catch {
            exportError = error.localizedDescription
            showingError = true
        }

        isExporting = false
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
