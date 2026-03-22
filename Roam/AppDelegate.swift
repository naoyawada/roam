import UIKit
import SwiftData
import os

final class AppDelegate: NSObject, UIApplicationDelegate, @unchecked Sendable {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "AppDelegate")

    /// Set by RoamApp.init() before the delegate is created.
    @MainActor static var modelContainer: ModelContainer!

    /// Set by RoamApp.init() so push handler can trigger catch-up.
    @MainActor static var visitPipeline: VisitPipeline?

    @MainActor
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        DeviceTokenService.ensureDeviceID()
        application.registerForRemoteNotifications()
        Self.logger.info("Registered for remote notifications")
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        DeviceTokenService.didRegister(tokenData: deviceToken)
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

            await pipeline.runCatchup()
            completionHandler(.newData)
        }
    }
}
