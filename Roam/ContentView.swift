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
            ZStack {
                SwipeableTabContainer(selection: $selectedTab, tab0: {
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
                }, tab1: {
                    TimelineView()
                }, tab2: {
                    InsightsView()
                })

                TabView(selection: $selectedTab) {
                    Tab("Dashboard", systemImage: "chart.bar.fill", value: 0) {
                        Color.clear
                    }
                    Tab("Timeline", systemImage: "calendar", value: 1) {
                        Color.clear
                    }
                    Tab("Insights", systemImage: "lightbulb.fill", value: 2) {
                        Color.clear
                    }
                }
                .tint(RoamTheme.accent)
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
                assignMissingColors()
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
