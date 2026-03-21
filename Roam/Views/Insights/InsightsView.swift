import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Query private var cityColors: [CityColor]
    @Query private var settings: [UserSettings]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: .now)

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        let analytics = AnalyticsService(context: context)
        let years = analytics.availableYears()
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                YearPicker(years: years.isEmpty ? [currentYear] : years, selectedYear: $selectedYear)

                if years.isEmpty {
                    Text("Insights will appear once you have a few nights logged")
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                } else {
                    MonthlyBreakdownChart(
                        breakdown: analytics.monthlyBreakdown(year: selectedYear),
                        cityColors: cityColors
                    )

                    let cityDays = analytics.daysPerCity(year: selectedYear)
                    let topCity = cityDays.max(by: { $0.value < $1.value })
                    let topCityName = topCity?.key.split(separator: "|").first.map(String.init) ?? ""
                    let homeCityKey = settings.first?.homeCityKey ?? ""

                    HighlightsGrid(
                        mostVisited: (city: topCityName, nights: topCity?.value ?? 0),
                        longestStreak: analytics.longestStreak(year: selectedYear),
                        newCityCount: analytics.newCities(year: selectedYear).count,
                        homeAwayRatio: analytics.homeAwayRatio(year: selectedYear, homeCityKey: homeCityKey)
                    )

                    let yoyData = years.suffix(2).map { year in
                        let awayNights = analytics.confirmedLogs(year: year).filter {
                            CityDisplayFormatter.cityKey(city: $0.city, state: $0.state, country: $0.country) != homeCityKey
                        }.count
                        return (
                            year: year,
                            totalCities: analytics.uniqueCitiesCount(year: year),
                            nightsAway: awayNights,
                            avgTrip: analytics.averageTripLength(year: year, homeCityKey: homeCityKey)
                        )
                    }

                    if yoyData.count >= 2 {
                        YearOverYearView(years: yoyData)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .grainBackground()
    }
}
