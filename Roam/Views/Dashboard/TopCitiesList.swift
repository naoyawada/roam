import SwiftUI

struct TopCitiesList: View {
    let cities: [(name: String, days: Int, percentage: Double, color: Color)]
    let otherCount: Int
    let otherDays: Int
    let totalDays: Int
    let allCities: [(name: String, days: Int)]

    @State private var showingAllCities = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedRows: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Top Cities")
                .fontWeight(.regular)
                .font(.subheadline)
                .foregroundStyle(RoamTheme.textPrimary)
                .padding(.bottom, 10)

            ForEach(Array(cities.enumerated()), id: \.offset) { index, city in
                let rowAnimated = animatedRows.contains(index)
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(city.color)
                        .frame(width: 10, height: 10)
                    Text(city.name)
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                    Spacer()
                    Text("\(city.days)")
                        .fontWeight(.medium)
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                    Text("\(Int(city.percentage * 100))%")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textTertiary)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .opacity(rowAnimated ? 1 : 0)

                Rectangle()
                    .fill(RoamTheme.border)
                    .frame(height: 1)
                    .opacity(rowAnimated ? 1 : 0)
            }

            // "Other" row
            if otherCount > 0 {
                let otherIndex = cities.count
                let otherAnimated = animatedRows.contains(otherIndex)
                let pct = totalDays > 0 ? Int(Double(otherDays) / Double(totalDays) * 100) : 0
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorPalette.otherColor)
                        .frame(width: 10, height: 10)
                    Text("\(otherCount) other cit\(otherCount == 1 ? "y" : "ies")")
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textSecondary)
                    Spacer()
                    Text("\(otherDays)")
                        .fontWeight(.medium)
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                    Text("\(pct)%")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textTertiary)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.vertical, 7)
                .opacity(otherAnimated ? 1 : 0)
            }

            // "See all" link
            if allCities.count > ColorPalette.maxColoredCities {
                Button {
                    showingAllCities = true
                } label: {
                    Text("See all \(allCities.count) cities \u{2192}")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(RoamTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingAllCities) {
            AllCitiesSheet(cities: allCities, totalDays: totalDays)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            guard animatedRows.isEmpty else { return }
            let totalRows = cities.count + (otherCount > 0 ? 1 : 0)
            for i in 0..<totalRows {
                if reduceMotion {
                    animatedRows.insert(i)
                } else {
                    let delay = 0.6 + Double(i) * 0.1
                    withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                        _ = animatedRows.insert(i)
                    }
                }
            }
        }
    }
}
