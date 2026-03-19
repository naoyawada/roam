import SwiftUI

struct QuickStatsRow: View {
    let citiesVisited: Int
    let longestStreak: Int
    let homeRatio: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedCards: Set<Int> = []

    var body: some View {
        HStack(spacing: 10) {
            StatCard(value: animatedCards.contains(0) ? citiesVisited : 0, suffix: "", label: "Cities visited")
            StatCard(value: animatedCards.contains(1) ? longestStreak : 0, suffix: "", label: "Longest streak")
            StatCard(value: animatedCards.contains(2) ? homeRatio : 0, suffix: "%", label: "Home ratio")
        }
        .onAppear {
            guard animatedCards.isEmpty else { return }
            for i in 0..<3 {
                if reduceMotion {
                    animatedCards.insert(i)
                } else {
                    let delay = 1.1 + Double(i) * 0.15
                    withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                        _ = animatedCards.insert(i)
                    }
                }
            }
        }
    }
}

private struct StatCard: View {
    let value: Int
    let suffix: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            AnimatingNumber(value: Double(value), suffix: suffix)
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
