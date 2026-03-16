import Foundation

enum DateNormalization {

    /// Given a capture timestamp, return the normalized "night date" stored as noon UTC.
    ///
    /// Rule: if capture is before 6:00 AM local time, the night belongs to the previous calendar day.
    /// The result is noon UTC on the normalized calendar date.
    static func normalizedNightDate(from captureDate: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let hour = calendar.component(.hour, from: captureDate)
        let calendarDate: Date
        if hour < 6 {
            calendarDate = calendar.date(byAdding: .day, value: -1, to: captureDate)!
        } else {
            calendarDate = captureDate
        }

        let components = calendar.dateComponents([.year, .month, .day], from: calendarDate)

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
}
