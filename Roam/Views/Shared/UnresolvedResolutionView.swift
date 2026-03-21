import SwiftUI
import SwiftData

struct UnresolvedResolutionView: View {
    let log: NightLog
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCity: String?
    @State private var selectedState: String?
    @State private var selectedCountry: String?
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?
    @State private var showingCitySearch = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Where were you on \(log.date.formatted(date: .long, time: .omitted))?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let city = selectedCity {
                    Text(CityDisplayFormatter.format(city: city, state: selectedState, country: selectedCountry))
                        .font(.title3)
                        .fontWeight(.semibold)

                    Button("Confirm") {
                        HapticService.medium()
                        log.city = selectedCity
                        log.state = selectedState
                        log.country = selectedCountry
                        log.latitude = selectedLatitude
                        log.longitude = selectedLongitude
                        log.source = .manual
                        log.status = .manual

                        // Assign color if new city
                        let cityKey = CityDisplayFormatter.cityKey(city: selectedCity, state: selectedState, country: selectedCountry)
                        let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
                        if !existingColors.contains(where: { $0.cityKey == cityKey }) {
                            let nextIndex = (existingColors.map(\.colorIndex).max() ?? -1) + 1
                            context.insert(CityColor(cityKey: cityKey, colorIndex: nextIndex))
                        }

                        try? context.save()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Search for City") {
                    showingCitySearch = true
                }
            }
            .padding()
            .navigationTitle("Resolve Night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
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
            .tint(RoamTheme.accent)
        }
    }
}
