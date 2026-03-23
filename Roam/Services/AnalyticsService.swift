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

    func confirmedLogs(year: Int) -> [DailyEntry] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let startOfYear = cal.date(from: DateComponents(year: year, month: 1, day: 1, hour: 0))!
        let endOfYear = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1, hour: 0))!

        let lowRaw = EntryConfidence.lowRaw
        let descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> {
                $0.date >= startOfYear && $0.date < endOfYear &&
                $0.confidenceRaw != lowRaw
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func allConfirmedLogs() -> [DailyEntry] {
        let lowRaw = EntryConfidence.lowRaw
        let descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { $0.confidenceRaw != lowRaw },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Days Per City

    func daysPerCity(year: Int) -> [String: Int] {
        let entries = confirmedLogs(year: year)
        var result: [String: Int] = [:]
        for entry in entries {
            result[entry.cityKey, default: 0] += 1
        }
        return result
    }

    // MARK: - Streaks

    func currentStreak(asOf today: Date) -> StreakInfo {
        let entries = allConfirmedLogs().reversed()
        guard let first = entries.first else { return StreakInfo(city: "", days: 0) }

        let firstKey = first.cityKey
        var count = 1
        var previousDate = first.date

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        for entry in entries.dropFirst() {
            let daysBetween = cal.dateComponents([.day], from: entry.date, to: previousDate).day ?? 0

            if entry.cityKey == firstKey && daysBetween == 1 {
                count += 1
                previousDate = entry.date
            } else {
                break
            }
        }
        return StreakInfo(city: first.primaryCity, days: count)
    }

    func longestStreak(year: Int) -> StreakInfo {
        let entries = confirmedLogs(year: year)
        guard !entries.isEmpty else { return StreakInfo(city: "", days: 0) }

        var bestCity = ""
        var bestCount = 0
        var currentCityKey = ""
        var currentCount = 0
        var previousDate: Date?

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        for entry in entries {
            let key = entry.cityKey

            if let prev = previousDate {
                let daysBetween = cal.dateComponents([.day], from: prev, to: entry.date).day ?? 0
                if key == currentCityKey && daysBetween == 1 {
                    currentCount += 1
                } else {
                    currentCityKey = key
                    currentCount = 1
                }
            } else {
                currentCityKey = key
                currentCount = 1
            }

            if currentCount > bestCount {
                bestCount = currentCount
                bestCity = entry.primaryCity
            }
            previousDate = entry.date
        }
        return StreakInfo(city: bestCity, days: bestCount)
    }

    // MARK: - Unique Cities

    func uniqueCitiesCount(year: Int) -> Int {
        daysPerCity(year: year).keys.count
    }

    // MARK: - Home / Away

    func homeAwayRatio(year: Int, homeCityKey: String) -> HomeAwayRatio {
        let entries = confirmedLogs(year: year)
        guard !entries.isEmpty else { return HomeAwayRatio(homePercentage: 0, awayPercentage: 0) }

        let homeCount = entries.filter { $0.cityKey == homeCityKey }.count
        let total = Double(entries.count)

        return HomeAwayRatio(
            homePercentage: Double(homeCount) / total,
            awayPercentage: Double(entries.count - homeCount) / total
        )
    }

    // MARK: - Monthly Breakdown

    func monthlyBreakdown(year: Int) -> [MonthlyBreakdown] {
        let entries = confirmedLogs(year: year)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        var byMonth: [Int: [DailyEntry]] = [:]
        for entry in entries {
            let month = cal.component(.month, from: entry.date)
            byMonth[month, default: []].append(entry)
        }

        return (1...12).map { month in
            let monthEntries = byMonth[month] ?? []
            var cityDays: [String: (city: String, days: Int)] = [:]
            for entry in monthEntries {
                let key = entry.cityKey
                if cityDays[key] != nil {
                    cityDays[key]!.days += 1
                } else {
                    cityDays[key] = (city: entry.primaryCity, days: 1)
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
        let entries = confirmedLogs(year: year)
        var trips: [Int] = []
        var awayCount = 0

        for entry in entries {
            if entry.cityKey == homeCityKey {
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

    func tripCount(year: Int, homeCityKey: String) -> (count: Int, avgDays: Double) {
        let entries = confirmedLogs(year: year)
        var trips: [Int] = []
        var awayCount = 0

        for entry in entries {
            if entry.cityKey == homeCityKey {
                if awayCount > 0 {
                    trips.append(awayCount)
                    awayCount = 0
                }
            } else {
                awayCount += 1
            }
        }
        if awayCount > 0 { trips.append(awayCount) }
        guard !trips.isEmpty else { return (count: 0, avgDays: 0) }
        let avg = Double(trips.reduce(0, +)) / Double(trips.count)
        return (count: trips.count, avgDays: avg)
    }

    // MARK: - Travel Days

    func travelDayCount(year: Int) -> Int {
        confirmedLogs(year: year).filter { $0.isTravelDay }.count
    }

    // MARK: - Available Years

    func availableYears() -> [Int] {
        let entries = allConfirmedLogs()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let years = Set(entries.map { cal.component(.year, from: $0.date) })
        return years.sorted().reversed()
    }
}
