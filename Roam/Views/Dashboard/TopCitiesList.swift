import SwiftUI

struct TopCitiesList: View {
    let cities: [(name: String, nights: Int, percentage: Double, color: Color)]
    let otherCount: Int
    let otherNights: Int
    let totalNights: Int
    let allCities: [(name: String, nights: Int)]

    @State private var showingAllCities = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Top Cities")
                .fontWeight(.medium)
                .font(.subheadline)
                .foregroundStyle(RoamTheme.textPrimary)
                .padding(.bottom, 10)

            ForEach(Array(cities.enumerated()), id: \.offset) { _, city in
                HStack {
                    Circle()
                        .fill(city.color)
                        .frame(width: 7, height: 7)
                    Text(city.name)
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                    Spacer()
                    AnimatingNumber(value: Double(animated ? city.nights : 0), suffix: "")
                        .fontWeight(.medium)
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                    AnimatingNumber(value: Double(animated ? Int(city.percentage * 100) : 0), suffix: "%")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textTertiary)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.vertical, 7)

                Rectangle()
                    .fill(RoamTheme.border)
                    .frame(height: 1)
            }

            // "Other" row
            if otherCount > 0 {
                let pct = totalNights > 0 ? Int(Double(otherNights) / Double(totalNights) * 100) : 0
                HStack {
                    Circle()
                        .fill(ColorPalette.otherColor)
                        .frame(width: 7, height: 7)
                    Text("\(otherCount) other cit\(otherCount == 1 ? "y" : "ies")")
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textSecondary)
                    Spacer()
                    AnimatingNumber(value: Double(animated ? otherNights : 0), suffix: "")
                        .fontWeight(.medium)
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textPrimary)
                    AnimatingNumber(value: Double(animated ? pct : 0), suffix: "%")
                        .font(.caption)
                        .foregroundStyle(RoamTheme.textTertiary)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.vertical, 7)
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
            AllCitiesSheet(cities: allCities, totalNights: totalNights)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            guard !animated else { return }
            if reduceMotion {
                animated = true
            } else {
                withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                    animated = true
                }
            }
        }
    }
}
