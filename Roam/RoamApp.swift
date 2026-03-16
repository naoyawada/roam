import SwiftUI
import SwiftData

@main
struct RoamApp: App {
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
    }
}
