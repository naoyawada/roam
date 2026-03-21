import SwiftUI
import SwiftData
@preconcurrency import MapKit

struct CitySearchView: View {
    @Binding var selectedCity: String?
    @Binding var selectedState: String?
    @Binding var selectedCountry: String?
    @Binding var selectedLatitude: Double?
    @Binding var selectedLongitude: Double?

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \NightLog.date, order: .reverse) private var allLogs: [NightLog]
    @State private var searchText = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @State private var completer = CitySearchCompleter()

    private var recentCities: [(city: String, state: String?, country: String?, displayName: String)] {
        let currentYear = Calendar.current.component(.year, from: .now)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        var seen = Set<String>()
        var cities: [(city: String, state: String?, country: String?, displayName: String)] = []

        for log in allLogs {
            guard cal.component(.year, from: log.date) == currentYear,
                  log.status != .unresolved,
                  let city = log.city, !city.isEmpty else { continue }

            let key = CityDisplayFormatter.cityKey(city: city, state: log.state, country: log.country)
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let displayName = CityDisplayFormatter.format(city: city, state: log.state, country: log.country)
            cities.append((city: city, state: log.state, country: log.country, displayName: displayName))
        }
        return cities
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty && !recentCities.isEmpty {
                    Section("Recent") {
                        ForEach(recentCities, id: \.displayName) { entry in
                            Button {
                                HapticService.medium()
                                selectedCity = entry.city
                                selectedState = entry.state
                                selectedCountry = entry.country
                                dismiss()
                            } label: {
                                Text(entry.displayName)
                            }
                        }
                    }
                }

                if !results.isEmpty {
                    Section(searchText.isEmpty ? "" : "Search Results") {
                        ForEach(results, id: \.self) { completion in
                            Button {
                                Task { await selectCompletion(completion) }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(completion.title)
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search cities")
            .onChange(of: searchText) { _, newValue in
                completer.search(query: newValue) { completions in
                    results = completions
                }
            }
            .navigationTitle("Select City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(),
              let item = response.mapItems.first,
              let reps = item.addressRepresentations else { return }

        guard let city = reps.cityName else { return }
        selectedCity = city

        // Extract state from cityWithContext: "Austin, TX" -> "TX"
        selectedState = {
            guard let ctx = reps.cityWithContext else { return nil }
            let prefix = "\(city), "
            guard ctx.hasPrefix(prefix) else { return nil }
            return String(ctx.dropFirst(prefix.count))
        }()

        selectedCountry = reps.region?.identifier
        let location = item.location
        selectedLatitude = location.coordinate.latitude
        selectedLongitude = location.coordinate.longitude
        HapticService.medium()
        dismiss()
    }
}

private class CitySearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var handler: (([MKLocalSearchCompletion]) -> Void)?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(query: String, handler: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.handler = handler
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        handler?(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        handler?([])
    }
}
