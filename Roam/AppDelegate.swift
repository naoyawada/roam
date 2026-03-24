import UIKit
import SwiftData
import os

final class AppDelegate: NSObject, UIApplicationDelegate, @unchecked Sendable {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "AppDelegate")

    /// Set by RoamApp.init() before the delegate is created.
    @MainActor static var modelContainer: ModelContainer!

    /// Set by RoamApp.init() so push handler can trigger catch-up.
    @MainActor static var visitPipeline: VisitPipeline?

    /// Set to true if app was relaunched for a location event (force-quit recovery).
    @MainActor static var launchedForLocation = false

    @MainActor
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        Self.logger.info("Registered for remote notifications")

        // If app was relaunched by significant location change (e.g., after force-quit),
        // start monitoring immediately so the pending location event is delivered.
        // RoamApp.init() hasn't run yet at this point, so we can't use the provider —
        // just flag it so RoamApp.init() starts monitoring immediately.
        if launchOptions?[.location] != nil {
            Self.logger.info("App relaunched for location event")
            AppDelegate.launchedForLocation = true
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: "apns_device_token")
        Self.logger.info("APNs token registered: \(hex.prefix(8))...")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Self.logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let isTest = (userInfo["test"] as? Int) == 1
        Self.logger.info("Silent push received (test=\(isTest))")

        Task { @MainActor in
            guard let pipeline = AppDelegate.visitPipeline else {
                Self.logger.error("VisitPipeline not available for push handling")
                completionHandler(.failed)
                return
            }

            await pipeline.runCatchup(trigger: "trigger_push")
            completionHandler(.newData)
        }
    }
}
