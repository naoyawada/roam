import SwiftUI
import SwiftData
import BackgroundTasks
import os

@main
struct RoamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer
    let locationProvider: LiveLocationProvider
    let visitPipeline: VisitPipeline
    let pipelineLogger: PipelineLogger

    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "RoamApp")
    static let dailyAggregationTaskID = "com.roamapp.dailyAggregation"

    init() {
        let iCloudSyncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true

        do {
            // Local config: RawVisit, PipelineEvent, UserSettings — never syncs
            let localConfig = ModelConfiguration(
                "local",
                schema: Schema([RawVisit.self, PipelineEvent.self, UserSettings.self]),
                cloudKitDatabase: .none
            )

            // Synced config: DailyEntry, CityRecord — syncs via iCloud (or local if toggled off)
            let syncedConfig = ModelConfiguration(
                "cloud",
                schema: Schema([DailyEntry.self, CityRecord.self]),
                cloudKitDatabase: iCloudSyncEnabled ? .automatic : .none
            )

            // Legacy config: NightLog, CityColor — kept for migration reads, never syncs to iCloud
            // Uses a separate store name so the old CloudKit data is still readable.
            let legacyConfig = ModelConfiguration(
                "legacy",
                schema: Schema([NightLog.self, CityColor.self]),
                cloudKitDatabase: .none
            )

            let container = try ModelContainer(
                for: RawVisit.self, PipelineEvent.self, UserSettings.self,
                    DailyEntry.self, CityRecord.self,
                    NightLog.self, CityColor.self,
                configurations: localConfig, syncedConfig, legacyConfig
            )

            modelContainer = container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Make container available to AppDelegate for push-triggered catch-ups
        AppDelegate.modelContainer = modelContainer

        // Create pipeline logger (uses ModelActor with its own context)
        let logger = PipelineLogger(modelContainer: modelContainer)
        pipelineLogger = logger

        // Create pipeline
        let pipeline = VisitPipeline(modelContainer: modelContainer, logger: logger)
        visitPipeline = pipeline

        // Make pipeline available to AppDelegate
        AppDelegate.visitPipeline = pipeline

        // Create and wire location provider
        let provider = LiveLocationProvider()
        provider.onVisitReceived = { [pipeline] visitData in
            Task { @MainActor in
                await pipeline.handleVisit(visitData)
            }
        }
        locationProvider = provider
        provider.startMonitoring()

        // Run legacy migration if needed
        if !LegacyMigrator.isMigrationComplete {
            let context = ModelContext(modelContainer)
            LegacyMigrator().migrate(context: context)
            Self.logger.info("Legacy migration completed")
        }

        // Register BGTask for daily aggregation
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.dailyAggregationTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await pipeline.runCatchup()
                refreshTask.setTaskCompleted(success: true)
            }
        }
        Self.scheduleDailyAggregation()

        Self.logger.info("RoamApp initialized with CLVisit pipeline")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Self.scheduleDailyAggregation()
                Task { @MainActor in
                    await visitPipeline.runCatchup()
                    await pipelineLogger.pruneOldEvents()
                }
            }
        }
    }

    static func scheduleDailyAggregation() {
        let request = BGAppRefreshTaskRequest(identifier: dailyAggregationTaskID)
        // Schedule for 3 AM tomorrow
        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 3
        components.minute = 0
        let candidate = calendar.date(from: components)!
        request.earliestBeginDate = candidate > Date()
            ? candidate
            : calendar.date(byAdding: .day, value: 1, to: candidate)!
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Failed to schedule daily aggregation: \(error.localizedDescription)")
        }
    }
}
