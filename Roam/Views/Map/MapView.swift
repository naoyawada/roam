import SwiftUI
import SwiftData
@preconcurrency import MapKit

struct MapView: View {
    @Query(sort: \NightLog.date) private var allLogs: [NightLog]
    @Query private var cityColors: [CityColor]

    @State private var selectedItem: CityMapItem?
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var cityItems: [CityMapItem] {
        let confirmedRaw = LogStatus.confirmedRaw
        let manualRaw = LogStatus.manualRaw

        var groups: [String: (logs: [NightLog], lat: Double, lon: Double, count: Int)] = [:]

        for log in allLogs {
            guard log.statusRaw == confirmedRaw || log.statusRaw == manualRaw,
                  let city = log.city, !city.isEmpty,
                  let lat = log.latitude, let lon = log.longitude else { continue }

            let key = CityDisplayFormatter.cityKey(city: city, state: log.state, country: log.country)
            if var group = groups[key] {
                group.logs.append(log)
                group.lat += lat
                group.lon += lon
                group.count += 1
                groups[key] = group
            } else {
                groups[key] = (logs: [log], lat: lat, lon: lon, count: 1)
            }
        }

        return groups.compactMap { key, group in
            let sorted = group.logs.sorted { $0.date < $1.date }
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
                latitude: group.lat / Double(group.count),
                longitude: group.lon / Double(group.count),
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

    var body: some View {
        ZStack {
            if cityItems.isEmpty {
                Map(position: $cameraPosition) {}
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
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
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedItem) { item in
            CityDetailSheet(item: item)
                .presentationDetents([.height(200)])
        }
    }
}
