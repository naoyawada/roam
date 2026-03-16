import SwiftUI

struct QuickStatsRow: View {
    let citiesVisited: Int
    let longestStreak: Int
    let homeRatio: Int

    var body: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(citiesVisited)", label: "Cities visited")
            StatCard(value: "\(longestStreak)", label: "Longest streak")
            StatCard(value: "\(homeRatio)%", label: "Home ratio")
        }
    }
}

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(RoamTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(RoamTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RoamTheme.cardPadding)
        .overlay(
            RoundedRectangle(cornerRadius: RoamTheme.cornerRadiusSmall)
                .stroke(RoamTheme.border, lineWidth: 1)
        )
    }
}
