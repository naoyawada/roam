import SwiftUI
import SwiftData

struct DayDetailSheet: View {
    let log: NightLog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingCitySearch = false
    @State private var selectedCity: String?
    @State private var selectedState: String?
    @State private var selectedCountry: String?
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?

    private var dateString: String {
        log.date.formatted(date: .long, time: .omitted)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Date", value: dateString)
                    LabeledContent("City", value: CityDisplayFormatter.format(
                        city: log.city, state: log.state, country: log.country
                    ))
                    LabeledContent("Status", value: log.status.rawValue.capitalized)
                }

                if log.status == .confirmed || log.status == .manual {
                    Section("Capture Details") {
                        LabeledContent("Captured at", value: log.capturedAt.formatted(date: .omitted, time: .shortened))
                        if let accuracy = log.horizontalAccuracy {
                            LabeledContent("Accuracy", value: "\(Int(accuracy))m")
                        }
                        LabeledContent("Source", value: log.source.rawValue.capitalized)
                        if let lat = log.latitude, let lon = log.longitude {
                            LabeledContent("Coordinates", value: String(format: "%.4f, %.4f", lat, lon))
                        }
                    }
                }

                Section {
                    Button("Edit City") {
                        showingCitySearch = true
                    }
                }
            }
            .navigationTitle("Night Details")
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
                log.city = newCity
                log.state = selectedState
                log.country = selectedCountry
                log.latitude = selectedLatitude
                log.longitude = selectedLongitude
                log.source = .manual
                if log.status == .unresolved { log.status = .manual }

                let cityKey = CityDisplayFormatter.cityKey(city: newCity, state: selectedState, country: selectedCountry)
                let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
                if !existingColors.contains(where: { $0.cityKey == cityKey }) {
                    let nextIndex = (existingColors.map(\.colorIndex).max() ?? -1) + 1
                    context.insert(CityColor(cityKey: cityKey, colorIndex: nextIndex))
                }
                try? context.save()
            }
        }
        .tint(RoamTheme.accent)
        .presentationDetents([.medium, .large])
    }
}
