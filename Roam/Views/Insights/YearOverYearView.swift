import SwiftUI

struct YearOverYearView: View {
    let years: [(year: Int, totalCities: Int, nightsAway: Int, avgTrip: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Year over Year")
                .fontWeight(.medium)
                .font(.subheadline)
                .foregroundStyle(RoamTheme.textPrimary)

            VStack(spacing: 12) {
                comparisonRow(label: "Total cities") { "\($0.totalCities)" }
                comparisonRow(label: "Nights away") { "\($0.nightsAway)" }
                comparisonRow(label: "Avg trip length") { String(format: "%.1fd", $0.avgTrip) }
            }
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: RoamTheme.cornerRadiusSmall)
                    .stroke(RoamTheme.border, lineWidth: 1)
            )
        }
    }

    private func comparisonRow(
        label: String,
        value: @escaping ((year: Int, totalCities: Int, nightsAway: Int, avgTrip: Double)) -> String
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(RoamTheme.textSecondary)
            Spacer()
            HStack(spacing: 16) {
                ForEach(years, id: \.year) { yearData in
                    VStack(alignment: .trailing) {
                        Text(value(yearData))
                            .font(.subheadline)
                            .fontWeight(yearData.year == years.last?.year ? .semibold : .regular)
                            .foregroundStyle(yearData.year == years.last?.year ? RoamTheme.textPrimary : RoamTheme.textSecondary)
                    }
                    .frame(width: 50, alignment: .trailing)
                }
            }
        }
    }
}
