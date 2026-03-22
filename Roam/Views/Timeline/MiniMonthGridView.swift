import SwiftUI

struct MiniMonthGridView: View {
    let year: Int
    let month: Int
    let entries: [DailyEntry]
    let cityRecords: [CityRecord]

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

    /// Total cells used (offset + days). Pad to 42 (6 rows x 7) for uniform grid height.
    private var trailingPadCount: Int {
        let totalUsed = firstWeekdayOffset + daysInMonth
        let maxCells = 42 // 6 rows
        return maxCells - totalUsed
    }

    private var today: DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.dateComponents([.year, .month, .day], from: DateHelpers.noonUTC(from: .now))
    }

    private func entryFor(day: Int) -> DailyEntry? {
        let targetDate = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return entries.first { calendar.isDate($0.date, inSameDayAs: targetDate) }
    }

    private func colorFor(entry: DailyEntry?) -> Color? {
        guard let entry, entry.confidence != .low else { return nil }
        guard let record = cityRecords.first(where: { $0.cityKey == entry.cityKey }) else { return nil }
        return ColorPalette.color(for: record.colorIndex)
    }

    private func confidenceOpacity(for entry: DailyEntry?) -> Double {
        guard let entry else { return 1.0 }
        switch entry.confidence {
        case .high: return 1.0
        case .medium: return 0.7
        case .low: return 0.5
        }
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
                    let entry = entryFor(day: day)
                    let isFuture = (year > today.year! || (year == today.year! && month > today.month!) ||
                                   (year == today.year! && month == today.month! && day > today.day!))

                    if isFuture {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RoamTheme.surfaceSubtle)
                            .opacity(0.5)
                            .aspectRatio(1, contentMode: .fit)
                    } else if entry?.confidence == .low {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RoamTheme.unresolvedFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .strokeBorder(RoamTheme.unresolvedBorder, style: StrokeStyle(lineWidth: 0.5, dash: [2]))
                            )
                            .aspectRatio(1, contentMode: .fit)
                    } else if let color = colorFor(entry: entry) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .opacity(confidenceOpacity(for: entry))
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
