import Foundation

enum CityDisplayFormatter {

    /// Format a city for display based on locale conventions.
    /// - Same country as device region: "City, State"
    /// - Different country: "City, Country" (localized country name)
    static func format(city: String?, state: String?, country: String?, deviceRegion: String? = nil) -> String {
        guard let city else { return "Unknown location" }

        let region = deviceRegion ?? Locale.current.region?.identifier ?? "US"

        if let country, country != region {
            let localizedCountry = Locale.current.localizedString(forRegionCode: country) ?? country
            return "\(city), \(localizedCountry)"
        } else if let state {
            return "\(city), \(state)"
        }
        return city
    }

    /// Generate a stable key for a city, used for CityColor mapping.
    static func cityKey(city: String?, state: String?, country: String?) -> String {
        [city, state, country].compactMap { $0 }.joined(separator: "|")
    }
}
