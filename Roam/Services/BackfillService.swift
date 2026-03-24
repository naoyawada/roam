import Foundation
import os
import SwiftData

enum BackfillService {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "Backfill")

    /// Calculate which nights are missing entries.
    /// Returns normalized dates (noon UTC) for each missed night.
    /// Looks back from yesterday up to maxDays. Only checks dates after the most recent existing entry.
    /// If no entries exist, checks the full maxDays window.
    /// Excludes today — the current night hasn't completed yet.
    static func missedNights(existingDates: [Date], today: Date, maxDays: Int = 30) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        // Find how far back to look: either to the most recent entry or maxDays
        let lookbackDays: Int
        if let mostRecent = existingDates.max() {
            let daysBetween = cal.dateComponents([.day], from: mostRecent, to: today).day ?? maxDays
            lookbackDays = min(max(daysBetween - 1, 0), maxDays)
        } else {
            lookbackDays = maxDays
        }

        guard lookbackDays > 0 else { return [] }

        // Build set of existing day keys
        let existingSet = Set(existingDates.map { date -> String in
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            return "\(comps.year!)-\(comps.month!)-\(comps.day!)"
        })

        var missed: [Date] = []
        for daysAgo in 1...lookbackDays {
            guard let candidate = cal.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let comps = cal.dateComponents([.year, .month, .day], from: candidate)
            let key = "\(comps.year!)-\(comps.month!)-\(comps.day!)"

            if !existingSet.contains(key) {
                var noonComps = comps
                noonComps.hour = 12
                noonComps.minute = 0
                noonComps.second = 0
                let noonDate = cal.date(from: noonComps)!
                missed.append(noonDate)
            }
        }
        return missed.reversed()  // chronological order
    }

    /// Run backfill on foreground launch. For missed nights, carries forward the
    /// city from the most recent confirmed/manual entry. If no prior entry exists,
    /// creates an .unresolved entry instead.
    @MainActor
    static func backfillMissedNights(context: ModelContext) {
        // Use the actual local calendar date (not normalizedNightDate) so we don't
        // accidentally skip last night during the 12AM-6AM window.
        // normalizedNightDate rolls back before 6 AM, which would make "today"
        // equal to last night's date, causing the backfill loop to skip it.
        let today = calendarTodayNoonUTC()

        let allLogs = (try? context.fetch(FetchDescriptor<NightLog>())) ?? []
        let existingDates = allLogs.map(\.date)

        let missed = missedNights(existingDates: existingDates, today: today)
        guard !missed.isEmpty else { return }

        // Find the most recent confirmed/manual entry to carry forward
        let confirmedRaw = LogStatus.confirmedRaw
        let manualRaw = LogStatus.manualRaw
        let anchor = allLogs
            .filter { $0.statusRaw == confirmedRaw || $0.statusRaw == manualRaw }
            .filter { $0.city != nil }
            .max(by: { $0.date < $1.date })

        for nightDate in missed {
            if let anchor {
                let log = NightLog(
                    date: nightDate,
                    city: anchor.city,
                    state: anchor.state,
                    country: anchor.country,
                    latitude: anchor.latitude,
                    longitude: anchor.longitude,
                    capturedAt: .now,
                    source: .automatic,
                    status: .confirmed
                )
                context.insert(log)
                logger.info("Backfilled \(nightDate) with \(anchor.city ?? "unknown")")
            } else {
                let log = NightLog(date: nightDate, capturedAt: .now, source: .automatic, status: .unresolved)
                context.insert(log)
                logger.info("Backfilled \(nightDate) as unresolved (no prior entry)")
            }
        }

        // Ensure city color exists for the carried-forward city
        if let anchor, let city = anchor.city {
            let cityKey = CityDisplayFormatter.cityKey(city: city, state: anchor.state, country: anchor.country)
            let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
            if !existingColors.contains(where: { $0.cityKey == cityKey }) {
                let nextIndex = (existingColors.map(\.colorIndex).max() ?? -1) + 1
                context.insert(CityColor(cityKey: cityKey, colorIndex: nextIndex))
            }
        }

        logger.info("Backfilled \(missed.count) missed night(s)")
        try? context.save()
    }

    /// The actual calendar date at noon UTC, using the user's local timezone
    /// to determine what "today" is. This avoids the before-6AM rollback
    /// that normalizedNightDate applies (which is for capture timestamps, not backfill).
    static func calendarTodayNoonUTC(now: Date = .now, timeZone: TimeZone = .current) -> Date {
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = timeZone
        let comps = localCal.dateComponents([.year, .month, .day], from: now)

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        return utcCal.date(from: DateComponents(
            year: comps.year, month: comps.month, day: comps.day,
            hour: 12, minute: 0, second: 0
        ))!
    }
}
