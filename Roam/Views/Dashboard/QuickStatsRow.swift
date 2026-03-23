import SwiftUI

struct QuickStatsRow: View {
    let citiesVisited: Int
    let currentStreak: Int
    let awayRatio: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedCards: Set<Int> = []

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StatCard(
                icon: "building.2",
                label: "Cities",
                value: animatedCards.contains(0) ? citiesVisited : 0,
                suffix: ""
            )
            StatCard(
                icon: "mappin.and.ellipse",
                label: "Days Here",
                value: animatedCards.contains(1) ? currentStreak : 0,
                suffix: ""
            )
            StatCard(
                icon: "suitcase",
                label: "Away",
                value: animatedCards.contains(2) ? awayRatio : 0,
                suffix: "%"
            )
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
    let icon: String
    let label: String
    let value: Int
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AnimatingNumber(value: Double(value), suffix: suffix)
                .font(.title)
                .fontWeight(.regular)
                .foregroundStyle(RoamTheme.textPrimary)
                .padding(.bottom, 6)

            HStack(spacing: 3) {
                Image(systemName: icon)
                Text(label)
                    .textCase(.uppercase)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(RoamTheme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: RoamTheme.cornerRadiusSmall)
                .stroke(RoamTheme.border, lineWidth: 1)
        )
    }
}
