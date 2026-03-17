import SwiftUI
import SwiftData

@main
struct RoamApp: App {
    @Environment(\.scenePhase) private var scenePhase
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: NightLog.self, CityColor.self, UserSettings.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        BackgroundTaskService.register(modelContainer: modelContainer)
        BackgroundTaskService.schedulePrimaryCapture()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Reschedule on every foreground return — ensures the task
                // survives force-quits, reboots, and iOS pruning the schedule.
                BackgroundTaskService.schedulePrimaryCapture()
            }
        }
    }
}
