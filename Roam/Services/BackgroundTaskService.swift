import BackgroundTasks
import CoreLocation
import os
import SwiftData

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

    @MainActor
    private static func handleCapture(
        task: BGAppRefreshTask,
        isRetry: Bool,
        modelContainer: ModelContainer
    ) async {
        let label = isRetry ? "retry" : "primary"
        logger.info("[\(label)] Background capture starting")

        // Schedule next primary capture regardless of outcome
        schedulePrimaryCapture()

        // Check location authorization before attempting capture
        let authStatus = CLLocationManager().authorizationStatus
        guard authStatus == .authorizedAlways else {
            logger.error("[\(label)] Location not authorized (.authorizedAlways required, got \(String(describing: authStatus)))")
            if isRetry {
                saveUnresolvedEntry(context: modelContainer.mainContext)
            } else {
                scheduleRetryCapture()
            }
            task.setTaskCompleted(success: false)
            return
        }

        let service = LocationCaptureService()
        let context = modelContainer.mainContext

        task.expirationHandler = {
            logger.warning("[\(label)] Task expired before capture completed")
            if !isRetry {
                scheduleRetryCapture()
            }
        }

        guard let result = await service.captureNight() else {
            logger.error("[\(label)] Capture returned nil")
            if isRetry {
                saveUnresolvedEntry(context: context)
            } else {
                scheduleRetryCapture()
            }
            task.setTaskCompleted(success: true)
            return
        }

        // Save confirmed entry
        let nightDate = DateNormalization.normalizedNightDate(from: result.capturedAt)
        let existing = try? context.fetch(
            FetchDescriptor<NightLog>(predicate: #Predicate { $0.date == nightDate })
        ).first

        let unresolvedRaw = LogStatus.unresolvedRaw
        if let existing, existing.statusRaw != unresolvedRaw {
            // Already have a confirmed/manual entry — don't overwrite
            task.setTaskCompleted(success: true)
            return
        }

        if let existing {
            // Update unresolved entry
            existing.city = result.city
            existing.state = result.state
            existing.country = result.country
            existing.latitude = result.latitude
            existing.longitude = result.longitude
            existing.capturedAt = result.capturedAt
            existing.horizontalAccuracy = result.horizontalAccuracy
            existing.source = .automatic
            existing.status = .confirmed
        } else {
            let log = NightLog(
                date: nightDate,
                city: result.city,
                state: result.state,
                country: result.country,
                latitude: result.latitude,
                longitude: result.longitude,
                capturedAt: result.capturedAt,
                horizontalAccuracy: result.horizontalAccuracy,
                source: .automatic,
                status: .confirmed
            )
            context.insert(log)
        }

        // Assign city color if new
        let cityKey = CityDisplayFormatter.cityKey(city: result.city, state: result.state, country: result.country)
        let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
        if !existingColors.contains(where: { $0.cityKey == cityKey }) {
            let nextIndex = (existingColors.map(\.colorIndex).max() ?? -1) + 1
            context.insert(CityColor(cityKey: cityKey, colorIndex: nextIndex))
        }

        do {
            try context.save()
            logger.info("Confirmed entry saved for \(result.city)")
        } catch {
            logger.error("Failed to save confirmed entry: \(error.localizedDescription)")
        }
        task.setTaskCompleted(success: true)
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
