import Foundation

enum UnresolvedFilter {

    /// Returns unresolved NightLogs that represent completed nights (before today).
    /// `today` should be the current calendar date at noon UTC (from `BackfillService.calendarTodayNoonUTC()`).
    static func actionable(_ logs: [NightLog], today: Date) -> [NightLog] {
        logs.filter { $0.status == .unresolved && $0.date < today }
    }
}
