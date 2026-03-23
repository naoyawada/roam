// RoamTests/DailyAggregatorTests.swift
import Testing
import Foundation
@testable import Roam

struct DailyAggregatorTests {
    let aggregator = DailyAggregator()

    private func makeVisit(
        city: String, region: String, country: String,
        lat: Double, lng: Double,
        arrival: Date, departure: Date
    ) -> RawVisit {
        let v = RawVisit()
        v.latitude = lat
        v.longitude = lng
        v.arrivalDate = arrival
        v.departureDate = departure
        v.resolvedCity = city
        v.resolvedRegion = region
        v.resolvedCountry = country
        v.isCityResolved = true
        return v
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func singleCityFullDay() {
        let visits = [
            makeVisit(city: "Portland", region: "OR", country: "US",
                     lat: 45.5, lng: -122.6,
                     arrival: date(2026, 3, 22, 8),
                     departure: date(2026, 3, 22, 23))
        ]
        let result = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result != nil)
        #expect(result?.primaryCity == "Portland")
        #expect(result?.isTravelDay == false)
        #expect(result?.confidenceRaw == EntryConfidence.highRaw)
    }

    @Test func travelDayTwoCities() {
        let visits = [
            makeVisit(city: "Portland", region: "OR", country: "US",
                     lat: 45.5, lng: -122.6,
                     arrival: date(2026, 3, 22, 7),
                     departure: date(2026, 3, 22, 11)),
            makeVisit(city: "San Francisco", region: "CA", country: "US",
                     lat: 37.7, lng: -122.4,
                     arrival: date(2026, 3, 22, 15),
                     departure: date(2026, 3, 22, 23))
        ]
        let result = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result != nil)
        #expect(result?.primaryCity == "San Francisco")  // 8 hours vs 4 hours
        #expect(result?.isTravelDay == true)
    }

    @Test func layoverFilteredOut() {
        let visits = [
            makeVisit(city: "Portland", region: "OR", country: "US",
                     lat: 45.5, lng: -122.6,
                     arrival: date(2026, 3, 22, 7),
                     departure: date(2026, 3, 22, 11)),
            makeVisit(city: "Denver", region: "CO", country: "US",
                     lat: 39.7, lng: -104.9,
                     arrival: date(2026, 3, 22, 14),
                     departure: date(2026, 3, 22, 15, 30)),  // 90 min layover
            makeVisit(city: "San Francisco", region: "CA", country: "US",
                     lat: 37.7, lng: -122.4,
                     arrival: date(2026, 3, 22, 18),
                     departure: date(2026, 3, 22, 23))
        ]
        let result = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result != nil)
        #expect(result?.isTravelDay == true)
        let json = result?.citiesVisitedJSON ?? "[]"
        #expect(!json.contains("Denver"))
    }

    @Test func midnightSplitCountsCorrectDay() {
        let visits = [
            makeVisit(city: "Portland", region: "OR", country: "US",
                     lat: 45.5, lng: -122.6,
                     arrival: date(2026, 3, 22, 22),
                     departure: date(2026, 3, 23, 8))
        ]
        let result22 = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result22 != nil)
        #expect(result22!.totalVisitHours >= 1.9 && result22!.totalVisitHours <= 2.1)

        let result23 = aggregator.aggregate(visits: visits, for: date(2026, 3, 23, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result23 != nil)
        #expect(result23!.totalVisitHours >= 7.9 && result23!.totalVisitHours <= 8.1)
    }

    @Test func allBelowThresholdFallsBackToLongest() {
        let visits = [
            makeVisit(city: "Denver", region: "CO", country: "US",
                     lat: 39.7, lng: -104.9,
                     arrival: date(2026, 3, 22, 10),
                     departure: date(2026, 3, 22, 11, 30)),
            makeVisit(city: "Chicago", region: "IL", country: "US",
                     lat: 41.8, lng: -87.6,
                     arrival: date(2026, 3, 22, 14),
                     departure: date(2026, 3, 22, 15))
        ]
        let result = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result != nil)
        #expect(result?.primaryCity == "Denver")
        #expect(result?.confidenceRaw == EntryConfidence.lowRaw)
    }

    @Test func noVisitsReturnsNil() {
        let result = aggregator.aggregate(visits: [], for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result == nil)
    }

    @Test func ongoingVisitClampedToNow() {
        let visits = [
            makeVisit(city: "Portland", region: "OR", country: "US",
                     lat: 45.5, lng: -122.6,
                     arrival: date(2026, 3, 22, 8),
                     departure: Date.distantFuture)
        ]
        let result = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result != nil)
        #expect(result!.totalVisitHours < 24.1)
    }
}
