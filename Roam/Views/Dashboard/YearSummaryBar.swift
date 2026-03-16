import SwiftUI

struct YearSummaryBar: View {
    let cityDays: [(name: String, days: Int, color: Color)]
    let totalDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(Calendar.current.component(.year, from: .now)))
                    .fontWeight(.medium)
                    .font(.subheadline)
                    .foregroundStyle(RoamTheme.textPrimary)
                Spacer()
                Text("\(totalDays) days logged")
                    .font(.caption)
                    .foregroundStyle(RoamTheme.textSecondary)
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(cityDays.enumerated()), id: \.offset) { _, entry in
                        let width = totalDays > 0
                            ? geo.size.width * CGFloat(entry.days) / CGFloat(totalDays)
                            : 0
                        RoundedRectangle(cornerRadius: RoamTheme.yearBarCornerRadius)
                            .fill(entry.color)
                            .frame(width: max(width, 4))
                    }
                }
            }
            .frame(height: RoamTheme.yearBarHeight)
        }
    }
}
