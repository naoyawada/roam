import Foundation
import SwiftData

@Model
final class NightLog {
    var id: UUID = UUID()
    @Attribute(.unique) var date: Date
    var city: String?
    var state: String?
    var country: String?
    var latitude: Double?
    var longitude: Double?
    var capturedAt: Date
    var horizontalAccuracy: Double?
    var source: CaptureSource
    var status: LogStatus

    init(
        id: UUID = UUID(),
        date: Date,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        capturedAt: Date = .now,
        horizontalAccuracy: Double? = nil,
        source: CaptureSource = .automatic,
        status: LogStatus = .confirmed
    ) {
        self.id = id
        self.date = date
        self.city = city
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.capturedAt = capturedAt
        self.horizontalAccuracy = horizontalAccuracy
        self.source = source
        self.status = status
    }
}
