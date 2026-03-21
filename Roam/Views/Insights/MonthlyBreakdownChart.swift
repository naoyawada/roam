import SwiftUI
import Charts

struct MonthlyBreakdownChart: View {
    let breakdown: [MonthlyBreakdown]
    let cityColors: [CityColor]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedMonths: Set<Int> = []

    private let monthLabels = Calendar.current.veryShortMonthSymbols

    private var legendEntries: [(key: String, label: String, color: Color)] {
        var seen = Set<String>()
        var entries: [(key: String, label: String, color: Color)] = []
        var hasOther = false

        for month in breakdown {
            for entry in month.cityDays {
                guard !seen.contains(entry.cityKey) else { continue }
                seen.insert(entry.cityKey)

                if let cc = cityColors.first(where: { $0.cityKey == entry.cityKey }),
                   cc.colorIndex < ColorPalette.maxColoredCities {
                    let parts = entry.cityKey.split(separator: "|")
                    let city = parts.first.map(String.init)
                    let state = parts.count > 1 ? String(parts[1]) : nil
                    let country = parts.count > 2 ? String(parts[2]) : nil
                    let label = CityDisplayFormatter.format(city: city, state: state, country: country)
                    entries.append((key: entry.cityKey, label: label, color: ColorPalette.color(for: cc.colorIndex)))
                } else {
                    hasOther = true
                }
            }
        }

        // Sort by color index for consistent ordering
        entries.sort { a, b in
            let aIndex = cityColors.first(where: { $0.cityKey == a.key })?.colorIndex ?? Int.max
            let bIndex = cityColors.first(where: { $0.cityKey == b.key })?.colorIndex ?? Int.max
            return aIndex < bIndex
        }

        if hasOther {
            entries.append((key: "other", label: "Other", color: ColorPalette.otherColor))
        }

        return entries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Breakdown")
                .fontWeight(.regular)
                .font(.subheadline)
                .foregroundStyle(RoamTheme.textPrimary)

            Chart {
                ForEach(breakdown, id: \.month) { month in
                    let revealed = animatedMonths.contains(month.month)
                    ForEach(Array(month.cityDays.enumerated()), id: \.offset) { _, entry in
                        BarMark(
                            x: .value("Month", monthLabels[month.month - 1]),
                            y: .value("Days", revealed ? entry.days : 0)
                        )
                        .foregroundStyle(colorForCity(entry.cityKey))
                    }
                }
            }
            .chartYScale(domain: 0...31)
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .onAppear {
                guard animatedMonths.isEmpty else { return }
                for month in breakdown {
                    if reduceMotion {
                        animatedMonths.insert(month.month)
                    } else {
                        let delay = 0.15 + Double(month.month - 1) * 0.12
                        withAnimation(.easeOut(duration: 0.7).delay(delay)) {
                            _ = animatedMonths.insert(month.month)
                        }
                    }
                }
            }

            // Legend
            FlowLayout(spacing: 8) {
                ForEach(legendEntries, id: \.key) { entry in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(entry.color)
                            .frame(width: 10, height: 10)
                        Text(entry.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
