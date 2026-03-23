// RoamTests/LegacyMigratorTests.swift
import Testing
import Foundation
import SwiftData
@testable import Roam

struct LegacyMigratorTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: NightLog.self, CityColor.self, RawVisit.self, DailyEntry.self, CityRecord.self, PipelineEvent.self,
            configurations: config
        )
    }

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func migratesSingleEntry() throws {
        UserDefaults.standard.removeObject(forKey: LegacyMigrator.migrationCompleteKey)
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = NightLog(
            date: noonUTC(2026, 3, 1),
            city: "Atlanta", state: "GA", country: "US",
            latitude: 33.749, longitude: -84.388,
            capturedAt: Date(),
            source: .manual, status: .confirmed
        )
        context.insert(log)
        try context.save()

        let migrator = LegacyMigrator()
        migrator.migrate(context: context)

        let entries = try context.fetch(FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date)]))
        #expect(entries.count == 1)
        #expect(entries[0].primaryCity == "Atlanta")
        #expect(entries[0].sourceRaw == EntrySource.migratedRaw)
        #expect(entries[0].confidenceRaw == EntryConfidence.mediumRaw)
    }

    @Test func infersTravelDayOnCityTransition() throws {
        UserDefaults.standard.removeObject(forKey: LegacyMigrator.migrationCompleteKey)
        let container = try makeContainer()
        let context = ModelContext(container)

        let log1 = NightLog(date: noonUTC(2026, 1, 3), city: "Atlanta", state: "GA", country: "US",
                           latitude: 33.749, longitude: -84.388, capturedAt: Date(), source: .manual, status: .confirmed)
        let log2 = NightLog(date: noonUTC(2026, 1, 4), city: "Asheville", state: "NC", country: "US",
                           latitude: 35.595, longitude: -82.551, capturedAt: Date(), source: .manual, status: .confirmed)
        context.insert(log1)
        context.insert(log2)
        try context.save()

        let migrator = LegacyMigrator()
        migrator.migrate(context: context)

        let entries = try context.fetch(FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date)]))
        #expect(entries.count == 2)
        #expect(entries[0].isTravelDay == false)
        #expect(entries[1].isTravelDay == true)
        #expect(entries[1].citiesVisitedJSON.contains("Atlanta"))
        #expect(entries[1].citiesVisitedJSON.contains("Asheville"))
    }

    @Test func preservesColorIndexFromCityColor() throws {
        UserDefaults.standard.removeObject(forKey: LegacyMigrator.migrationCompleteKey)
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = NightLog(date: noonUTC(2026, 3, 1), city: "Atlanta", state: "GA", country: "US",
                          latitude: 33.749, longitude: -84.388, capturedAt: Date(), source: .manual, status: .confirmed)
        let color = CityColor(cityKey: "Atlanta|GA|US", colorIndex: 5)
        context.insert(log)
        context.insert(color)
        try context.save()

        let migrator = LegacyMigrator()
        migrator.migrate(context: context)

        let records = try context.fetch(FetchDescriptor<CityRecord>())
        #expect(records.count == 1)
        #expect(records[0].colorIndex == 5)
    }
}
