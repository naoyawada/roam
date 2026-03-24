import Foundation
import SwiftData

@Model
final class UserSettings {
    var homeCityKey: String?
    var hasCompletedOnboarding: Bool = false
    var notificationsEnabled: Bool = false

    // Per-type notification toggles (active when notificationsEnabled is true)
    var notifyNewCity: Bool = true
    var notifyWelcomeBack: Bool = true
    var notifyWelcomeHome: Bool = true
    var notifyStreakMilestone: Bool = true
    var notifyTravelDay: Bool = true
    var notifyTripSummary: Bool = true
    var notifyMonthlyRecap: Bool = true
    var notifyNewYear: Bool = true

    // MARK: - Legacy (kept for SettingsView compat, will be removed in Task 11/14)
    var primaryCheckHour: Int = 2
    var primaryCheckMinute: Int = 0
    var retryCheckHour: Int = 5
    var retryCheckMinute: Int = 0

    init(
        homeCityKey: String? = nil,
        hasCompletedOnboarding: Bool = false,
        notificationsEnabled: Bool = false
    ) {
        self.homeCityKey = homeCityKey
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationsEnabled = notificationsEnabled
    }
}
