import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DailyEntry.date, order: .reverse) private var allEntries: [DailyEntry]
    @Query private var cityRecords: [CityRecord]
    @Query private var settings: [UserSettings]

    @Binding var showingSettings: Bool
    var lowConfidenceEntries: [DailyEntry]
    var onResolveLowConfidence: (DailyEntry) -> Void

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    private func colorIndex(for cityKey: String) -> Int {
        cityRecords.first(where: { $0.cityKey == cityKey })?.colorIndex ?? 0
    }

    var body: some View {
        let analytics = AnalyticsService(context: context)
        ScrollView {
            if allEntries.isEmpty {
                VStack {
                    Spacer(minLength: 120)
                    Text("Your first day will appear here")
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    let streak = analytics.currentStreak(asOf: DateHelpers.noonUTC(from: .now))

                    CurrentCityBanner(
                        cityName: streak.city.isEmpty ? "No data yet" : streak.city,
                        streakDays: streak.days
                    )

                    let cityDaysMap = analytics.daysPerCity(year: currentYear)
                    let totalDays = cityDaysMap.values.reduce(0, +)
                    let sortedCities = cityDaysMap.sorted { $0.value > $1.value }

                    YearSummaryBar(
                        cityDays: sortedCities.map { entry in
                            let parts = entry.key.split(separator: "|")
                            let idx = colorIndex(for: entry.key)
                            return (name: String(parts.first ?? ""), days: entry.value, color: ColorPalette.color(for: idx))
                        },
                        totalDays: totalDays
                    )

                    let deviceRegion = Locale.current.region?.identifier
                    let top5 = sortedCities.prefix(5)
                    let others = sortedCities.dropFirst(5)
                    let otherDaysCount = others.reduce(0) { $0 + $1.value }

                    let allCitiesList: [(name: String, days: Int)] = sortedCities.map { entry in
                        let parts = entry.key.split(separator: "|")
                        let city = parts.count > 0 ? String(parts[0]) : ""
                        let state = parts.count > 1 ? String(parts[1]) : nil
                        let country = parts.count > 2 ? String(parts[2]) : nil
                        return (name: CityDisplayFormatter.format(city: city, state: state, country: country, deviceRegion: deviceRegion), days: entry.value)
                    }

                    TopCitiesList(
                        cities: top5.map { entry in
                            let parts = entry.key.split(separator: "|")
                            let city = parts.count > 0 ? String(parts[0]) : ""
                            let state = parts.count > 1 ? String(parts[1]) : nil
                            let country = parts.count > 2 ? String(parts[2]) : nil
                            let displayName = CityDisplayFormatter.format(city: city, state: state, country: country, deviceRegion: deviceRegion)
                            let idx = colorIndex(for: entry.key)
                            return (name: displayName, days: entry.value, percentage: totalDays > 0 ? Double(entry.value) / Double(totalDays) : 0, color: ColorPalette.color(for: idx))
                        },
                        otherCount: others.count,
                        otherDays: otherDaysCount,
                        totalDays: totalDays,
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
        }
            .navigationTitle("Roam")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !lowConfidenceEntries.isEmpty {
                        Button {
                            onResolveLowConfidence(lowConfidenceEntries[0])
                        } label: {
                            Text("\(lowConfidenceEntries.count)")
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
            }
            .grainBackground()
    }
}
