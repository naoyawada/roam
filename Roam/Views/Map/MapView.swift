import SwiftUI
import SwiftData
@preconcurrency import MapKit

struct MapView: View {
    @Query(sort: \NightLog.date) private var allLogs: [NightLog]
    @Query private var cityColors: [CityColor]

    @State private var selectedItem: CityMapItem?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var geocodedCoordinates: [String: CLLocationCoordinate2D] = [:]
    @State private var geocodingInProgress = false

    private var allCityData: [String: (logs: [NightLog], avgLat: Double?, avgLon: Double?)] {
        let confirmedRaw = LogStatus.confirmedRaw
        let manualRaw = LogStatus.manualRaw

        var groups: [String: [NightLog]] = [:]

        for log in allLogs {
            guard log.statusRaw == confirmedRaw || log.statusRaw == manualRaw,
                  let city = log.city, !city.isEmpty else { continue }

            let key = CityDisplayFormatter.cityKey(city: city, state: log.state, country: log.country)
            groups[key, default: []].append(log)
        }

        return groups.mapValues { logs in
            let withCoords = logs.filter { $0.latitude != nil && $0.longitude != nil }
            if withCoords.isEmpty {
                return (logs: logs, avgLat: nil, avgLon: nil)
            }
            let avgLat = withCoords.reduce(0.0) { $0 + ($1.latitude ?? 0) } / Double(withCoords.count)
            let avgLon = withCoords.reduce(0.0) { $0 + ($1.longitude ?? 0) } / Double(withCoords.count)
            return (logs: logs, avgLat: avgLat, avgLon: avgLon)
        }
    }

    private var cityItems: [CityMapItem] {
        allCityData.compactMap { key, data in
            let lat: Double
            let lon: Double

            if let avgLat = data.avgLat, let avgLon = data.avgLon {
                lat = avgLat
                lon = avgLon
            } else if let coord = geocodedCoordinates[key] {
                lat = coord.latitude
                lon = coord.longitude
            } else {
                return nil
            }

            let sorted = data.logs.sorted { $0.date < $1.date }
            guard let first = sorted.first, let last = sorted.last else { return nil }

            let parts = key.split(separator: "|")
            let city = parts.count > 0 ? String(parts[0]) : ""
            let state = parts.count > 1 ? String(parts[1]) : nil
            let country = parts.count > 2 ? String(parts[2]) : nil
            let displayName = CityDisplayFormatter.format(city: city, state: state, country: country)

            let colorIndex = cityColors.first(where: { $0.cityKey == key })?.colorIndex ?? 0
            let color = ColorPalette.color(for: colorIndex)

            return CityMapItem(
                id: key,
                displayName: displayName,
                latitude: lat,
                longitude: lon,
                totalNights: sorted.count,
                firstVisit: first.date,
                lastVisit: last.date,
                color: color
            )
        }
    }

    private var defaultRegion: MKCoordinateRegion {
        let timezone = TimeZone.current.identifier.split(separator: "/").first.map(String.init) ?? ""
        switch timezone {
        case "America": return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.6), span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50))
        case "Europe": return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 50.1, longitude: 9.7), span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30))
        case "Asia": return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0), span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50))
        case "Australia": return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -25.3, longitude: 133.8), span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30))
        case "Africa": return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 1.6, longitude: 17.3), span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50))
        default: return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 20, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120))
        }
    }

    private let mapStyle: MapStyle = .standard(emphasis: .muted, pointsOfInterest: .excludingAll)

    var body: some View {
        ZStack {
            if cityItems.isEmpty && !geocodingInProgress {
                Map(position: $cameraPosition) {}
                    .mapStyle(mapStyle)
                    .saturation(0)
                    .colorMultiply(Color(red: 0.96, green: 0.93, blue: 0.88))
                    .onAppear {
                        cameraPosition = .region(defaultRegion)
                    }

                Text("Your cities will appear here")
                    .font(.subheadline)
                    .foregroundStyle(RoamTheme.textSecondary)
            } else {
                Map(position: $cameraPosition) {
                    ForEach(cityItems) { item in
                        Annotation(item.displayName, coordinate: CLLocationCoordinate2D(
                            latitude: item.latitude,
                            longitude: item.longitude
                        )) {
                            CityPinAnnotation(color: item.color)
                                .onTapGesture {
                                    HapticService.selection()
                                    selectedItem = item
                                }
                        }
                    }
                }
                .mapStyle(mapStyle)
                .saturation(0)
                .colorMultiply(Color(red: 0.96, green: 0.93, blue: 0.88))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedItem) { item in
            CityDetailSheet(item: item)
                .presentationDetents([.height(200)])
        }
        .task {
            await geocodeMissingCities()
        }
    }

    private func geocodeMissingCities() async {
        let citiesNeedingGeocode = allCityData.filter { $0.value.avgLat == nil }
            .filter { !geocodedCoordinates.keys.contains($0.key) }

        guard !citiesNeedingGeocode.isEmpty else { return }
        geocodingInProgress = true

        for (key, _) in citiesNeedingGeocode {
            let parts = key.split(separator: "|")
            let city = parts.count > 0 ? String(parts[0]) : ""
            let state = parts.count > 1 ? String(parts[1]) : nil
            let country = parts.count > 2 ? String(parts[2]) : nil

            let searchString = [city, state, country].compactMap { $0 }.joined(separator: ", ")
            guard !searchString.isEmpty else { continue }

            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = searchString
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                if let item = response.mapItems.first {
                    geocodedCoordinates[key] = item.location.coordinate
                }
            } catch {
                // Skip cities that can't be geocoded
            }
        }

        geocodingInProgress = false
    }
}

