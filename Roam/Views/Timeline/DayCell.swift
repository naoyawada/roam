import SwiftUI

struct DayCell: View {
    let day: Int
    let color: Color?
    let isUnresolved: Bool
    let isFuture: Bool
    let isToday: Bool

    var body: some View {
        ZStack {
            if let color, !isFuture {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
            } else if isUnresolved {
                RoundedRectangle(cornerRadius: 8)
                    .fill(RoamTheme.unresolvedFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(RoamTheme.unresolvedBorder, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(RoamTheme.surfaceSubtle)
                    .opacity(isFuture ? 0.5 : 1)
            }

            Text("\(day)")
                .font(.caption)
                .fontWeight(isToday ? .semibold : .regular)
                .foregroundStyle(
                    (color != nil && !isFuture) ? .white :
                    isFuture ? RoamTheme.textTertiary : RoamTheme.textSecondary
                )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
