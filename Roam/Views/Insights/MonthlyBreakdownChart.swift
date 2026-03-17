import SwiftUI
import Charts

struct MonthlyBreakdownChart: View {
    let breakdown: [MonthlyBreakdown]
    let cityColors: [CityColor]

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
            .chartYScale(domain: 0...31)
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption2)
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

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if i > 0 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for (i, row) in rows.enumerated() {
            if i > 0 { y += spacing }
            var x = bounds.minX
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            for index in row {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var currentWidth: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(index)
            currentWidth += size.width + spacing
        }
        return rows
    }
}
