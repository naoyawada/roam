import SwiftUI

struct HighlightsGrid: View {
    let mostVisited: (city: String, nights: Int)
    let longestStreak: StreakInfo
    let newCities: [String]
    let homeAwayRatio: HomeAwayRatio

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Highlights")
                .fontWeight(.medium)
                .font(.subheadline)
                .foregroundStyle(RoamTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                HighlightCard(
                    label: "Most visited",
                    value: mostVisited.city,
                    detail: "\(mostVisited.nights) nights"
                )
                HighlightCard(
                    label: "Longest streak",
                    value: longestStreak.city,
                    detail: "\(longestStreak.days) consecutive"
                )
                HighlightCard(
                    label: "New cities this year",
                    value: "\(newCities.count)",
                    detail: newCities.prefix(3).joined(separator: ", ")
                )
                HighlightCard(
                    label: "Home vs. away",
                    value: "\(Int(homeAwayRatio.homePercentage * 100))% / \(Int(homeAwayRatio.awayPercentage * 100))%",
                    detail: ""
                )
            }
        }
    }
}

private struct HighlightCard: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .textCase(.uppercase)
                .tracking(0.3)
                .foregroundStyle(RoamTheme.textTertiary)
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(RoamTheme.textPrimary)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(RoamTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RoamTheme.cardPadding)
        .overlay(
            RoundedRectangle(cornerRadius: RoamTheme.cornerRadiusSmall)
                .stroke(RoamTheme.border, lineWidth: 1)
        )
    }
}
