import SwiftUI
import SwiftData
import os

struct ContentView: View {
    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "ForegroundCatch")

    @Environment(\.modelContext) private var context
    @Query private var settings: [UserSettings]
    @Query private var allLogs: [NightLog]

    @StateObject private var locationService = LocationCaptureService()
    @State private var selectedTab: Int = 0
    @State private var showingSettings = false
    @State private var unresolvedToResolve: NightLog?

    private var unresolvedLogs: [NightLog] {
        UnresolvedFilter.actionable(allLogs, today: BackfillService.calendarTodayNoonUTC())
    }

    private var hasCompletedOnboarding: Bool {
        settings.first?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(
                locationService: locationService,
                hasCompletedOnboarding: Binding(
                    get: { hasCompletedOnboarding },
                    set: { newValue in
                        if newValue {
                            let s = settings.first ?? UserSettings()
                            if settings.first == nil { context.insert(s) }
                            s.hasCompletedOnboarding = true
                            try? context.save()
                        }
                    }
                )
            )
        } else {
            NativeTabBarContainer(selection: $selectedTab) {
                SwipeableTabContainer(selection: $selectedTab, tab0: {
                    DashboardView(
                        showingSettings: $showingSettings,
                        unresolvedLogs: unresolvedLogs,
                        onResolve: { unresolvedToResolve = $0 }
                    )
                }, tab1: {
                    TimelineView()
                }, tab2: {
                    InsightsView()
                })
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(item: $unresolvedToResolve) { log in
                UnresolvedResolutionView(log: log)
            }
            .task {
                await attemptForegroundCapture()
                BackfillService.backfillMissedNights(context: context)
                DeduplicationService.deduplicateNightLogs(context: context)
                DeduplicationService.deduplicateCityColors(context: context)
                CityColorService.assignMissingColors(context: context)
            }
            .onAppear {
                setWindowBackground()
            }
        }
    }

    private func setWindowBackground() {
        let bg = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.098, green: 0.094, blue: 0.086, alpha: 1)
                : UIColor(red: 0.969, green: 0.969, blue: 0.957, alpha: 1)
        }
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.backgroundColor = bg
                    window.rootViewController?.view.backgroundColor = bg
                }
            }
        }
    }

    private func attemptForegroundCapture() async {
        guard SignificantLocationService.isInCaptureWindow(date: .now) else { return }

        let nightDate = DateNormalization.normalizedNightDate(from: .now)

        let existing = try? context.fetch(
            FetchDescriptor<NightLog>(predicate: #Predicate { $0.date == nightDate })
        ).first

        let unresolvedRaw = LogStatus.unresolvedRaw
        if let existing, existing.statusRaw != unresolvedRaw {
            return
        }

        guard locationService.authorizationStatus == .authorizedAlways else {
            return
        }

        Self.logger.info("Attempting foreground capture for \(nightDate)")
        guard let result = await locationService.captureNight() else {
            Self.logger.error("Foreground capture failed")
            return
        }

        CaptureResultSaver.save(result: result, context: context)
        Self.logger.info("Foreground capture succeeded: \(result.city)")
    }

}
