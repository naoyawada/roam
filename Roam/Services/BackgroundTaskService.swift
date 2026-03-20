import BackgroundTasks
import CoreLocation
import os
import SwiftData

enum CaptureOutcome: Sendable {
    case captured
    case skipped
    case failed
}

enum BackgroundTaskService {

    static let primaryTaskID = "com.roamapp.nightCapture"
    static let retryTaskID = "com.roamapp.nightCaptureRetry"

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "BackgroundTask")

    /// Register background task handlers. Call once at app launch.
    @MainActor
    static func register(modelContainer: ModelContainer) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: primaryTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await handleCapture(task: refreshTask, isRetry: false, modelContainer: modelContainer)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: retryTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await handleCapture(task: refreshTask, isRetry: true, modelContainer: modelContainer)
            }
        }

        logger.info("Background task handlers registered")
    }

    /// Schedule the primary capture task.
    static func schedulePrimaryCapture(hour: Int = 2, minute: Int = 0) {
        let request = BGAppRefreshTaskRequest(identifier: primaryTaskID)
        request.earliestBeginDate = nextDate(hour: hour, minute: minute)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Primary capture scheduled for \(request.earliestBeginDate?.description ?? "nil")")
        } catch {
            logger.error("Failed to schedule primary capture: \(error.localizedDescription)")
        }
    }

    /// Schedule the retry capture task.
    static func scheduleRetryCapture(hour: Int = 5, minute: Int = 0) {
        let request = BGAppRefreshTaskRequest(identifier: retryTaskID)
        request.earliestBeginDate = nextDate(hour: hour, minute: minute)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Retry capture scheduled for \(request.earliestBeginDate?.description ?? "nil")")
        } catch {
            logger.error("Failed to schedule retry capture: \(error.localizedDescription)")
        }
    }

    /// Shared capture logic used by both BGTask and silent push handlers.
    @MainActor
    static func performCapture(
        modelContainer: ModelContainer,
        source: String
    ) async -> CaptureOutcome {
        logger.info("[\(source)] Capture starting")

        guard SignificantLocationService.isInCaptureWindow(date: .now) else {
            logger.warning("[\(source)] Outside capture window, skipping")
            return .skipped
        }

        let authStatus = CLLocationManager().authorizationStatus
        guard authStatus == .authorizedAlways else {
            logger.error("[\(source)] Location not authorized (.authorizedAlways required, got \(String(describing: authStatus)))")
            HeartbeatService.log(.locationFailed, payload: ["error": "not_authorized", "source": source])
            return .failed
        }

        let service = LocationCaptureService()
        let context = modelContainer.mainContext

        guard let result = await service.captureNight() else {
            logger.error("[\(source)] Capture returned nil")
            HeartbeatService.log(.locationFailed, payload: ["error": "capture_nil", "source": source])
            return .failed
        }

        CaptureResultSaver.save(result: result, context: context)
        HeartbeatService.log(.locationCaptured, payload: [
            "lat": result.latitude,
            "lng": result.longitude,
            "city": result.city,
            "source": source,
        ])
        return .captured
    }

    @MainActor
    private static func handleCapture(
        task: BGAppRefreshTask,
        isRetry: Bool,
        modelContainer: ModelContainer
    ) async {
        let label = isRetry ? "retry" : "primary"
        logger.info("[\(label)] Background capture starting")
        HeartbeatService.log(.bgTaskFired, payload: ["retry": isRetry])

        // Schedule next primary capture regardless of outcome
        schedulePrimaryCapture()

        task.expirationHandler = {
            logger.warning("[\(label)] Task expired before capture completed")
            if !isRetry {
                scheduleRetryCapture()
            }
        }

        let outcome = await performCapture(modelContainer: modelContainer, source: label)

        switch outcome {
        case .captured:
            task.setTaskCompleted(success: true)
        case .skipped:
            task.setTaskCompleted(success: false)
        case .failed:
            if isRetry {
                saveUnresolvedEntry(context: modelContainer.mainContext)
            } else {
                scheduleRetryCapture()
            }
            task.setTaskCompleted(success: false)
        }
    }

    @MainActor
    private static func saveUnresolvedEntry(context: ModelContext) {
        let nightDate = DateNormalization.normalizedNightDate(from: .now)
        let existing = try? context.fetch(
            FetchDescriptor<NightLog>(predicate: #Predicate { $0.date == nightDate })
        ).first
        if existing == nil {
            let log = NightLog(date: nightDate, capturedAt: .now, source: .automatic, status: .unresolved)
            context.insert(log)
            do {
                try context.save()
                logger.info("Unresolved entry saved for \(nightDate)")
            } catch {
                logger.error("Failed to save unresolved entry: \(error.localizedDescription)")
            }
        }
    }

    private static func nextDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        let candidate = calendar.date(from: components)!
        return candidate > Date() ? candidate : calendar.date(byAdding: .day, value: 1, to: candidate)!
    }
}
