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
                    .fill(ColorPalette.unresolvedColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.yellow.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .opacity(isFuture ? 0.3 : 0.5)
            }

            Text("\(day)")
                .font(.caption)
                .fontWeight(isToday ? .bold : .semibold)
                .foregroundStyle(isFuture ? .secondary : .primary)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
