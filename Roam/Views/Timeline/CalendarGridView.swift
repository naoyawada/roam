import SwiftUI
import SwiftData

struct CalendarGridView: View {
    let year: Int
    let month: Int
    let entries: [DailyEntry]
    let cityRecords: [CityRecord]
    let onDayTapped: (DailyEntry?, Date) -> Void

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
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return offset
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

    /// Resolve colors for travel day cities from citiesVisitedJSON
    private func travelColorsFor(entry: DailyEntry?) -> [Color] {
        guard let entry, entry.isTravelDay,
              let data = entry.citiesVisitedJSON.data(using: .utf8),
              let cities = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return []
        }
        return cities.compactMap { cityDict in
            guard let city = cityDict["city"],
                  let region = cityDict["region"],
                  let country = cityDict["country"] else { return nil }
            let key = CityDisplayFormatter.cityKey(city: city, state: region, country: country)
            guard let record = cityRecords.first(where: { $0.cityKey == key }) else { return nil }
            return ColorPalette.color(for: record.colorIndex)
        }
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        LazyVGrid(columns: columns, spacing: 4) {
            // Empty cells before first day (negative IDs to avoid collision with day numbers)
            ForEach((-firstWeekday)..<0, id: \.self) { _ in
                Color.clear.aspectRatio(1, contentMode: .fit)
            }

            // Day cells
            ForEach(1...daysInMonth, id: \.self) { day in
                let entry = entryFor(day: day)
                let isFuture = (year > today.year! || (year == today.year! && month > today.month!) ||
                               (year == today.year! && month == today.month! && day > today.day!))
                let isToday = (year == today.year! && month == today.month! && day == today.day!)

                let dayDate = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!

                DayCell(
                    day: day,
                    color: colorFor(entry: entry),
                    travelColors: travelColorsFor(entry: entry),
                    confidence: entry?.confidence ?? .high,
                    isLowConfidence: entry?.confidence == .low,
                    isTravelDay: entry?.isTravelDay ?? false,
                    isFuture: isFuture,
                    isToday: isToday
                )
                .onTapGesture {
                    if !isFuture {
                        HapticService.selection()
                        onDayTapped(entry, dayDate)
                    }
                }
            }
        }
    }
}
