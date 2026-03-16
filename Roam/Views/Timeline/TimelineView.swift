import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NightLog.date) private var allLogs: [NightLog]
    @Query private var cityColors: [CityColor]

    @State private var displayedMonth = Calendar.current.component(.month, from: Date())
    @State private var displayedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedLog: NightLog?

    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols

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
                    ForEach(weekdaySymbols, id: \.self) { symbol in
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
                ) { log in
                    selectedLog = log
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
        let usedKeys = Set(allLogs.compactMap {
            $0.status != .unresolved ? CityDisplayFormatter.cityKey(city: $0.city, state: $0.state, country: $0.country) : nil
        })

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(cityColors.filter { usedKeys.contains($0.cityKey) }, id: \.cityKey) { cc in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ColorPalette.color(for: cc.colorIndex))
                            .frame(width: 10, height: 10)
                        Text(cc.cityKey.split(separator: "|").first.map(String.init) ?? "")
                            .font(.caption2)
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
