import SwiftUI

struct HighlightsGrid: View {
    let mostVisited: (city: String, nights: Int)
    let longestStreak: StreakInfo
    let newCities: [String]
    let homeAwayRatio: HomeAwayRatio

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Highlights")
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
