// Roam/Services/VisitPipeline.swift
import Foundation
import SwiftData
import CoreLocation

@MainActor
final class VisitPipeline {
    private let modelContainer: ModelContainer
    private let logger: PipelineLogger
    private let aggregator = DailyAggregator()
    private let cityResolver = CityResolver()
    private let accuracyThreshold: Double = 1000.0

    init(modelContainer: ModelContainer, logger: PipelineLogger) {
        self.modelContainer = modelContainer
        self.logger = logger
    }

    func handleVisit(_ visitData: VisitData) async {
        let context = ModelContext(modelContainer)
        guard visitData.horizontalAccuracy <= accuracyThreshold else {
            await logger.log(category: "visit_delivery", event: "visit_accuracy_rejected",
                           detail: "accuracy: \(visitData.horizontalAccuracy)m")
            return
        }
        await logger.log(category: "visit_delivery", event: "visit_received",
                        detail: "\(visitData.latitude), \(visitData.longitude)")
        let rawVisit = RawVisit(from: visitData)
        context.insert(rawVisit)
        try? context.save()
        let resolved = await cityResolver.resolve(visit: rawVisit, context: context)
        if resolved {
            await logger.log(category: "geocoding", event: "geocode_success",
                           detail: "\(rawVisit.resolvedCity ?? ""), \(rawVisit.resolvedRegion ?? "")",
                           rawVisitID: rawVisit.id)
            aggregateDates(for: rawVisit, context: context)
        } else {
            await logger.log(category: "geocoding", event: "geocode_failed",
                           detail: "attempt \(rawVisit.geocodeAttempts)", rawVisitID: rawVisit.id)
        }
    }

    func runCatchup() async {
        let context = ModelContext(modelContainer)
        await logger.log(category: "trigger", event: "trigger_foreground")
        await retryUnresolvedGeocoding(context: context)
        let lastEntry = fetchLastEntry(context: context)
        let today = DateHelpers.noonUTC(from: Date())
        let missingDates = findMissingDates(from: lastEntry?.date, to: today)
        for date in missingDates {
            let visits = fetchVisits(for: date, context: context)
            if !visits.isEmpty {
                let entry = aggregator.aggregate(visits: visits, for: date)
                if let entry = entry {
                    let _ = upsertEntry(entry, context: context)
                    updateCityRecord(for: entry, context: context)
                    await logger.log(category: "aggregation", event: "entry_created",
                                   detail: entry.primaryCity, dailyEntryID: entry.id)
                    continue
                }
            }
            if let lastKnown = fetchLastEntryBefore(date: date, context: context) {
                let recentVisits = fetchVisitsAfter(date: lastKnown.date, context: context)
                if let propagated = aggregator.propagate(for: date, lastEntry: lastKnown, recentVisits: recentVisits) {
                    let _ = upsertEntry(propagated, context: context)
                    await logger.log(category: "aggregation", event: "city_propagated",
                                   detail: propagated.primaryCity, dailyEntryID: propagated.id)
                } else {
                    // Departure detected but no arrival — create low-confidence fallback
                    let fallback = DailyEntry()
                    fallback.date = date
                    fallback.sourceRaw = EntrySource.fallbackRaw
                    fallback.confidenceRaw = EntryConfidence.lowRaw
                    if let departureVisit = recentVisits.first(where: {
                        $0.resolvedCity != lastKnown.primaryCity || $0.resolvedRegion != lastKnown.primaryRegion
                    }) {
                        fallback.primaryCity = departureVisit.resolvedCity ?? ""
                        fallback.primaryRegion = departureVisit.resolvedRegion ?? ""
                        fallback.primaryCountry = departureVisit.resolvedCountry ?? ""
                        fallback.primaryLatitude = departureVisit.latitude
                        fallback.primaryLongitude = departureVisit.longitude
                    }
                    fallback.updatedAt = Date()
                    let _ = upsertEntry(fallback, context: context)
                    await logger.log(category: "aggregation", event: "entry_created",
                                   detail: "fallback: \(fallback.primaryCity)", dailyEntryID: fallback.id)
                }
            }
        }
    }

    func handleVisitForTesting(visitData: VisitData, resolvedCity: String, resolvedRegion: String, resolvedCountry: String) {
        let context = ModelContext(modelContainer)
        let rawVisit = RawVisit(from: visitData)
        rawVisit.resolvedCity = resolvedCity
        rawVisit.resolvedRegion = resolvedRegion
        rawVisit.resolvedCountry = resolvedCountry
        rawVisit.isCityResolved = true
        context.insert(rawVisit)
        try? context.save()
        aggregateDates(for: rawVisit, context: context)
    }

    // MARK: - Private

    private func aggregateDates(for visit: RawVisit, context: ModelContext) {
        let affectedDates = determineDates(for: visit)
        for date in affectedDates {
            let allVisits = fetchVisits(for: date, context: context)
            if let entry = aggregator.aggregate(visits: allVisits, for: date) {
                let oldCityKey = upsertEntry(entry, context: context)
                updateCityRecord(for: entry, context: context)
                if let oldKey = oldCityKey {
                    decrementCityRecord(cityKey: oldKey, context: context)
                }
            }
        }
    }

