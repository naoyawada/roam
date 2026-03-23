// Roam/Models/CityRecord.swift
import Foundation
import SwiftData

@Model
final class CityRecord {
    var id: UUID = UUID()
    var cityName: String = ""
    var region: String = ""
    var country: String = ""
    var canonicalLatitude: Double = 0.0
    var canonicalLongitude: Double = 0.0
    var colorIndex: Int = 0
    var totalDays: Int = 0
    var firstVisitedDate: Date = Date()
    var lastVisitedDate: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// City key in pipe-delimited format for lookups
    var cityKey: String {
        CityDisplayFormatter.cityKey(
            city: cityName,
            state: region,
            country: country
        )
    }

    init() {}
}
