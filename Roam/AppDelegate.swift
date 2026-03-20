import UIKit
import SwiftData
import os

final class AppDelegate: NSObject, UIApplicationDelegate, @unchecked Sendable {

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "AppDelegate")

    /// Set by RoamApp.init() before the delegate is created.
    @MainActor static var modelContainer: ModelContainer!

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
            HeartbeatService.log(.pushReceived)

            guard let container = AppDelegate.modelContainer else {
                Self.logger.error("modelContainer not available for push handling")
                completionHandler(.failed)
                return
            }

            let outcome = await BackgroundTaskService.performCapture(
                modelContainer: container,
                source: isTest ? "test-push" : "push",
                forceCaptureWindow: isTest
            )

            switch outcome {
            case .captured:
                completionHandler(.newData)
            case .skipped:
                completionHandler(.noData)
            case .failed:
                completionHandler(.failed)
            }
        }
    }
}
