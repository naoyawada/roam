import SwiftUI

struct YearSummaryBar: View {
    let cityDays: [(name: String, days: Int, color: Color)]
    let totalDays: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(Calendar.current.component(.year, from: .now)))
                    .fontWeight(.regular)
                    .font(.subheadline)
                    .foregroundStyle(RoamTheme.textPrimary)
                Spacer()
                AnimatingNumber(value: Double(animated ? totalDays : 0), suffix: " days logged")
                    .font(.caption)
                    .foregroundStyle(RoamTheme.textSecondary)
            }

            GeometryReader { geo in
                let spacing: CGFloat = 2
                let totalSpacing = spacing * CGFloat(max(cityDays.count - 1, 0))
                let availableWidth = geo.size.width - totalSpacing
                HStack(spacing: spacing) {
                    ForEach(Array(cityDays.enumerated()), id: \.offset) { _, entry in
                        let width = totalDays > 0
                            ? availableWidth * CGFloat(entry.days) / CGFloat(totalDays)
                            : 0
                        RoundedRectangle(cornerRadius: RoamTheme.yearBarCornerRadius)
                            .fill(entry.color)
                            .frame(width: max(width, 4))
                    }
                }
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: animated ? geo.size.width : 0)
                }
            }
            .frame(height: RoamTheme.yearBarHeight)
        }
        .onAppear {
            guard !animated else { return }
            if reduceMotion {
                animated = true
            } else {
                withAnimation(.easeOut(duration: 0.7).delay(0.1)) {
                    animated = true
                }
            }
        }
    }
}
