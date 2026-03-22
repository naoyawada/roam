// Roam/Views/Settings/DebugScenarios.swift
import Foundation
import CoreLocation

// MARK: - Preset Cities

struct DebugCity {
    let name: String
    let state: String
    let country: String
    let coordinate: CLLocationCoordinate2D

    static let portland = DebugCity(name: "Portland", state: "OR", country: "US",
                                    coordinate: CLLocationCoordinate2D(latitude: 45.5152, longitude: -122.6784))
    static let sanFrancisco = DebugCity(name: "San Francisco", state: "CA", country: "US",
                                        coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))
    static let newYork = DebugCity(name: "New York", state: "NY", country: "US",
                                   coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060))
    static let losAngeles = DebugCity(name: "Los Angeles", state: "CA", country: "US",
                                      coordinate: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437))
    static let denver = DebugCity(name: "Denver", state: "CO", country: "US",
                                  coordinate: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903))
    static let chicago = DebugCity(name: "Chicago", state: "IL", country: "US",
                                   coordinate: CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298))
    static let tokyo = DebugCity(name: "Tokyo", state: "Tokyo", country: "JP",
                                 coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503))
    static let london = DebugCity(name: "London", state: "England", country: "GB",
                                  coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278))
    static let sydney = DebugCity(name: "Sydney", state: "NSW", country: "AU",
                                  coordinate: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093))

    static let allPresets: [DebugCity] = [
        .portland, .sanFrancisco, .newYork, .losAngeles,
        .denver, .chicago, .tokyo, .london, .sydney
    ]

    func visitData(arrival: Date, departure: Date) -> VisitData {
        VisitData(
            coordinate: coordinate,
            arrivalDate: arrival,
            departureDate: departure,
            horizontalAccuracy: 10.0,
            source: "debug"
        )
    }
}

// MARK: - Date Extension

extension Date {
    func adjustedToHour(_ hour: Int, minute: Int = 0) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        var comps = cal.dateComponents([.year, .month, .day], from: self)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return cal.date(from: comps) ?? self
    }
}

// MARK: - Preset Scenarios

struct DebugScenario {
    let name: String
    let description: String
    let visits: [DebugScenarioVisit]
}

struct DebugScenarioVisit {
    let visitData: VisitData
    let resolvedCity: String
    let resolvedRegion: String
    let resolvedCountry: String
}

enum DebugScenarios {

    static var allScenarios: [DebugScenario] {
        [normalWeek, stationaryWeek, tripWithLayover, redEyeFlight, dayTrip, dataGap]
    }

    // MARK: - Normal Week
    // 7 days at home in Portland, daily 8AM–11PM
    static var normalWeek: DebugScenario {
        let base = Date()
        var visits: [DebugScenarioVisit] = []
        for dayOffset in 0..<7 {
            let day = Calendar.current.date(byAdding: .day, value: -dayOffset, to: base)!
            let arrival = day.adjustedToHour(8)
            let departure = day.adjustedToHour(23)
            let vd = DebugCity.portland.visitData(arrival: arrival, departure: departure)
            visits.append(DebugScenarioVisit(
                visitData: vd,
                resolvedCity: DebugCity.portland.name,
                resolvedRegion: DebugCity.portland.state,
                resolvedCountry: DebugCity.portland.country
            ))
        }
        return DebugScenario(
            name: "Normal Week",
            description: "7 days at home in Portland (8AM–11PM daily)",
            visits: visits
        )
    }

    // MARK: - Stationary Week
    // Single arrival visit on day 1, nothing for days 2–7 (tests propagation)
    static var stationaryWeek: DebugScenario {
        let base = Date()
        let day1 = Calendar.current.date(byAdding: .day, value: -6, to: base)!
        let arrival = day1.adjustedToHour(9)
        let departure = Date.distantFuture
        let vd = DebugCity.portland.visitData(arrival: arrival, departure: departure)
        let visit = DebugScenarioVisit(
            visitData: vd,
            resolvedCity: DebugCity.portland.name,
            resolvedRegion: DebugCity.portland.state,
            resolvedCountry: DebugCity.portland.country
        )
        return DebugScenario(
            name: "Stationary Week",
            description: "Single arrival on day 1 — tests city propagation across 7 days",
            visits: [visit]
        )
    }

