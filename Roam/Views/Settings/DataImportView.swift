import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataImportView: View {
    @Environment(\.modelContext) private var context
    @State private var showingFilePicker = false
    @State private var importResult: DataImportService.ImportResult?
    @State private var showingResult = false
    @State private var importError: String?
    @State private var showingError = false

    var body: some View {
        Form {
            Section {
                Text("Import NightLog entries from a CSV or JSON file previously exported from Roam.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Choose File") {
                    showingFilePicker = true
                }
            }
        }
        .navigationTitle("Import Data")
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Import Complete", isPresented: $showingResult) {
            Button("OK", role: .cancel) { }
        } message: {
            if let result = importResult {
                Text(importSummary(result))
            }
        }
        .alert("Import Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError ?? "An unknown error occurred.")
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Unable to access the selected file."
                showingError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let format: DataImportService.ImportFormat =
                    url.pathExtension.lowercased() == "json" ? .json : .csv
                importResult = DataImportService.importFile(content: content, format: format, into: context)
                DeduplicationService.deduplicateNightLogs(context: context)
                DeduplicationService.deduplicateCityColors(context: context)
                CityColorService.assignMissingColors(context: context)
                showingResult = true
            } catch {
                importError = error.localizedDescription
                showingError = true
            }

        case .failure(let error):
            importError = error.localizedDescription
            showingError = true
        }
    }

    private func importSummary(_ result: DataImportService.ImportResult) -> String {
        var parts = ["\(result.imported) entries imported"]
        if result.updated > 0 {
            parts.append("\(result.updated) updated")
        }
        parts.append("\(result.skipped) skipped (duplicates)")
        if result.malformed > 0 {
            parts.append("\(result.malformed) malformed rows")
        }
        return parts.joined(separator: ", ")
    }
}
