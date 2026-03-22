// RoamTests/CityPropagationTests.swift
import Testing
import Foundation
import SwiftData
@testable import Roam

struct CityPropagationTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: RawVisit.self, DailyEntry.self, CityRecord.self, PipelineEvent.self,
            configurations: config
        )
    }

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateHelpers.noonUTC(
            from: {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(identifier: "UTC")!
                return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
            }(),
            timeZone: TimeZone(identifier: "UTC")!
        )
    }

    @Test func propagatesLastKnownCityWhenNoDeparture() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = DailyEntry()
        existing.date = noonUTC(2026, 3, 20)
        existing.primaryCity = "Portland"
        existing.primaryRegion = "OR"
        existing.primaryCountry = "US"
        existing.primaryLatitude = 45.5
        existing.primaryLongitude = -122.6
        existing.sourceRaw = EntrySource.visitRaw
        existing.confidenceRaw = EntryConfidence.highRaw
        context.insert(existing)
        try context.save()

        let aggregator = DailyAggregator()
        let result = aggregator.propagate(
            for: noonUTC(2026, 3, 21),
            lastEntry: existing,
            recentVisits: []
        )

        #expect(result != nil)
        #expect(result?.primaryCity == "Portland")
        #expect(result?.confidenceRaw == EntryConfidence.mediumRaw)
        #expect(result?.sourceRaw == EntrySource.propagatedRaw)
    }

    @Test func detectsDepartureWhenVisitAtDifferentCity() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = DailyEntry()
        existing.date = noonUTC(2026, 3, 20)
        existing.primaryCity = "Portland"
        existing.primaryRegion = "OR"
        existing.primaryCountry = "US"
        existing.sourceRaw = EntrySource.visitRaw
        context.insert(existing)

        let sfVisit = RawVisit()
        sfVisit.resolvedCity = "San Francisco"
        sfVisit.resolvedRegion = "CA"
        sfVisit.resolvedCountry = "US"
        sfVisit.arrivalDate = noonUTC(2026, 3, 21)
        sfVisit.isCityResolved = true
        context.insert(sfVisit)
        try context.save()

        let aggregator = DailyAggregator()
        let result = aggregator.propagate(
            for: noonUTC(2026, 3, 21),
            lastEntry: existing,
            recentVisits: [sfVisit]
        )

        #expect(result == nil)
    }

    @Test func sameCityVisitDoesNotCountAsDeparture() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = DailyEntry()
        existing.date = noonUTC(2026, 3, 20)
        existing.primaryCity = "Portland"
        existing.primaryRegion = "OR"
        existing.primaryCountry = "US"
        existing.sourceRaw = EntrySource.visitRaw
        context.insert(existing)

        let pdxVisit = RawVisit()
        pdxVisit.resolvedCity = "Portland"
        pdxVisit.resolvedRegion = "OR"
        pdxVisit.resolvedCountry = "US"
        pdxVisit.arrivalDate = noonUTC(2026, 3, 21)
        pdxVisit.isCityResolved = true
        context.insert(pdxVisit)
        try context.save()

        let aggregator = DailyAggregator()
        let result = aggregator.propagate(
            for: noonUTC(2026, 3, 21),
            lastEntry: existing,
            recentVisits: [pdxVisit]
        )

        #expect(result != nil)
        #expect(result?.primaryCity == "Portland")
        #expect(result?.confidenceRaw == EntryConfidence.mediumRaw)
    }
}
