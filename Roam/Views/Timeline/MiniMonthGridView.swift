import SwiftUI

struct MiniMonthGridView: View {
    let year: Int
    let month: Int
    let logs: [NightLog]
    let cityColors: [CityColor]

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

    private var firstWeekdayOffset: Int {
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    /// Total cells used (offset + days). Pad to 42 (6 rows × 7) for uniform grid height.
    private var trailingPadCount: Int {
        let totalUsed = firstWeekdayOffset + daysInMonth
        let maxCells = 42 // 6 rows
        return maxCells - totalUsed
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
        let monthName = Calendar.current.shortMonthSymbols[month - 1]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 1.5), count: 7)

        VStack(alignment: .leading, spacing: 3) {
            Text(monthName)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 1.5) {
                // Leading offset
                ForEach((-firstWeekdayOffset)..<0, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }

                // Day cells
                ForEach(1...daysInMonth, id: \.self) { day in
                    let log = logFor(day: day)
                    let isFuture = (year > today.year! || (year == today.year! && month > today.month!) ||
                                   (year == today.year! && month == today.month! && day > today.day!))

                    if isFuture {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RoamTheme.surfaceSubtle)
                            .opacity(0.5)
                            .aspectRatio(1, contentMode: .fit)
                    } else if log?.status == .unresolved {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RoamTheme.unresolvedFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(RoamTheme.unresolvedBorder, style: StrokeStyle(lineWidth: 0.5, dash: [2]))
                            )
                            .aspectRatio(1, contentMode: .fit)
                    } else if let color = colorFor(log: log) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .aspectRatio(1, contentMode: .fit)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }

                // Trailing pad to fill 6 rows
                ForEach(0..<trailingPadCount, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }
}
