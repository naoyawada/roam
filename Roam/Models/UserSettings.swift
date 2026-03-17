import Foundation
import SwiftData

@Model
final class UserSettings {
    var homeCityKey: String?
    var primaryCheckHour: Int = 2
    var primaryCheckMinute: Int = 0
    var retryCheckHour: Int = 5
    var retryCheckMinute: Int = 0
    var hasCompletedOnboarding: Bool = false
    var notificationsEnabled: Bool = true

    init(
        homeCityKey: String? = nil,
        primaryCheckHour: Int = 2,
        primaryCheckMinute: Int = 0,
        retryCheckHour: Int = 5,
        retryCheckMinute: Int = 0,
        hasCompletedOnboarding: Bool = false,
        notificationsEnabled: Bool = true
    ) {
        self.homeCityKey = homeCityKey
        self.primaryCheckHour = primaryCheckHour
        self.primaryCheckMinute = primaryCheckMinute
        self.retryCheckHour = retryCheckHour
        self.retryCheckMinute = retryCheckMinute
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationsEnabled = notificationsEnabled
    }
}
