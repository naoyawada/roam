import SwiftUI

struct HighlightsGrid: View {
    let mostVisited: (city: String, days: Int)
    let longestStreak: StreakInfo
    let newCityCount: Int
    let homeAwayRatio: HomeAwayRatio
    let travelDays: Int
    let trips: (count: Int, avgDays: Double)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Highlights")
                .fontWeight(.regular)
                .font(.subheadline)
                .foregroundStyle(RoamTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 10) {
                HighlightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Most Visited",
                    value: mostVisited.city,
                    detail: "\(mostVisited.days) Days"
                )
                HighlightCard(
                    icon: "flame",
                    label: "Longest Streak",
                    value: longestStreak.city,
                    detail: "\(longestStreak.days) Days"
                )
                HighlightCard(
                    icon: "building.2",
                    label: "Cities This Year",
                    largeValue: "\(newCityCount)"
                )
                HighlightCard(
                    icon: "suitcase",
                    label: "Away",
                    largeValue: "\(Int(homeAwayRatio.awayPercentage * 100))%"
                )
                HighlightCard(
                    icon: "airplane",
                    label: "Travel Days",
                    largeValue: "\(travelDays)"
                )
                HighlightCard(
                    icon: "map",
                    label: "Trips",
                    largeValue: "\(trips.count)"
                )
            }
        }
    }
}

private struct HighlightCard: View {
    @Environment(\.colorTheme) private var colorTheme
    let icon: String
    let label: String
    var value: String = ""
    var detail: String = ""
    var largeValue: String = ""

    private let cardHeight: CGFloat = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(colorTheme.accent)
                .frame(width: 24, height: 24, alignment: .leading)
                .padding(.bottom, 8)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .textCase(.uppercase)
                .foregroundStyle(RoamTheme.textSecondary)
                .padding(.bottom, 4)

            Spacer(minLength: 0)

            if !largeValue.isEmpty {
                Text(largeValue)
                    .font(.title)
                    .fontWeight(.regular)
                    .foregroundStyle(RoamTheme.textPrimary)
            } else {
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(RoamTheme.textPrimary)
                    .lineLimit(1)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: cardHeight)
        .padding(RoamTheme.cardPadding)
        .overlay(
            RoundedRectangle(cornerRadius: RoamTheme.cornerRadiusSmall)
                .stroke(RoamTheme.border, lineWidth: 1)
        )
    }
}
