import SwiftUI

struct DayCell: View {
    let day: Int
    let color: Color?
    let travelColors: [Color]  // For travel days: gradient from first city to last
    let confidence: EntryConfidence
    let isLowConfidence: Bool
    let isTravelDay: Bool
    let isFuture: Bool
    let isToday: Bool

    private var confidenceOpacity: Double {
        switch confidence {
        case .high: return 1.0
        case .medium: return 0.7
        case .low: return 0.5
        }
    }

    var body: some View {
        ZStack {
            if isTravelDay && travelColors.count >= 2 && !isFuture {
                // Gradient for travel days
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: travelColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(confidenceOpacity)
            } else if let color, !isFuture {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .opacity(confidenceOpacity)
            } else if isLowConfidence {
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

            VStack(spacing: 0) {
                Text("\(day)")
                    .font(.caption)
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundStyle(
                        (color != nil && !isFuture) || (isTravelDay && !travelColors.isEmpty && !isFuture) ? .white :
                        isFuture ? RoamTheme.textTertiary : RoamTheme.textSecondary
                    )

                if isTravelDay && !isFuture {
                    Image(systemName: "airplane")
                        .font(.system(size: 6))
                        .foregroundStyle(
                            (color != nil || !travelColors.isEmpty) ? .white.opacity(0.8) : RoamTheme.textTertiary
                        )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
