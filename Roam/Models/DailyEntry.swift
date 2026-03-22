// Roam/Models/DailyEntry.swift
import Foundation
import SwiftData

@Model
final class DailyEntry: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()  // Noon UTC on the calendar date
    var primaryCity: String = ""
    var primaryRegion: String = ""
    var primaryCountry: String = ""
    var primaryLatitude: Double = 0.0
    var primaryLongitude: Double = 0.0
    var isTravelDay: Bool = false
    var citiesVisitedJSON: String = "[]"
    var totalVisitHours: Double = 0.0
    var sourceRaw: String = EntrySource.visitRaw
    var confidenceRaw: String = EntryConfidence.highRaw
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .visit }
        set { sourceRaw = newValue.rawValue }
    }

    var confidence: EntryConfidence {
        get { EntryConfidence(rawValue: confidenceRaw) ?? .high }
        set { confidenceRaw = newValue.rawValue }
    }

    /// City key in pipe-delimited format for color lookups and analytics
    var cityKey: String {
        CityDisplayFormatter.cityKey(
            city: primaryCity,
            state: primaryRegion,
            country: primaryCountry
        )
    }

    init() {}
}
