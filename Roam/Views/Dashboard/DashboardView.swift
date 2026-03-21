import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NightLog.date, order: .reverse) private var allLogs: [NightLog]
    @Query private var cityColors: [CityColor]
    @Query private var settings: [UserSettings]

    @Binding var showingSettings: Bool
    var unresolvedLogs: [NightLog]
    var onResolve: (NightLog) -> Void

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        let analytics = AnalyticsService(context: context)
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Roam")
                            .font(.largeTitle)
                            .fontWeight(.regular)
                        Spacer()
                        if !unresolvedLogs.isEmpty {
                            Button {
                                onResolve(unresolvedLogs[0])
                            } label: {
                                Text("\(unresolvedLogs.count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(RoamTheme.accent, in: Capsule())
                            }
                        }
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                        }
                    }
                    let streak = analytics.currentStreak(asOf: DateNormalization.normalizedNightDate(from: .now))

                    CurrentCityBanner(
                        cityName: streak.city.isEmpty ? "No data yet" : streak.city,
                        streakDays: streak.days
                    )

                    let cityDaysMap = analytics.daysPerCity(year: currentYear)
                    let totalDays = cityDaysMap.values.reduce(0, +)
                    let sortedCities = cityDaysMap.sorted { $0.value > $1.value }

                    YearSummaryBar(
                        cityDays: sortedCities.enumerated().map { index, entry in
                            let parts = entry.key.split(separator: "|")
                            return (name: String(parts.first ?? ""), days: entry.value, color: ColorPalette.color(for: index))
                        },
                        totalDays: totalDays
                    )

                    let deviceRegion = Locale.current.region?.identifier
                    let top5 = sortedCities.prefix(5)
                    let others = sortedCities.dropFirst(5)
                    let otherNightsCount = others.reduce(0) { $0 + $1.value }

                    let allCitiesList: [(name: String, nights: Int)] = sortedCities.map { entry in
                        let parts = entry.key.split(separator: "|")
                        let city = parts.count > 0 ? String(parts[0]) : ""
                        let state = parts.count > 1 ? String(parts[1]) : nil
                        let country = parts.count > 2 ? String(parts[2]) : nil
                        return (name: CityDisplayFormatter.format(city: city, state: state, country: country, deviceRegion: deviceRegion), nights: entry.value)
                    }

                    TopCitiesList(
                        cities: top5.enumerated().map { index, entry in
                            let parts = entry.key.split(separator: "|")
                            let city = parts.count > 0 ? String(parts[0]) : ""
                            let state = parts.count > 1 ? String(parts[1]) : nil
                            let country = parts.count > 2 ? String(parts[2]) : nil
                            let displayName = CityDisplayFormatter.format(city: city, state: state, country: country, deviceRegion: deviceRegion)
                            return (name: displayName, nights: entry.value, percentage: totalDays > 0 ? Double(entry.value) / Double(totalDays) : 0, color: ColorPalette.color(for: index))
                        },
                        otherCount: others.count,
                        otherNights: otherNightsCount,
                        totalNights: totalDays,
                        allCities: allCitiesList
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
            .grainBackground()
    }
}
