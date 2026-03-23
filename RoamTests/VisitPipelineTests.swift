// RoamTests/VisitPipelineTests.swift
import Testing
import Foundation
import SwiftData
import CoreLocation
@testable import Roam

struct VisitPipelineTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: RawVisit.self, DailyEntry.self, CityRecord.self, PipelineEvent.self,
            configurations: config
        )
    }

    @Test func handleVisitCreatesRawVisitAndDailyEntry() async throws {
        let container = try makeContainer()
        let logger = PipelineLogger(modelContainer: container)
        let pipeline = await VisitPipeline(modelContainer: container, logger: logger)

        let visitDate: Date = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            return cal.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 8))!
        }()
        let departureDate: Date = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            return cal.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 23))!
        }()

        await pipeline.handleVisitForTesting(
            visitData: VisitData(
                coordinate: CLLocationCoordinate2D(latitude: 45.5152, longitude: -122.6784),
                arrivalDate: visitDate,
                departureDate: departureDate,
                horizontalAccuracy: 10.0,
                source: "debug"
            ),
            resolvedCity: "Portland",
            resolvedRegion: "OR",
            resolvedCountry: "US"
        )

        // Verify RawVisit was created
        let context = ModelContext(container)
        let rawVisits = try context.fetch(FetchDescriptor<RawVisit>())
        #expect(rawVisits.count == 1)
        #expect(rawVisits.first?.isCityResolved == true)

        // Verify DailyEntry was created
        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.primaryCity == "Portland")
        #expect(entries.first?.confidenceRaw == EntryConfidence.highRaw)
    }
}
