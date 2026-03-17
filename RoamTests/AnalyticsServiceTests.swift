import XCTest
import SwiftData
@testable import Roam

@MainActor
final class AnalyticsServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let cloudConfig = ModelConfiguration(
            "cloud",
            schema: Schema([NightLog.self, CityColor.self]),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let localConfig = ModelConfiguration(
            "local",
            schema: Schema([UserSettings.self]),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        container = try ModelContainer(
            for: NightLog.self, CityColor.self, UserSettings.self,
            configurations: cloudConfig, localConfig
        )
        context = container.mainContext
    }

    func testDaysPerCity() {
        insertLog(date: noonUTC(2026, 1, 1), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 2), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 3), city: "New York", state: "NY", country: "US")

        let analytics = AnalyticsService(context: context)
        let result = analytics.daysPerCity(year: 2026)

        XCTAssertEqual(result["Austin|TX|US"], 2)
        XCTAssertEqual(result["New York|NY|US"], 1)
    }

    func testCurrentStreak() {
        insertLog(date: noonUTC(2026, 3, 13), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 3, 14), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 3, 15), city: "Austin", state: "TX", country: "US")

        let analytics = AnalyticsService(context: context)
        let streak = analytics.currentStreak(asOf: noonUTC(2026, 3, 16))

        XCTAssertEqual(streak.city, "Austin")
        XCTAssertEqual(streak.days, 3)
    }

    func testCurrentStreakBrokenByDifferentCity() {
        insertLog(date: noonUTC(2026, 3, 13), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 3, 14), city: "New York", state: "NY", country: "US")
        insertLog(date: noonUTC(2026, 3, 15), city: "Austin", state: "TX", country: "US")

        let analytics = AnalyticsService(context: context)
        let streak = analytics.currentStreak(asOf: noonUTC(2026, 3, 16))

        XCTAssertEqual(streak.city, "Austin")
        XCTAssertEqual(streak.days, 1)
    }

    func testLongestStreak() {
        insertLog(date: noonUTC(2026, 1, 1), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 2), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 3), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 4), city: "New York", state: "NY", country: "US")
        insertLog(date: noonUTC(2026, 1, 5), city: "New York", state: "NY", country: "US")

        let analytics = AnalyticsService(context: context)
        let streak = analytics.longestStreak(year: 2026)

        XCTAssertEqual(streak.city, "Austin")
        XCTAssertEqual(streak.days, 3)
    }

    func testUniqueCitiesCount() {
        insertLog(date: noonUTC(2026, 1, 1), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 2), city: "New York", state: "NY", country: "US")
        insertLog(date: noonUTC(2026, 1, 3), city: "Austin", state: "TX", country: "US")

        let analytics = AnalyticsService(context: context)
        XCTAssertEqual(analytics.uniqueCitiesCount(year: 2026), 2)
    }

    func testHomeAwayRatio() {
        insertLog(date: noonUTC(2026, 1, 1), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 2), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 3), city: "Austin", state: "TX", country: "US")
        insertLog(date: noonUTC(2026, 1, 4), city: "New York", state: "NY", country: "US")

        let analytics = AnalyticsService(context: context)
        let ratio = analytics.homeAwayRatio(year: 2026, homeCityKey: "Austin|TX|US")

        XCTAssertEqual(ratio.homePercentage, 0.75, accuracy: 0.01)
        XCTAssertEqual(ratio.awayPercentage, 0.25, accuracy: 0.01)
    }

    // MARK: - Helpers

    private func insertLog(date: Date, city: String, state: String, country: String) {
        let log = NightLog(
            date: date,
            city: city,
            state: state,
            country: country,
            capturedAt: date,
            source: .automatic,
            status: .confirmed
        )
        context.insert(log)
        try! context.save()
    }

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
