import Foundation
import SwiftData

@Model
final class NightLog: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date.distantPast
    var city: String?
    var state: String?
    var country: String?
    var latitude: Double?
    var longitude: Double?
    var capturedAt: Date = Date.now
    var horizontalAccuracy: Double?
    var sourceRaw: String = CaptureSource.automaticRaw
    var statusRaw: String = LogStatus.confirmedRaw

    var source: CaptureSource {
        get { CaptureSource(rawValue: sourceRaw) ?? .automatic }
        set { sourceRaw = newValue.rawValue }
    }

    var status: LogStatus {
        get { LogStatus(rawValue: statusRaw) ?? .confirmed }
        set { statusRaw = newValue.rawValue }
    }

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
        self.sourceRaw = source.rawValue
        self.statusRaw = status.rawValue
    }
}
