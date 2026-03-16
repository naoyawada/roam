import SwiftUI

struct AllCitiesSheet: View {
    let cities: [(name: String, nights: Int)]
    let totalNights: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Summary line
                    HStack {
                        Text("\(Calendar.current.component(.year, from: .now))")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(totalNights) nights \u{00B7} \(cities.count) cities")
                            .font(.caption)
                            .foregroundStyle(RoamTheme.textSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                    ForEach(Array(cities.enumerated()), id: \.offset) { index, city in
                        let isTop5 = index < ColorPalette.maxColoredCities

                        HStack(alignment: .center) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(RoamTheme.textTertiary)
                                .frame(width: 20, alignment: .leading)

                            Text(city.name)
                                .font(isTop5 ? .body : .subheadline)
                                .fontWeight(isTop5 ? .medium : .regular)
                                .foregroundStyle(isTop5 ? RoamTheme.textPrimary : RoamTheme.textSecondary)

                            Spacer()

                            Text("\(city.nights)")
                                .font(isTop5 ? .body : .subheadline)
                                .fontWeight(isTop5 ? .semibold : .medium)
                                .foregroundStyle(isTop5 ? RoamTheme.textPrimary : RoamTheme.textSecondary)

                            Text(city.nights == 1 ? "night" : "nights")
                                .font(.caption)
                                .foregroundStyle(RoamTheme.textTertiary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)

                        if index == ColorPalette.maxColoredCities - 1 && cities.count > ColorPalette.maxColoredCities {
                            // Thicker divider between top 5 and rest
                            Rectangle()
                                .fill(RoamTheme.borderStrong)
                                .frame(height: 1)
                                .padding(.horizontal)
                        } else if index < cities.count - 1 {
                            Rectangle()
                                .fill(RoamTheme.border)
                                .frame(height: 1)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("All Cities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(RoamTheme.accent)
                }
            }
            .grainBackground()
        }
    }
}
