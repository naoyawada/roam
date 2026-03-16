import SwiftUI

struct QuickStatsRow: View {
    let citiesVisited: Int
    let longestStreak: Int
    let homeRatio: Int

    var body: some View {
        HStack(spacing: 12) {
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
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
