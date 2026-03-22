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

    @StateObject private var locationService = OnboardingLocationManager()
    @State private var selectedTab: AppTab = .dashboard

    @Query(sort: \DailyEntry.date, order: .reverse) private var allEntries: [DailyEntry]
    @State private var entryToResolve: DailyEntry?

    @State private var showingSettings = false
    @State private var showingLocationUpgradeAlert = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var lowConfidenceEntries: [DailyEntry] {
        let lowRaw = EntryConfidence.lowRaw
        return allEntries.filter { $0.confidenceRaw == lowRaw }
    }

    var body: some View {
        mainTabView
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { if !$0 { hasCompletedOnboarding = true } }
            )) {
                OnboardingView(
                    locationService: locationService,
                    hasCompletedOnboarding: $hasCompletedOnboarding
                )
            }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "chart.bar.fill", value: .dashboard) {
                NavigationStack {
                    DashboardView(
                        showingSettings: $showingSettings,
                        lowConfidenceEntries: lowConfidenceEntries,
                        onResolveLowConfidence: { entryToResolve = $0 }
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
        .sheet(item: $entryToResolve) { entry in
            DayDetailSheet(entry: entry)
        }
        .task {
            DeduplicationService.deduplicateDailyEntries(context: context)
            DeduplicationService.deduplicateCityRecords(context: context)
        }
        .onAppear {
            setWindowBackground()
            configureNavigationBarAppearance()
            checkLocationAuthorization()
        }
        .alert("Background Location Required", isPresented: $showingLocationUpgradeAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Roam needs \"Always\" location access to track your city in the background. Please change location access to \"Always\" in Settings.")
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

    private func checkLocationAuthorization() {
        let status = locationService.authorizationStatus
        if status == .authorizedWhenInUse {
            // Try the programmatic upgrade first — iOS may show the prompt
            locationService.requestAlwaysAuthorization()
            // Show alert after a short delay to give iOS a chance to show its own prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if locationService.authorizationStatus == .authorizedWhenInUse {
                    showingLocationUpgradeAlert = true
                }
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
}
