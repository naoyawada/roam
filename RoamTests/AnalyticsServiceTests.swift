import XCTest
import SwiftData
@testable import Roam

@MainActor
final class AnalyticsServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([DailyEntry.self, CityRecord.self, UserSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    func testDaysPerCity() {
        insertEntry(date: noonUTC(2026, 1, 1), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 1, 2), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 1, 3), city: "New York", region: "NY", country: "US")

        let analytics = AnalyticsService(context: context)
        let result = analytics.daysPerCity(year: 2026)

        XCTAssertEqual(result["Austin|TX|US"], 2)
        XCTAssertEqual(result["New York|NY|US"], 1)
    }

    func testCurrentStreak() {
        insertEntry(date: noonUTC(2026, 3, 13), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 3, 14), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 3, 15), city: "Austin", region: "TX", country: "US")

        let analytics = AnalyticsService(context: context)
        let streak = analytics.currentStreak(asOf: noonUTC(2026, 3, 16))

        XCTAssertEqual(streak.city, "Austin")
        XCTAssertEqual(streak.days, 3)
    }

    func testCurrentStreakBrokenByDifferentCity() {
        insertEntry(date: noonUTC(2026, 3, 13), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 3, 14), city: "New York", region: "NY", country: "US")
        insertEntry(date: noonUTC(2026, 3, 15), city: "Austin", region: "TX", country: "US")

        let analytics = AnalyticsService(context: context)
        let streak = analytics.currentStreak(asOf: noonUTC(2026, 3, 16))

        XCTAssertEqual(streak.city, "Austin")
        XCTAssertEqual(streak.days, 1)
    }

    func testLongestStreak() {
        insertEntry(date: noonUTC(2026, 1, 1), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 1, 2), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 1, 3), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 1, 4), city: "New York", region: "NY", country: "US")
        insertEntry(date: noonUTC(2026, 1, 5), city: "New York", region: "NY", country: "US")

        let analytics = AnalyticsService(context: context)
        let streak = analytics.longestStreak(year: 2026)

        XCTAssertEqual(streak.city, "Austin")
        XCTAssertEqual(streak.days, 3)
    }

    func testUniqueCitiesCount() {
        insertEntry(date: noonUTC(2026, 1, 1), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 1, 2), city: "New York", region: "NY", country: "US")
        insertEntry(date: noonUTC(2026, 1, 3), city: "Austin", region: "TX", country: "US")

        let analytics = AnalyticsService(context: context)
        XCTAssertEqual(analytics.uniqueCitiesCount(year: 2026), 2)
    }

    func testHomeAwayRatio() {
        insertEntry(date: noonUTC(2026, 1, 1), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 1, 2), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 1, 3), city: "Austin", region: "TX", country: "US")
        insertEntry(date: noonUTC(2026, 1, 4), city: "New York", region: "NY", country: "US")

        let analytics = AnalyticsService(context: context)
        let ratio = analytics.homeAwayRatio(year: 2026, homeCityKey: "Austin|TX|US")

        XCTAssertEqual(ratio.homePercentage, 0.75, accuracy: 0.01)
        XCTAssertEqual(ratio.awayPercentage, 0.25, accuracy: 0.01)
    }

    // MARK: - Helpers

    private func insertEntry(date: Date, city: String, region: String, country: String) {
        let entry = DailyEntry()
        entry.date = date
        entry.primaryCity = city
        entry.primaryRegion = region
        entry.primaryCountry = country
        entry.primaryLatitude = 0.0
        entry.primaryLongitude = 0.0
        entry.source = .visit
        entry.confidence = .high
        entry.createdAt = date
        entry.updatedAt = date
        context.insert(entry)
        try! context.save()
    }

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
