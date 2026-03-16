import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [UserSettings]
    @Query private var allLogs: [NightLog]

    @StateObject private var locationService = LocationCaptureService()
    @State private var showingSettings = false
    @State private var unresolvedToResolve: NightLog?

    private var unresolvedLogs: [NightLog] {
        allLogs.filter { $0.status == .unresolved }
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
            TabView {
                Tab("Dashboard", systemImage: "chart.bar.fill") {
                    NavigationStack {
                        DashboardView()
                            .safeAreaInset(edge: .top) {
                                if !unresolvedLogs.isEmpty {
                                    UnresolvedBanner(unresolvedCount: unresolvedLogs.count) {
                                        unresolvedToResolve = unresolvedLogs.first
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button {
                                        showingSettings = true
                                    } label: {
                                        Image(systemName: "gearshape")
                                    }
                                }
                            }
                    }
                }
                Tab("Timeline", systemImage: "calendar") {
                    TimelineView()
                }
                Tab("Insights", systemImage: "lightbulb.fill") {
                    InsightsView()
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(item: $unresolvedToResolve) { log in
                UnresolvedResolutionView(log: log)
            }
            .onAppear {
                BackfillService.backfillMissedNights(context: context)
                assignMissingColors()
            }
        }
    }

    private func assignMissingColors() {
        let existingColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
        let existingKeys = Set(existingColors.map(\.cityKey))
        let maxIndex = existingColors.map(\.colorIndex).max() ?? -1

        var nextIndex = maxIndex + 1
        var cityKeys = Set<String>()

        for log in allLogs where log.city != nil {
            let key = CityDisplayFormatter.cityKey(city: log.city, state: log.state, country: log.country)
            if !existingKeys.contains(key) && !cityKeys.contains(key) {
                cityKeys.insert(key)
                let cityColor = CityColor(cityKey: key, colorIndex: nextIndex)
                context.insert(cityColor)
                nextIndex += 1
            }
        }

        if !cityKeys.isEmpty {
            try? context.save()
        }
    }
}
