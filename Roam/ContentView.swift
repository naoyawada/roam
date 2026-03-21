import SwiftUI
import SwiftData
import os

enum AppTab: Int, CaseIterable {
    case dashboard = 0
    case timeline = 1
    case insights = 2
}

struct ContentView: View {
    private static let logger = Logger(subsystem: "com.naoyawada.roam", category: "ForegroundCatch")

    @Environment(\.modelContext) private var context
    @Query private var settings: [UserSettings]
    @Query private var allLogs: [NightLog]

    @StateObject private var locationService = LocationCaptureService()
    @State private var selectedTab: AppTab = .dashboard
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
            TabView(selection: $selectedTab) {
                Tab("Dashboard", systemImage: "chart.bar.fill", value: .dashboard) {
                    NavigationStack {
                        DashboardView(
                            showingSettings: $showingSettings,
                            unresolvedLogs: unresolvedLogs,
                            onResolve: { unresolvedToResolve = $0 }
                        )
                    }
                }
                Tab("Timeline", systemImage: "calendar", value: .timeline) {
                    NavigationStack {
                        TimelineView()
                    }
                }
Tab("Insights", systemImage: "lightbulb.fill", value: .insights) {
                    NavigationStack {
                        InsightsView()
                    }
                }
            }
            .tint(RoamTheme.accent)
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
                configureNavigationBarAppearance()
            }
        }
    }

    private func configureNavigationBarAppearance() {
        let titleColor = UIColor(RoamTheme.textPrimary)

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.largeTitleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont.systemFont(ofSize: 34, weight: .regular)
        ]
        scrollEdge.titleTextAttributes = [
            .foregroundColor: titleColor
        ]

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.largeTitleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont.systemFont(ofSize: 34, weight: .regular)
        ]
        standard.titleTextAttributes = [
            .foregroundColor: titleColor
        ]

        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
        UINavigationBar.appearance().standardAppearance = standard
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
