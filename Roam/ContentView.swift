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

    private var lowConfidenceEntries: [DailyEntry] {
        let lowRaw = EntryConfidence.lowRaw
        return allEntries.filter { $0.confidenceRaw == lowRaw }
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