    // MARK: - Trip with Layover
    // Portland morning -> Denver 90min layover -> SF evening, 2 days in SF
    static var tripWithLayover: DebugScenario {
        let base = Date()
        let day0 = Calendar.current.date(byAdding: .day, value: -2, to: base)!
        let day1 = Calendar.current.date(byAdding: .day, value: -1, to: base)!
        let day2 = base

        // Portland: 6AM depart
        let pdxVisit = DebugCity.portland.visitData(
            arrival: day0.adjustedToHour(0),
            departure: day0.adjustedToHour(6)
        )
        // Denver layover: arrive 9AM, depart 10:30AM
        let denVisit = DebugCity.denver.visitData(
            arrival: day0.adjustedToHour(9),
            departure: day0.adjustedToHour(10, minute: 30)
        )
        // SF: arrive 1PM
        let sfVisit1 = DebugCity.sanFrancisco.visitData(
            arrival: day0.adjustedToHour(13),
            departure: day1.adjustedToHour(23)
        )
        // SF day 2
        let sfVisit2 = DebugCity.sanFrancisco.visitData(
            arrival: day2.adjustedToHour(0),
            departure: day2.adjustedToHour(22)
        )

        return DebugScenario(
            name: "Trip with Layover",
            description: "Portland → Denver (90min) → San Francisco, 2 nights in SF",
            visits: [
                DebugScenarioVisit(visitData: pdxVisit, resolvedCity: DebugCity.portland.name,
                                   resolvedRegion: DebugCity.portland.state, resolvedCountry: DebugCity.portland.country),
                DebugScenarioVisit(visitData: denVisit, resolvedCity: DebugCity.denver.name,
                                   resolvedRegion: DebugCity.denver.state, resolvedCountry: DebugCity.denver.country),
                DebugScenarioVisit(visitData: sfVisit1, resolvedCity: DebugCity.sanFrancisco.name,
                                   resolvedRegion: DebugCity.sanFrancisco.state, resolvedCountry: DebugCity.sanFrancisco.country),
                DebugScenarioVisit(visitData: sfVisit2, resolvedCity: DebugCity.sanFrancisco.name,
                                   resolvedRegion: DebugCity.sanFrancisco.state, resolvedCountry: DebugCity.sanFrancisco.country)
            ]
        )
    }

    // MARK: - Red-Eye Flight
    // SF full day, depart 11PM, arrive NYC 7AM next day
    static var redEyeFlight: DebugScenario {
        let base = Date()
        let day0 = Calendar.current.date(byAdding: .day, value: -1, to: base)!
        let day1 = base

        // SF full day until 11PM
        let sfVisit = DebugCity.sanFrancisco.visitData(
            arrival: day0.adjustedToHour(8),
            departure: day0.adjustedToHour(23)
        )
        // NYC: arrive 7AM next day
        let nycVisit = DebugCity.newYork.visitData(
            arrival: day1.adjustedToHour(7),
            departure: day1.adjustedToHour(23)
        )

        return DebugScenario(
            name: "Red-Eye Flight",
            description: "SF full day, depart 11PM → arrive NYC 7AM next day",
            visits: [
                DebugScenarioVisit(visitData: sfVisit, resolvedCity: DebugCity.sanFrancisco.name,
                                   resolvedRegion: DebugCity.sanFrancisco.state, resolvedCountry: DebugCity.sanFrancisco.country),
                DebugScenarioVisit(visitData: nycVisit, resolvedCity: DebugCity.newYork.name,
                                   resolvedRegion: DebugCity.newYork.state, resolvedCountry: DebugCity.newYork.country)
            ]
        )
    }

    // MARK: - Day Trip
    // Portland base, 4hrs at Cannon Beach coast
    static var dayTrip: DebugScenario {
        let base = Date()
        let cannonBeachCoord = CLLocationCoordinate2D(latitude: 45.8918, longitude: -123.9615)

        let pdxMorning = DebugCity.portland.visitData(
            arrival: base.adjustedToHour(7),
            departure: base.adjustedToHour(10)
        )
        let cannonBeachVD = VisitData(
            coordinate: cannonBeachCoord,
            arrivalDate: base.adjustedToHour(11),
            departureDate: base.adjustedToHour(15),
            horizontalAccuracy: 10.0,
            source: "debug"
        )
        let pdxEvening = DebugCity.portland.visitData(
            arrival: base.adjustedToHour(16),
            departure: base.adjustedToHour(23)
        )

        return DebugScenario(
            name: "Day Trip",
            description: "Portland base with 4hr visit to Cannon Beach coast",
            visits: [
                DebugScenarioVisit(visitData: pdxMorning, resolvedCity: DebugCity.portland.name,
                                   resolvedRegion: DebugCity.portland.state, resolvedCountry: DebugCity.portland.country),
                DebugScenarioVisit(visitData: cannonBeachVD, resolvedCity: "Cannon Beach",
                                   resolvedRegion: "OR", resolvedCountry: "US"),
                DebugScenarioVisit(visitData: pdxEvening, resolvedCity: DebugCity.portland.name,
                                   resolvedRegion: DebugCity.portland.state, resolvedCountry: DebugCity.portland.country)
            ]
        )
    }

    // MARK: - Data Gap
    // Empty visits array (tests catch-up)
    static var dataGap: DebugScenario {
        DebugScenario(
            name: "Data Gap",
            description: "Empty visits — tests catch-up and gap handling",
            visits: []
        )
    }
}
