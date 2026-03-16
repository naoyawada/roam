import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Query private var cityColors: [CityColor]
    @Query private var settings: [UserSettings]

    @State private var selectedYear: Int? = Calendar.current.component(.year, from: .now)

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        let analytics = AnalyticsService(context: context)
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    let years = analytics.availableYears()

                    YearPicker(years: years.isEmpty ? [currentYear] : years, selectedYear: $selectedYear)

                    // When selectedYear is nil, show all-time data using current year for monthly chart
                    let displayYear = selectedYear ?? currentYear

                    MonthlyBreakdownChart(
                        breakdown: analytics.monthlyBreakdown(year: displayYear),
                        cityColors: cityColors
                    )

                    // For "All Time", aggregate across all years
                    let cityDays: [String: Int] = {
                        if let year = selectedYear {
                            return analytics.daysPerCity(year: year)
                        } else {
                            var allTimeDays: [String: Int] = [:]
                            for year in analytics.availableYears() {
                                for (key, count) in analytics.daysPerCity(year: year) {
                                    allTimeDays[key, default: 0] += count
                                }
                            }
                            return allTimeDays
                        }
                    }()

                    let topCity = cityDays.max(by: { $0.value < $1.value })
                    let topCityName = topCity?.key.split(separator: "|").first.map(String.init) ?? ""
                    let homeCityKey = settings.first?.homeCityKey ?? ""

                    HighlightsGrid(
                        mostVisited: (city: topCityName, nights: topCity?.value ?? 0),
                        longestStreak: analytics.longestStreak(year: displayYear),
                        newCities: analytics.newCities(year: displayYear),
                        homeAwayRatio: analytics.homeAwayRatio(year: displayYear, homeCityKey: homeCityKey)
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
                .padding()
            }
            .navigationTitle("Insights")
        }
    }
}
