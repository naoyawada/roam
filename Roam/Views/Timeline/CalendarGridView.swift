import SwiftUI
import SwiftData

struct CalendarGridView: View {
    let year: Int
    let month: Int
    let logs: [NightLog]
    let cityColors: [CityColor]
    let onDayTapped: (NightLog?, Date) -> Void

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private var firstDayOfMonth: Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1, hour: 12))!
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: firstDayOfMonth)!.count
    }

    private var firstWeekday: Int {
        // 1 = Sunday in Calendar
        calendar.component(.weekday, from: firstDayOfMonth) - 1
    }

    private var today: DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.dateComponents([.year, .month, .day], from: BackfillService.calendarTodayNoonUTC())
    }

    private func logFor(day: Int) -> NightLog? {
        let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return logs.first { calendar.isDate($0.date, inSameDayAs: targetDate) }
    }

    private func colorFor(log: NightLog?) -> Color? {
        guard let log, log.status != .unresolved else { return nil }
        let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
        guard let cityColor = cityColors.first(where: { $0.cityKey == key }) else { return nil }
        return ColorPalette.color(for: cityColor.colorIndex)
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        LazyVGrid(columns: columns, spacing: 4) {
            // Empty cells before first day
            ForEach(0..<firstWeekday, id: \.self) { _ in
                Color.clear.aspectRatio(1, contentMode: .fit)
            }

            // Day cells
            ForEach(1...daysInMonth, id: \.self) { day in
                let log = logFor(day: day)
                let isFuture = (year > today.year! || (year == today.year! && month > today.month!) ||
                               (year == today.year! && month == today.month! && day > today.day!))
                let isToday = (year == today.year! && month == today.month! && day == today.day!)

                let dayDate = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!

                DayCell(
                    day: day,
                    color: colorFor(log: log),
                    isUnresolved: log?.status == .unresolved,
                    isFuture: isFuture,
                    isToday: isToday
                )
                .onTapGesture {
                    if !isFuture {
                        onDayTapped(log, dayDate)
                    }
                }
            }
        }
    }
}
