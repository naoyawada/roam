import SwiftUI
import SwiftData

@main
struct RoamApp: App {
    @Environment(\.scenePhase) private var scenePhase
    let modelContainer: ModelContainer
    let significantLocationService: SignificantLocationService

    init() {
        let iCloudSyncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true

        do {
            // "cloud" config: NightLog + CityColor
            // Uses the same store name regardless of toggle so data is preserved when switching.
            let cloudConfig = ModelConfiguration(
                "cloud",
                schema: Schema([NightLog.self, CityColor.self]),
                cloudKitDatabase: iCloudSyncEnabled ? .automatic : .none
            )

            // "local" config: UserSettings — always local, never syncs
            let localConfig = ModelConfiguration(
                "local",
                schema: Schema([UserSettings.self]),
                cloudKitDatabase: .none
            )

            modelContainer = try ModelContainer(
                for: NightLog.self, CityColor.self, UserSettings.self,
                configurations: cloudConfig, localConfig
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        significantLocationService = SignificantLocationService(modelContainer: modelContainer)

        BackgroundTaskService.register(modelContainer: modelContainer)
        BackgroundTaskService.schedulePrimaryCapture()
        significantLocationService.startMonitoring()

        // Set the app-wide window background to match the theme color
        // so the status bar area and home indicator area aren't white.
        let bg = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.098, green: 0.094, blue: 0.086, alpha: 1)
                : UIColor(red: 0.969, green: 0.969, blue: 0.957, alpha: 1)
        }
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.backgroundColor = bg
                }
            }
        }
        // Also set via appearance for any future windows
        UIWindow.appearance().backgroundColor = bg
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
