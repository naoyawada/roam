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

        // Fire twice for the same entry
        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: false)
        await service.handleEntryCommitted(entry: entry, previousCityKey: nil, isNewEntry: true, isNewCity: false)

        // No evaluators are registered yet (Tasks 4-7), so no notifications fire.
        // This validates the dedup infrastructure doesn't crash.
        // Once evaluators are added, this should assert count == 1 (dedup prevents second).
        XCTAssertEqual(mockCenter.addedRequests.count, 0, "No evaluators registered yet — dedup infra should not crash")
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
