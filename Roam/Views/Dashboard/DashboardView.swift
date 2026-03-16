import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NightLog.date, order: .reverse) private var allLogs: [NightLog]
    @Query private var cityColors: [CityColor]
    @Query private var settings: [UserSettings]

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        let analytics = AnalyticsService(context: context)
        ScrollView {
                VStack(spacing: 20) {
                    let streak = analytics.currentStreak(asOf: DateNormalization.normalizedNightDate(from: .now))

                    CurrentCityBanner(
                        cityName: streak.city.isEmpty ? "No data yet" : streak.city,
                        streakDays: streak.days
                    )

                    let cityDaysMap = analytics.daysPerCity(year: currentYear)
                    let totalDays = cityDaysMap.values.reduce(0, +)
                    let sortedCities = cityDaysMap.sorted { $0.value > $1.value }

                    YearSummaryBar(
                        cityDays: sortedCities.map { entry in
                            let colorIndex = cityColors.first { $0.cityKey == entry.key }?.colorIndex ?? 0
                            let parts = entry.key.split(separator: "|")
                            return (name: String(parts.first ?? ""), days: entry.value, color: ColorPalette.color(for: colorIndex))
                        },
                        totalDays: totalDays
                    )

                    let deviceRegion = Locale.current.region?.identifier
                    TopCitiesList(
                        cities: sortedCities.prefix(5).map { entry in
                            let colorIndex = cityColors.first { $0.cityKey == entry.key }?.colorIndex ?? 0
                            let parts = entry.key.split(separator: "|")
                            let city = parts.count > 0 ? String(parts[0]) : ""
                            let state = parts.count > 1 ? String(parts[1]) : nil
                            let country = parts.count > 2 ? String(parts[2]) : nil
                            let displayName = CityDisplayFormatter.format(city: city, state: state, country: country, deviceRegion: deviceRegion)
                            return (name: displayName, nights: entry.value, percentage: totalDays > 0 ? Double(entry.value) / Double(totalDays) : 0, color: ColorPalette.color(for: colorIndex))
                        }
                    )

                    let homeCityKey = settings.first?.homeCityKey ?? ""
                    let longestStreak = analytics.longestStreak(year: currentYear)
                    let ratio = analytics.homeAwayRatio(year: currentYear, homeCityKey: homeCityKey)

                    QuickStatsRow(
                        citiesVisited: analytics.uniqueCitiesCount(year: currentYear),
                        longestStreak: longestStreak.days,
                        homeRatio: Int(ratio.homePercentage * 100)
                    )
                }
                .padding()
            }
            .navigationTitle("Roam")
    }
}
