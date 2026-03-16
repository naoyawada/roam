import Foundation
import SwiftData

@Model
final class UserSettings {
    var homeCityKey: String?
    var primaryCheckHour: Int
    var primaryCheckMinute: Int
    var retryCheckHour: Int
    var retryCheckMinute: Int
    var hasCompletedOnboarding: Bool
    var iCloudSyncEnabled: Bool
    var notificationsEnabled: Bool

    init(
        homeCityKey: String? = nil,
        primaryCheckHour: Int = 2,
        primaryCheckMinute: Int = 0,
        retryCheckHour: Int = 5,
        retryCheckMinute: Int = 0,
        hasCompletedOnboarding: Bool = false,
        iCloudSyncEnabled: Bool = true,
        notificationsEnabled: Bool = true
    ) {
        self.homeCityKey = homeCityKey
        self.primaryCheckHour = primaryCheckHour
        self.primaryCheckMinute = primaryCheckMinute
        self.retryCheckHour = retryCheckHour
        self.retryCheckMinute = retryCheckMinute
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.notificationsEnabled = notificationsEnabled
    }
}
