import SwiftUI
@preconcurrency import MapKit

struct CitySearchView: View {
    @Binding var selectedCity: String?
    @Binding var selectedState: String?
    @Binding var selectedCountry: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @State private var completer = CitySearchCompleter()

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { completion in
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
