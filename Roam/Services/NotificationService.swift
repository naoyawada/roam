// Roam/Services/NotificationService.swift
import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationService {
    private let modelContainer: ModelContainer
    private let notificationCenter: NotificationScheduling

    init(modelContainer: ModelContainer, notificationCenter: NotificationScheduling) {
        self.modelContainer = modelContainer
        self.notificationCenter = notificationCenter
    }

    func handleEntryCommitted(entry: DailyEntry, previousCityKey: String?, isNewEntry: Bool, isNewCity: Bool) async {
        let context = ModelContext(modelContainer)

        // Gate: master toggle
        guard let settings = try? context.fetch(FetchDescriptor<UserSettings>()).first,
              settings.notificationsEnabled else { return }

        // Gate: skip propagated entries
        if entry.source == .propagated { return }

        // Prune old dedup keys (>30 days)
        pruneOldDedupKeys()

        // Evaluate notification types in priority order
        let dateString = dedupDateString(for: entry.date)

        // Each type returns a UNNotificationRequest? — first non-nil wins
        let evaluators: [() -> UNNotificationRequest?] = [
            { self.evaluateWelcomeHome(entry: entry, settings: settings, dateString: dateString, context: context) },
            { self.evaluateTripSummary(entry: entry, settings: settings, dateString: dateString, context: context) },
            { self.evaluateNewCity(entry: entry, settings: settings, dateString: dateString, isNewCity: isNewCity) },
            { self.evaluateWelcomeBack(entry: entry, settings: settings, dateString: dateString, previousCityKey: previousCityKey, isNewCity: isNewCity, context: context) },
        ]

        for evaluate in evaluators {
            if let request = evaluate() {
                // Check dedup
                let dedupKey = request.identifier
                guard !isDuplicate(key: dedupKey) else { return }
                markFired(key: dedupKey)
                try? await notificationCenter.add(request)
                return
            }
        }
    }

    // MARK: - Deduplication

    private func isDuplicate(key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) != nil
    }

    private func markFired(key: String) {
        UserDefaults.standard.set(Date(), forKey: key)
    }

    private func dedupDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private func pruneOldDedupKeys() {
        let defaults = UserDefaults.standard
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let allKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("notif-") }
        for key in allKeys {
            if let date = defaults.object(forKey: key) as? Date, date < cutoff {
                defaults.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Welcome Home (Priority 1)

    private func evaluateWelcomeHome(entry: DailyEntry, settings: UserSettings, dateString: String, context: ModelContext) -> UNNotificationRequest? {
        guard settings.notifyWelcomeHome,
              let homeCityKey = settings.homeCityKey,
              entry.cityKey == homeCityKey else { return nil }

        let daysAway = countConsecutiveDaysAway(before: entry.date, homeCityKey: homeCityKey, context: context)
        guard daysAway == 1 else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Roam"
        content.body = "Welcome home. Good to be back."
        content.sound = .default
        content.threadIdentifier = "welcomeHome"
        return UNNotificationRequest(identifier: "notif-welcomeHome-\(dateString)", content: content, trigger: nil)
    }

    // MARK: - Trip Summary (Priority 2)

    private func evaluateTripSummary(entry: DailyEntry, settings: UserSettings, dateString: String, context: ModelContext) -> UNNotificationRequest? {
        guard settings.notifyTripSummary,
              let homeCityKey = settings.homeCityKey,
              entry.cityKey == homeCityKey else { return nil }

        let daysAway = countConsecutiveDaysAway(before: entry.date, homeCityKey: homeCityKey, context: context)
        guard daysAway >= 2 else { return nil }

        // Get trip count for enrichment
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let year = cal.component(.year, from: entry.date)
        let analytics = AnalyticsService(context: context)
        let tripInfo = analytics.tripCount(year: year, homeCityKey: homeCityKey)

        // Find the most-visited away city during this trip for the copy
        let tripCityName = lastAwayCityName(before: entry.date, homeCityKey: homeCityKey, context: context)
        let tripCityDisplay = tripCityName ?? "your trip"

        let content = UNMutableNotificationContent()
        content.title = "Roam"
        content.body = "Back from \(daysAway) days away — your \(ordinal(tripInfo.count)) trip to \(tripCityDisplay) this year."
        content.sound = .default
        content.threadIdentifier = "tripSummary"
        return UNNotificationRequest(identifier: "notif-tripSummary-\(dateString)", content: content, trigger: nil)
    }

    // MARK: - New City (Priority 3)

    private func evaluateNewCity(entry: DailyEntry, settings: UserSettings, dateString: String, isNewCity: Bool) -> UNNotificationRequest? {
        guard settings.notifyNewCity, isNewCity else { return nil }

        let displayName = CityDisplayFormatter.format(city: entry.primaryCity, state: entry.primaryRegion, country: entry.primaryCountry)
        let content = UNMutableNotificationContent()
        content.title = "Roam"
        content.body = "First time in \(displayName)! Welcome."
        content.sound = .default
        content.threadIdentifier = "newCity"
        return UNNotificationRequest(identifier: "notif-newCity-\(dateString)", content: content, trigger: nil)
    }

    // MARK: - Welcome Back (Priority 4)

    private func evaluateWelcomeBack(entry: DailyEntry, settings: UserSettings, dateString: String, previousCityKey: String?, isNewCity: Bool, context: ModelContext) -> UNNotificationRequest? {
        guard settings.notifyWelcomeBack,
              !isNewCity,
              previousCityKey != entry.cityKey,
              entry.cityKey != settings.homeCityKey else { return nil }

        let cityName = entry.primaryCity
        let region = entry.primaryRegion
        let country = entry.primaryCountry
        let descriptor = FetchDescriptor<CityRecord>(
            predicate: #Predicate<CityRecord> {
                $0.cityName == cityName && $0.region == region && $0.country == country
            }
        )
        guard let record = try? context.fetch(descriptor).first else { return nil }

        let displayName = CityDisplayFormatter.format(city: entry.primaryCity, state: entry.primaryRegion, country: entry.primaryCountry)
        let visitCount = record.totalDays + 1
        let content = UNMutableNotificationContent()
        content.title = "Roam"
        content.body = "Welcome back to \(displayName)! Your \(ordinal(visitCount)) visit."
        content.sound = .default
        content.threadIdentifier = "welcomeBack"
        return UNNotificationRequest(identifier: "notif-welcomeBack-\(dateString)", content: content, trigger: nil)
    }

    // MARK: - Helpers

    private func countConsecutiveDaysAway(before date: Date, homeCityKey: String, context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { $0.date < date },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let entries = try? context.fetch(descriptor) else { return 0 }
        var count = 0
        for entry in entries {
            if entry.cityKey == homeCityKey { break }
            count += 1
        }
        return count
    }

    private func lastAwayCityName(before date: Date, homeCityKey: String, context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { $0.date < date },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let entries = try? context.fetch(descriptor) else { return nil }
        for entry in entries {
            if entry.cityKey == homeCityKey { break }
            return CityDisplayFormatter.format(city: entry.primaryCity, state: entry.primaryRegion, country: entry.primaryCountry)
        }
        return nil
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}
