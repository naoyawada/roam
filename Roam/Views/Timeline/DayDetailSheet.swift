import SwiftUI
import SwiftData

struct DayDetailSheet: View {
    let entry: DailyEntry

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingCitySearch = false
    @State private var selectedCity: String?
    @State private var selectedState: String?
    @State private var selectedCountry: String?
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?

    private var dateString: String {
        entry.date.formatted(date: .long, time: .omitted)
    }

    private var confidenceLabel: String {
        switch entry.confidence {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    private var sourceLabel: String {
        switch entry.source {
        case .visit: return "Visit Detection"
        case .manual: return "Manual"
        case .propagated: return "Propagated"
        case .fallback: return "Fallback"
        case .migrated: return "Migrated"
        case .debug: return "Debug"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Date", value: dateString)
                    LabeledContent("City", value: CityDisplayFormatter.format(
                        city: entry.primaryCity.isEmpty ? nil : entry.primaryCity,
                        state: entry.primaryRegion.isEmpty ? nil : entry.primaryRegion,
                        country: entry.primaryCountry.isEmpty ? nil : entry.primaryCountry
                    ))
                    LabeledContent("Confidence", value: confidenceLabel)
                    if entry.isTravelDay {
                        LabeledContent("Travel Day", value: "Yes")
                    }
                }

                Section("Details") {
                    LabeledContent("Source", value: sourceLabel)
                    if entry.primaryLatitude != 0 || entry.primaryLongitude != 0 {
                        LabeledContent("Coordinates", value: String(format: "%.4f, %.4f", entry.primaryLatitude, entry.primaryLongitude))
                    }
                    if entry.totalVisitHours > 0 {
                        LabeledContent("Visit Hours", value: String(format: "%.1f", entry.totalVisitHours))
                    }
                }

                if entry.confidence != .high {
                    Section {
                        Button("Edit City") {
                            showingCitySearch = true
                        }
                    } footer: {
                        Text("This entry has \(confidenceLabel.lowercased()) confidence. Tap to set the correct city.")
                    }
                } else {
                    Section {
                        Button("Edit City") {
                            showingCitySearch = true
                        }
                    }
                }
            }
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCitySearch) {
                CitySearchView(
                    selectedCity: $selectedCity,
                    selectedState: $selectedState,
                    selectedCountry: $selectedCountry,
                    selectedLatitude: $selectedLatitude,
                    selectedLongitude: $selectedLongitude
                )
            }
            .onChange(of: selectedCity) { _, newCity in
                guard let newCity else { return }
                entry.primaryCity = newCity
                entry.primaryRegion = selectedState ?? ""
                entry.primaryCountry = selectedCountry ?? ""
                entry.primaryLatitude = selectedLatitude ?? 0
                entry.primaryLongitude = selectedLongitude ?? 0
                entry.source = .manual
                if entry.confidence == .low {
                    entry.confidence = .high
                }
                entry.updatedAt = .now

                // Ensure a CityRecord exists for this city
                let cityKey = CityDisplayFormatter.cityKey(city: newCity, state: selectedState, country: selectedCountry)
                let existingRecords = (try? context.fetch(FetchDescriptor<CityRecord>())) ?? []
                if !existingRecords.contains(where: { $0.cityKey == cityKey }) {
                    let nextIndex = (existingRecords.map(\.colorIndex).max() ?? -1) + 1
                    let newRecord = CityRecord()
                    newRecord.cityName = newCity
                    newRecord.region = selectedState ?? ""
                    newRecord.country = selectedCountry ?? ""
                    newRecord.colorIndex = nextIndex
                    newRecord.totalDays = 1
                    newRecord.firstVisitedDate = entry.date
                    newRecord.lastVisitedDate = entry.date
                    context.insert(newRecord)
                }

                // Also update legacy CityColor for backward compatibility
                let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
                if !existingColors.contains(where: { $0.cityKey == cityKey }) {
                    let nextColorIndex = (existingColors.map(\.colorIndex).max() ?? -1) + 1
                    context.insert(CityColor(cityKey: cityKey, colorIndex: nextColorIndex))
                }

                try? context.save()
            }
        }
        .tint(RoamTheme.accent)
        .presentationDetents([.medium, .large])
    }
}
