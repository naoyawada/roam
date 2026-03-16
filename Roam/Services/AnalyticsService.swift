import Foundation
import SwiftData

struct StreakInfo {
    let city: String
    let days: Int
}

struct HomeAwayRatio {
    let homePercentage: Double
    let awayPercentage: Double
}

struct MonthlyBreakdown {
    let month: Int
    let cityDays: [(cityKey: String, city: String, days: Int)]
}

@MainActor
final class AnalyticsService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Core Queries

    func confirmedLogs(year: Int) -> [NightLog] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let startOfYear = cal.date(from: DateComponents(year: year, month: 1, day: 1, hour: 0))!
        let endOfYear = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1, hour: 0))!

        let unresolvedRaw = LogStatus.unresolvedRaw
        let descriptor = FetchDescriptor<NightLog>(
            predicate: #Predicate<NightLog> {
                $0.date >= startOfYear && $0.date < endOfYear &&
                $0.statusRaw != unresolvedRaw
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func allConfirmedLogs() -> [NightLog] {
        let unresolvedRaw = LogStatus.unresolvedRaw
        let descriptor = FetchDescriptor<NightLog>(
            predicate: #Predicate<NightLog> { $0.statusRaw != unresolvedRaw },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Days Per City

    func daysPerCity(year: Int) -> [String: Int] {
        let logs = confirmedLogs(year: year)
        var result: [String: Int] = [:]
        for log in logs {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            result[key, default: 0] += 1
        }
        return result
    }

    // MARK: - Streaks

    func currentStreak(asOf today: Date) -> StreakInfo {
        let logs = allConfirmedLogs().reversed()
        guard let first = logs.first else { return StreakInfo(city: "", days: 0) }

        let firstKey = CityDisplayFormatter.cityKey(city: first.city, state: first.state, country: first.country)
        var count = 1
        var previousDate = first.date

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        for log in logs.dropFirst() {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            let daysBetween = cal.dateComponents([.day], from: log.date, to: previousDate).day ?? 0

            if key == firstKey && daysBetween == 1 {
                count += 1
                previousDate = log.date
            } else {
                break
            }
        }
        return StreakInfo(city: first.city ?? "", days: count)
    }

    func longestStreak(year: Int) -> StreakInfo {
        let logs = confirmedLogs(year: year)
        guard !logs.isEmpty else { return StreakInfo(city: "", days: 0) }

        var bestCity = ""
        var bestCount = 0
        var currentCity = ""
        var currentCount = 0
        var previousDate: Date?

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        for log in logs {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)

            if let prev = previousDate {
                let daysBetween = cal.dateComponents([.day], from: prev, to: log.date).day ?? 0
                if key == currentCity && daysBetween == 1 {
                    currentCount += 1
                } else {
                    currentCity = key
                    currentCount = 1
                }
            } else {
                currentCity = key
                currentCount = 1
            }

            if currentCount > bestCount {
                bestCount = currentCount
                bestCity = log.city ?? ""
            }
            previousDate = log.date
        }
        return StreakInfo(city: bestCity, days: bestCount)
    }

    // MARK: - Unique Cities

    func uniqueCitiesCount(year: Int) -> Int {
        daysPerCity(year: year).keys.count
    }

    // MARK: - Home / Away

    func homeAwayRatio(year: Int, homeCityKey: String) -> HomeAwayRatio {
        let logs = confirmedLogs(year: year)
        guard !logs.isEmpty else { return HomeAwayRatio(homePercentage: 0, awayPercentage: 0) }

        let homeCount = logs.filter {
            CityDisplayFormatter.cityKey(city: $0.city, state: $0.state, country: $0.country) == homeCityKey
        }.count
        let total = Double(logs.count)

        return HomeAwayRatio(
            homePercentage: Double(homeCount) / total,
            awayPercentage: Double(logs.count - homeCount) / total
        )
    }

    // MARK: - Monthly Breakdown

    func monthlyBreakdown(year: Int) -> [MonthlyBreakdown] {
        let logs = confirmedLogs(year: year)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        var byMonth: [Int: [NightLog]] = [:]
        for log in logs {
            let month = cal.component(.month, from: log.date)
            byMonth[month, default: []].append(log)
        }

        return (1...12).map { month in
            let monthLogs = byMonth[month] ?? []
            var cityDays: [String: (city: String, days: Int)] = [:]
            for log in monthLogs {
                let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
                if cityDays[key] != nil {
                    cityDays[key]!.days += 1
                } else {
                    cityDays[key] = (city: log.city ?? "Unknown", days: 1)
                }
            }
            let sorted = cityDays.map { (cityKey: $0.key, city: $0.value.city, days: $0.value.days) }
                .sorted { $0.days > $1.days }
            return MonthlyBreakdown(month: month, cityDays: sorted)
        }
    }

    // MARK: - New Cities

    func newCities(year: Int) -> [String] {
        let thisYearKeys = Set(daysPerCity(year: year).keys)
        var allPriorKeys: Set<String> = []
        for priorYear in 2020..<year {
            allPriorKeys.formUnion(daysPerCity(year: priorYear).keys)
        }
        return Array(thisYearKeys.subtracting(allPriorKeys)).sorted()
    }

    // MARK: - Average Trip Length

    func averageTripLength(year: Int, homeCityKey: String) -> Double {
        let logs = confirmedLogs(year: year)
        var trips: [Int] = []
        var awayCount = 0

        for log in logs {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            if key == homeCityKey {
                if awayCount > 0 {
                    trips.append(awayCount)
                    awayCount = 0
                }
            } else {
                awayCount += 1
            }
        }
        if awayCount > 0 { trips.append(awayCount) }
        guard !trips.isEmpty else { return 0 }
        return Double(trips.reduce(0, +)) / Double(trips.count)
    }

    // MARK: - Available Years

    func availableYears() -> [Int] {
        let logs = allConfirmedLogs()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let years = Set(logs.map { cal.component(.year, from: $0.date) })
        return years.sorted().reversed()
    }
}
