import SwiftUI

struct YearDotGridView: View {
    let year: Int
    let entries: [DailyEntry]
    let cityRecords: [CityRecord]
    let onMonthTapped: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(1...12, id: \.self) { month in
                MiniMonthGridView(
                    year: year,
                    month: month,
                    entries: entries,
                    cityRecords: cityRecords
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onMonthTapped(month)
                }
            }
        }
        .padding(.horizontal)
    }
}
