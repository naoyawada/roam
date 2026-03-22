import SwiftUI
import SwiftData
import os

enum AppTab: Int, CaseIterable {
    case dashboard = 0
    case timeline = 1
    case insights = 2
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [UserSettings]

    @StateObject private var locationService = LocationCaptureService()
    @State private var selectedTab: AppTab = .dashboard

    // Legacy: DashboardView still expects these parameters (will be removed in Task 11)
    @Query private var allLogs: [NightLog]
    @State private var unresolvedToResolve: NightLog?

    @State private var showingSettings = false

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
                // Legacy deduplication — still needed while NightLog data exists
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
}
