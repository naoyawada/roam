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
        let _dateString = dedupDateString(for: entry.date)
        _ = _dateString // Will be used by evaluators in Tasks 4-7

        // Priority 1-6 evaluated here (later tasks will add the actual evaluations)
        // Each type returns a UNNotificationRequest? — first non-nil wins
        let evaluators: [() -> UNNotificationRequest?] = [
            // Will be populated in Tasks 4-7
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
}
