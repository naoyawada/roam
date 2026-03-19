import SwiftUI

struct QuickStatsRow: View {
    let citiesVisited: Int
    let longestStreak: Int
    let homeRatio: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated = false

    var body: some View {
        HStack(spacing: 10) {
            StatCard(value: animated ? citiesVisited : 0, suffix: nil, label: "Cities visited")
            StatCard(value: animated ? longestStreak : 0, suffix: nil, label: "Longest streak")
            StatCard(value: animated ? homeRatio : 0, suffix: "%", label: "Home ratio")
        }
        .onAppear {
            guard !animated else { return }
            if reduceMotion {
                animated = true
            } else {
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    animated = true
                }
            }
        }
    }
}

private struct StatCard: View {
    let value: Int
    let suffix: String?
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)\(suffix ?? "")")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(RoamTheme.textPrimary)
                .contentTransition(.numericText(value: Double(value)))
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
