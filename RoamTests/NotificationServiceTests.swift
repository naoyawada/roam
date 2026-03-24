import XCTest
import SwiftData
import UserNotifications
@testable import Roam

@MainActor
final class MockNotificationCenter: NotificationScheduling {
    var addedRequests: [UNNotificationRequest] = []
    var pendingRequests: [UNNotificationRequest] = []
    var removedPendingIdentifiers: [String] = []
    var removedDeliveredIdentifiers: [String] = []
    var authorizationGranted = true

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(contentsOf: identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(contentsOf: identifiers)
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationGranted
    }
}

@MainActor
final class NotificationServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var mockCenter: MockNotificationCenter!
    var service: NotificationService!

    override func setUp() async throws {
        let schema = Schema([DailyEntry.self, CityRecord.self, UserSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        // Create settings with notifications enabled
        let settings = UserSettings(notificationsEnabled: true)
        context.insert(settings)
        try context.save()

        mockCenter = MockNotificationCenter()
        service = NotificationService(modelContainer: container, notificationCenter: mockCenter)
    }

    override func tearDown() {
        // Clean up dedup keys
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("notif-") }
        keys.forEach { defaults.removeObject(forKey: $0) }
    }

    func testPropagatedEntriesSkipped() async {
        let entry = makeEntry(city: "Portland", region: "OR", country: "US", source: .propagated)
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: false)

        XCTAssertTrue(mockCenter.addedRequests.isEmpty, "Propagated entries should not fire notifications")
    }

    func testNotificationsDisabledSkipsAll() async {
        // Disable master toggle
        let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
        settings.notificationsEnabled = false
        try! context.save()

        let entry = makeEntry(city: "Portland", region: "OR", country: "US")
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: false)

        XCTAssertTrue(mockCenter.addedRequests.isEmpty, "Disabled master toggle should skip all")
    }

    func testDeduplication() async {
        let entry = makeEntry(city: "Denver", region: "CO", country: "US")
        context.insert(entry)
        try! context.save()

        // Fire twice for the same entry — New City evaluator fires on first call
        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: true)
        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: true)

        XCTAssertEqual(mockCenter.addedRequests.count, 1, "Dedup should prevent second notification")
    }

    func testWelcomeHomeNotification() async {
        let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
        settings.homeCityKey = "Portland|OR|US"
        try! context.save()

        // Yesterday was away
        let yesterday = makeEntry(city: "Seattle", region: "WA", country: "US", date: noonUTC(2026, 3, 23))
        context.insert(yesterday)
        try! context.save()

        // Today: back home (1 day away)
        let entry = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, 24))
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Seattle|WA|US", isNewEntry: true, isNewCity: false)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        XCTAssertTrue(mockCenter.addedRequests.first?.content.body.contains("Welcome home") == true)
    }

    func testTripSummaryNotification() async {
        let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
        settings.homeCityKey = "Portland|OR|US"
        try! context.save()

        // 3 days away in Denver
        for day in 21...23 {
            let away = makeEntry(city: "Denver", region: "CO", country: "US", date: noonUTC(2026, 3, day))
            context.insert(away)
        }
        try! context.save()

        // Today: back home (3 days away -> trip summary, not welcome home)
        let entry = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, 24))
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Denver|CO|US", isNewEntry: true, isNewCity: false)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        XCTAssertTrue(mockCenter.addedRequests.first?.content.body.contains("Back from") == true)
    }

    func testWelcomeHomeVsTripSummaryMutualExclusion() async {
        let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
        settings.homeCityKey = "Portland|OR|US"
        try! context.save()

        // 2 days away -> should be Trip Summary (not Welcome Home)
        for day in 22...23 {
            let away = makeEntry(city: "Denver", region: "CO", country: "US", date: noonUTC(2026, 3, day))
            context.insert(away)
        }
        try! context.save()

        let entry = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, 24))
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Denver|CO|US", isNewEntry: true, isNewCity: false)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let body = mockCenter.addedRequests.first?.content.body ?? ""
        XCTAssertTrue(body.contains("Back from"), "2+ days away should trigger Trip Summary, got: \(body)")
        XCTAssertFalse(body.contains("Welcome home"), "Welcome Home should not fire for 2+ days away")
    }

    func testWelcomeHomeNoOpWithoutHomeCity() async {
        // No home city set
        let entry = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, 24))
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Seattle|WA|US", isNewEntry: true, isNewCity: false)

        let welcomeHome = mockCenter.addedRequests.filter { $0.content.body.contains("Welcome home") }
        XCTAssertTrue(welcomeHome.isEmpty, "Welcome Home should no-op without home city")
    }

    func testNewCityNotification() async {
        let entry = makeEntry(city: "Denver", region: "CO", country: "US")
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: true)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let body = mockCenter.addedRequests.first?.content.body ?? ""
        XCTAssertTrue(body.contains("First time in"), "Expected new city notification, got: \(body)")
    }

    func testWelcomeBackNotification() async {
        // Create CityRecord for Denver (visited before)
        let record = CityRecord()
        record.cityName = "Denver"
        record.region = "CO"
        record.country = "US"
        record.totalDays = 3
        context.insert(record)
        try! context.save()

        let entry = makeEntry(city: "Denver", region: "CO", country: "US")
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: false)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let body = mockCenter.addedRequests.first?.content.body ?? ""
        XCTAssertTrue(body.contains("Welcome back"), "Expected welcome back notification, got: \(body)")
    }

    func testWelcomeBackDoesNotFireForHomeCity() async {
        let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
        settings.homeCityKey = "Portland|OR|US"
        try! context.save()

        let record = CityRecord()
        record.cityName = "Portland"
        record.region = "OR"
        record.country = "US"
        record.totalDays = 50
        context.insert(record)
        try! context.save()

        let entry = makeEntry(city: "Portland", region: "OR", country: "US")
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Denver|CO|US", isNewEntry: true, isNewCity: false)

        let welcomeBack = mockCenter.addedRequests.filter { $0.content.body.contains("Welcome back") }
        XCTAssertTrue(welcomeBack.isEmpty, "Welcome Back should not fire for home city")
    }

    func testTravelDayNotification() async {
        let entry = makeEntry(
            city: "Seattle",
            region: "WA",
            country: "US",
            isTravelDay: true,
            citiesVisitedJSON: "[{\"city\":\"Portland\",\"region\":\"OR\",\"country\":\"US\"},{\"city\":\"Seattle\",\"region\":\"WA\",\"country\":\"US\"}]"
        )
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: false)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let body = mockCenter.addedRequests.first?.content.body ?? ""
        XCTAssertTrue(body.contains("Travel day"), "Expected travel day notification, got: \(body)")
    }

    func testStreakMilestoneNotification() async {
        // Build a 7-day streak in Portland
        for day in 18...24 {
            let e = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, day))
            context.insert(e)
        }
        try! context.save()

        // Fetch the entry for March 24 (today)
        let targetDate = noonUTC(2026, 3, 24)
        let entry = try! context.fetch(
            FetchDescriptor<DailyEntry>(
                predicate: #Predicate<DailyEntry> { $0.date == targetDate }
            )
        ).first!

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: false, isNewCity: false)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let body = mockCenter.addedRequests.first?.content.body ?? ""
        XCTAssertTrue(body.contains("streak") || body.contains("7 days"), "Expected streak notification, got: \(body)")
    }

    func testStreakDoesNotFireAtNonMilestone() async {
        // Build a 5-day streak (not a milestone)
        for day in 20...24 {
            let e = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, day))
            context.insert(e)
        }
        try! context.save()

        let targetDate = noonUTC(2026, 3, 24)
        let entry = try! context.fetch(
            FetchDescriptor<DailyEntry>(
                predicate: #Predicate<DailyEntry> { $0.date == targetDate }
            )
        ).first!

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: false, isNewCity: false)

        let streakNotifs = mockCenter.addedRequests.filter { $0.content.body.lowercased().contains("streak") }
        XCTAssertTrue(streakNotifs.isEmpty, "5 days is not a milestone — should not fire streak notification")
    }

    func testNewYearNotification() async {
        let dec31 = makeEntry(city: "Tokyo", region: "Tokyo", country: "JP", date: noonUTC(2025, 12, 31))
        context.insert(dec31)
        try! context.save()

        let jan1 = makeEntry(city: "Tokyo", region: "Tokyo", country: "JP", date: noonUTC(2026, 1, 1))
        context.insert(jan1)
        try! context.save()

        await service.handleEntryCommitted(entry: jan1, previousCityKey: "Tokyo|Tokyo|JP", isNewEntry: true, isNewCity: false)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let body = mockCenter.addedRequests.first?.content.body ?? ""
        XCTAssertTrue(body.contains("First city of 2026"), "Expected new year notification, got: \(body)")
    }

    func testNewYearNoOpForFirstTimeUser() async {
        let entry = makeEntry(city: "Denver", region: "CO", country: "US", date: noonUTC(2026, 1, 1))
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: true)

        let newYear = mockCenter.addedRequests.filter { $0.content.body.contains("First city of") }
        XCTAssertTrue(newYear.isEmpty, "New year should not fire for first-time user with no prior entries")
    }

    func testMonthlyRecapScheduling() async {
        for day in 1...20 {
            let e = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, day))
            context.insert(e)
        }
        try! context.save()

        let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
        settings.homeCityKey = "Portland|OR|US"
        try! context.save()

        await service.scheduleMonthlyRecap()

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let request = mockCenter.addedRequests.first!
        XCTAssertEqual(request.identifier, "notif-monthlyRecap")
        XCTAssertNotNil(request.trigger as? UNCalendarNotificationTrigger)
    }

    func testPriorityOrder() async {
        // New City (priority 3) AND Travel Day (priority 5) both trigger
        // New City should win
        let entry = makeEntry(
            city: "Denver",
            region: "CO",
            country: "US",
            isTravelDay: true,
            citiesVisitedJSON: "[{\"city\":\"Portland\",\"region\":\"OR\",\"country\":\"US\"},{\"city\":\"Denver\",\"region\":\"CO\",\"country\":\"US\"}]"
        )
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: true)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        let body = mockCenter.addedRequests.first?.content.body ?? ""
        XCTAssertTrue(body.contains("First time in"), "New City (priority 3) should win over Travel Day (priority 5), got: \(body)")
    }

    func testToggleRespected() async {
        let settings = try! context.fetch(FetchDescriptor<UserSettings>()).first!
        settings.notifyNewCity = false
        try! context.save()

        let entry = makeEntry(city: "Denver", region: "CO", country: "US")
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: true)

        XCTAssertTrue(mockCenter.addedRequests.isEmpty, "Disabled toggle should suppress that type")
    }

    func testSingleCallProducesOneEntryDrivenNotification() async {
        let entry = makeEntry(city: "Seattle", region: "WA", country: "US")
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: true)

        // Entry-driven priority chain produces at most 1 notification per call
        // (catchup-only-today and multi-date coalescing are enforced by VisitPipeline, not NotificationService)
        XCTAssertEqual(mockCenter.addedRequests.count, 1)
    }

    func testNewYearCoFiresWithPriorityType() async {
        // Dec 31 entry in previous year
        let dec31 = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2025, 12, 31))
        context.insert(dec31)
        try! context.save()

        // Jan 1 in a NEW city — should fire both New City AND New Year
        let jan1 = makeEntry(city: "Denver", region: "CO", country: "US", date: noonUTC(2026, 1, 1))
        context.insert(jan1)
        try! context.save()

        await service.handleEntryCommitted(entry: jan1, previousCityKey: "Portland|OR|US", isNewEntry: true, isNewCity: true)

        XCTAssertEqual(mockCenter.addedRequests.count, 2, "New Year should co-fire with New City")
        let bodies = mockCenter.addedRequests.map(\.content.body)
        XCTAssertTrue(bodies.contains(where: { $0.contains("First time in") }), "Expected New City notification")
        XCTAssertTrue(bodies.contains(where: { $0.contains("First city of 2026") }), "Expected New Year notification")
    }

    func testTripSummaryNoOpWithoutHomeCity() async {
        // No home city set — 3 days away then "return"
        for day in 21...23 {
            let away = makeEntry(city: "Denver", region: "CO", country: "US", date: noonUTC(2026, 3, day))
            context.insert(away)
        }
        try! context.save()

        let entry = makeEntry(city: "Portland", region: "OR", country: "US", date: noonUTC(2026, 3, 24))
        context.insert(entry)
        try! context.save()

        await service.handleEntryCommitted(entry: entry, previousCityKey: "Denver|CO|US", isNewEntry: true, isNewCity: false)

        let tripSummary = mockCenter.addedRequests.filter { $0.content.body.contains("Back from") }
        XCTAssertTrue(tripSummary.isEmpty, "Trip Summary should no-op without home city")
    }

    // MARK: - Helpers

    func makeEntry(
        city: String,
        region: String,
        country: String,
        date: Date? = nil,
        source: EntrySource = .visit,
        confidence: EntryConfidence = .high,
        isTravelDay: Bool = false,
        citiesVisitedJSON: String = "[]"
    ) -> DailyEntry {
        let entry = DailyEntry()
        entry.date = date ?? noonUTC(2026, 3, 24)
        entry.primaryCity = city
        entry.primaryRegion = region
        entry.primaryCountry = country
        entry.source = source
        entry.confidence = confidence
        entry.isTravelDay = isTravelDay
        entry.citiesVisitedJSON = citiesVisitedJSON
        entry.createdAt = Date()
        entry.updatedAt = Date()
        return entry
    }

    func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
