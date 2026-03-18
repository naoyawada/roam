import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NightLog.date) private var allLogs: [NightLog]
    @Query private var cityColors: [CityColor]

    @State private var displayedMonth = Calendar.current.component(.month, from: Date())
    @State private var displayedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedLog: NightLog?

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let firstWeekday = Calendar.current.firstWeekday - 1
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Month navigation
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Text(monthYearString)
                        .font(.headline)
                    Spacer()
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.horizontal)

                // Weekday headers
                HStack(spacing: 4) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                // Calendar grid
                CalendarGridView(
                    year: displayedYear,
                    month: displayedMonth,
                    logs: allLogs,
                    cityColors: cityColors
                ) { log, date in
                    if let log {
                        selectedLog = log
                    } else {
                        // Create an unresolved entry for this empty day
                        let newLog = NightLog(date: date, capturedAt: .now, source: .manual, status: .unresolved)
                        context.insert(newLog)
                        try? context.save()
                        selectedLog = newLog
                    }
                }
                .padding(.horizontal)

                // Legend
                legend

                Spacer()
            }
            .grainBackground()
            .navigationTitle("Timeline")
            .sheet(item: $selectedLog) { log in
                DayDetailSheet(log: log)
            }
        }
    }

    private var monthYearString: String {
        let components = DateComponents(year: displayedYear, month: displayedMonth)
        let date = Calendar.current.date(from: components)!
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func previousMonth() {
        if displayedMonth == 1 {
            displayedMonth = 12
            displayedYear -= 1
        } else {
            displayedMonth -= 1
        }
    }

    private func nextMonth() {
        if displayedMonth == 12 {
            displayedMonth = 1
            displayedYear += 1
        } else {
            displayedMonth += 1
        }
    }

    private var legend: some View {
        var keyCounts: [String: Int] = [:]
        for log in allLogs where log.status != .unresolved {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            keyCounts[key, default: 0] += 1
        }
        let sorted = cityColors
            .filter { keyCounts[$0.cityKey] != nil }
            .sorted { keyCounts[$0.cityKey, default: 0] > keyCounts[$1.cityKey, default: 0] }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(sorted, id: \.cityKey) { cc in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ColorPalette.color(for: cc.colorIndex))
                            .frame(width: 10, height: 10)
                        let parts = cc.cityKey.split(separator: "|")
                        let city = parts.first.map(String.init)
                        let state = parts.count > 1 ? String(parts[1]) : nil
                        let country = parts.count > 2 ? String(parts[2]) : nil
                        Text(CityDisplayFormatter.format(city: city, state: state, country: country))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(RoamTheme.unresolvedFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(RoamTheme.unresolvedBorder, style: StrokeStyle(lineWidth: 1, dash: [2]))
                        )
                        .frame(width: 10, height: 10)
                    Text("Unresolved")
                        .font(.caption2)
                }
            }
            .padding(.horizontal)
        }
    }
}
