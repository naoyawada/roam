import SwiftUI
import Charts

struct MonthlyBreakdownChart: View {
    let breakdown: [MonthlyBreakdown]
    let cityColors: [CityColor]

    private let monthLabels = Calendar.current.veryShortMonthSymbols

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Breakdown")
                .fontWeight(.semibold)

            Chart {
                ForEach(breakdown, id: \.month) { month in
                    ForEach(Array(month.cityDays.enumerated()), id: \.offset) { _, entry in
                        BarMark(
                            x: .value("Month", monthLabels[month.month - 1]),
                            y: .value("Days", entry.days)
                        )
                        .foregroundStyle(colorForCity(entry.cityKey))
                    }
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
        }
    }

    private func colorForCity(_ key: String) -> Color {
        guard let cc = cityColors.first(where: { $0.cityKey == key }) else {
            return .gray
        }
        return ColorPalette.color(for: cc.colorIndex)
    }
}
