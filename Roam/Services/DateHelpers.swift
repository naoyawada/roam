// Roam/Services/DateHelpers.swift
import Foundation

enum DateHelpers {
    /// Convert a calendar date to noon UTC for stable storage.
    static func noonUTC(from date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        var noonComponents = DateComponents()
        noonComponents.year = components.year
        noonComponents.month = components.month
        noonComponents.day = components.day
        noonComponents.hour = 12
        noonComponents.minute = 0
        noonComponents.second = 0

        return utcCalendar.date(from: noonComponents)!
    }

    /// Returns the start of the calendar day (midnight) in the given timezone.
    static func startOfDay(for date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    /// Returns the start of the next calendar day in the given timezone.
    static func endOfDay(for date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }
}