    private func determineDates(for visit: RawVisit) -> [Date] {
        var dates: [Date] = []
        var cursor = DateHelpers.startOfDay(for: visit.arrivalDate)
        let effectiveDeparture = visit.departureDate == .distantFuture ? Date() : visit.departureDate
        let endDay = DateHelpers.startOfDay(for: effectiveDeparture)
        while cursor <= endDay {
            dates.append(cursor)
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)!
        }
        return dates
    }

    /// Returns the old city key if the entry's primary city changed, for CityRecord stat adjustment.
    @discardableResult
    private func upsertEntry(_ entry: DailyEntry, context: ModelContext) -> String? {
        let targetDate = entry.date
        let descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { $0.date == targetDate }
        )
        var oldCityKey: String? = nil
        if let existing = try? context.fetch(descriptor).first {
            if existing.primaryCity != entry.primaryCity || existing.primaryRegion != entry.primaryRegion {
                oldCityKey = existing.cityKey
            }
            existing.primaryCity = entry.primaryCity
            existing.primaryRegion = entry.primaryRegion
            existing.primaryCountry = entry.primaryCountry
            existing.primaryLatitude = entry.primaryLatitude
            existing.primaryLongitude = entry.primaryLongitude
            existing.isTravelDay = entry.isTravelDay
            existing.citiesVisitedJSON = entry.citiesVisitedJSON
            existing.totalVisitHours = entry.totalVisitHours
            existing.sourceRaw = entry.sourceRaw
            existing.confidenceRaw = entry.confidenceRaw
            existing.updatedAt = Date()
        } else {
            context.insert(entry)
        }
        try? context.save()
        return oldCityKey
    }

    private func updateCityRecord(for entry: DailyEntry, context: ModelContext) {
        let cityName = entry.primaryCity
        let region = entry.primaryRegion
        let country = entry.primaryCountry
        let descriptor = FetchDescriptor<CityRecord>(
            predicate: #Predicate<CityRecord> {
                $0.cityName == cityName && $0.region == region && $0.country == country
            }
        )
        let record: CityRecord
        if let existing = try? context.fetch(descriptor).first {
            record = existing
        } else {
            record = CityRecord()
            record.cityName = cityName
            record.region = region
            record.country = country
            record.canonicalLatitude = entry.primaryLatitude
            record.canonicalLongitude = entry.primaryLongitude
            record.firstVisitedDate = entry.date
            let allRecords = (try? context.fetch(FetchDescriptor<CityRecord>())) ?? []
            record.colorIndex = (allRecords.map(\.colorIndex).max() ?? -1) + 1
            context.insert(record)
        }
        // Recount total days (idempotent)
        let allEntries = (try? context.fetch(FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> {
                $0.primaryCity == cityName && $0.primaryRegion == region && $0.primaryCountry == country
            }
        ))) ?? []
        record.totalDays = allEntries.count
        record.lastVisitedDate = allEntries.map(\.date).max() ?? entry.date
        record.updatedAt = Date()
        try? context.save()
    }

    private func decrementCityRecord(cityKey: String, context: ModelContext) {
        // Parse pipe-delimited key
        let parts = cityKey.components(separatedBy: "|")
        guard parts.count >= 3 else { return }
        let cityName = parts[0]
        let region = parts[1]
        let country = parts[2]
        let descriptor = FetchDescriptor<CityRecord>(
            predicate: #Predicate<CityRecord> {
                $0.cityName == cityName && $0.region == region && $0.country == country
            }
        )
        guard let record = try? context.fetch(descriptor).first else { return }
        let allEntries = (try? context.fetch(FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> {
                $0.primaryCity == cityName && $0.primaryRegion == region && $0.primaryCountry == country
            }
        ))) ?? []
        record.totalDays = allEntries.count
        record.lastVisitedDate = allEntries.map(\.date).max() ?? record.firstVisitedDate
        record.updatedAt = Date()
        try? context.save()
    }

    private func fetchLastEntry(context: ModelContext) -> DailyEntry? {
        var descriptor = FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchLastEntryBefore(date: Date, context: ModelContext) -> DailyEntry? {
        var descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { $0.date < date },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchVisits(for date: Date, context: ModelContext) -> [RawVisit] {
        let dayStart = DateHelpers.startOfDay(for: date)
        let dayEnd = DateHelpers.endOfDay(for: date)
        let descriptor = FetchDescriptor<RawVisit>(
            predicate: #Predicate<RawVisit> {
                $0.isCityResolved && $0.arrivalDate < dayEnd && $0.departureDate > dayStart
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchVisitsAfter(date: Date, context: ModelContext) -> [RawVisit] {
        let descriptor = FetchDescriptor<RawVisit>(
            predicate: #Predicate<RawVisit> { $0.isCityResolved && $0.arrivalDate > date }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func findMissingDates(from lastDate: Date?, to today: Date) -> [Date] {
        guard let lastDate = lastDate else { return [today] }
        var missing: [Date] = []
        var cursor = DateHelpers.noonUTC(
            from: Calendar.current.date(byAdding: .day, value: 1, to: lastDate)!
        )
        while cursor <= today {
            missing.append(cursor)
            cursor = DateHelpers.noonUTC(
                from: Calendar.current.date(byAdding: .day, value: 1, to: cursor)!
            )
        }
        return missing
    }

    private func retryUnresolvedGeocoding(context: ModelContext) async {
        let maxAttempts = 5
        let descriptor = FetchDescriptor<RawVisit>(
            predicate: #Predicate<RawVisit> {
                $0.isCityResolved == false && $0.geocodeAttempts < maxAttempts
            }
        )
        guard let unresolved = try? context.fetch(descriptor) else { return }
        for visit in unresolved {
            let resolved = await cityResolver.resolve(visit: visit, context: context)
            if resolved {
                await logger.log(category: "geocoding", event: "geocode_retry_success",
                               detail: visit.resolvedCity ?? "", rawVisitID: visit.id)
            }
        }
    }
}
