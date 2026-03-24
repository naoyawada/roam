import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorTheme) private var colorTheme
    @Environment(\.modelContext) private var context
    @AppStorage("colorTheme") private var colorThemeRaw: String = ColorTheme.default.rawValue
    @Query private var settingsArray: [UserSettings]
    @Query(
        sort: \DailyEntry.updatedAt,
        order: .reverse
    ) private var allEntries: [DailyEntry]
    @State private var showingCitySearch = false
    @State private var selectedCity: String?
    @State private var selectedState: String?
    @State private var selectedCountry: String?
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true
    @State private var showSyncRestartAlert = false
    @State private var aboutTapCount = 0
    @State private var systemNotificationsDenied = false

    private var settings: UserSettings {
        if let existing = settingsArray.first {
            return existing
        }
        let new = UserSettings()
        context.insert(new)
        try? context.save()
        return new
    }

    private var latestEntry: DailyEntry? {
        allEntries.first { !$0.primaryCity.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Home City") {
                    Button {
                        showingCitySearch = true
                    } label: {
                        HStack {
                            Text("Home City")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(homeCityDisplay)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Color Theme", selection: selectedTheme) {
                        ForEach(ColorTheme.allCases) { theme in
                            HStack(spacing: 4) {
                                ForEach(0..<5, id: \.self) { i in
                                    Circle()
                                        .fill(theme.colors[i])
                                        .frame(width: 10, height: 10)
                                }
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Notifications") {
                    Toggle("Notifications", isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: { newValue in
                            settings.notificationsEnabled = newValue
                            try? context.save()
                            if newValue {
                                Task {
                                    let center = UNUserNotificationCenter.current()
                                    let granted = try? await center.requestAuthorization(options: [.alert, .sound])
                                    if granted == false {
                                        await MainActor.run {
                                            systemNotificationsDenied = true
                                        }
                                    }
                                }
                            }
                        }
                    ))

                    if systemNotificationsDenied {
                        Text("Notifications are disabled in System Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                    }

                }
                Section {
                    Toggle("New City", isOn: Binding(
                        get: { settings.notifyNewCity },
                        set: { settings.notifyNewCity = $0; try? context.save() }
                    ))
                    Toggle("Welcome Back", isOn: Binding(
                        get: { settings.notifyWelcomeBack },
                        set: { settings.notifyWelcomeBack = $0; try? context.save() }
                    ))
                    Toggle("Welcome Home", isOn: Binding(
                        get: { settings.notifyWelcomeHome },
                        set: { settings.notifyWelcomeHome = $0; try? context.save() }
                    ))
                    Toggle("Streak Milestones", isOn: Binding(
                        get: { settings.notifyStreakMilestone },
                        set: { settings.notifyStreakMilestone = $0; try? context.save() }
                    ))
                    Toggle("Travel Day", isOn: Binding(
                        get: { settings.notifyTravelDay },
                        set: { settings.notifyTravelDay = $0; try? context.save() }
                    ))
                    Toggle("Trip Summary", isOn: Binding(
                        get: { settings.notifyTripSummary },
                        set: { settings.notifyTripSummary = $0; try? context.save() }
                    ))
                    Toggle("Monthly Recap", isOn: Binding(
                        get: { settings.notifyMonthlyRecap },
                        set: { settings.notifyMonthlyRecap = $0; try? context.save() }
                    ))
                    Toggle("New Year", isOn: Binding(
                        get: { settings.notifyNewYear },
                        set: { settings.notifyNewYear = $0; try? context.save() }
                    ))
                }
                .disabled(!settings.notificationsEnabled)

                Section("Tracking Status") {
                    if let entry = latestEntry {
                        LabeledContent("Last recorded") {
                            VStack(alignment: .trailing) {
                                Text(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                Text(CityDisplayFormatter.format(
                                    city: entry.primaryCity,
                                    state: entry.primaryRegion,
                                    country: entry.primaryCountry
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        LabeledContent("Last recorded", value: "None yet")
                    }
                }

                Section("Data") {
                    Toggle("iCloud Sync", isOn: $iCloudSyncEnabled)
                        .onChange(of: iCloudSyncEnabled) { oldValue, newValue in
                            guard oldValue != newValue else { return }
                            showSyncRestartAlert = true
                        }
                    NavigationLink("Export Data") {
                        DataExportView()
                    }
                    NavigationLink("Import Data") {
                        DataImportView()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    Text("Roam passively monitors your location to automatically track which cities you visit. Location data is stored on-device and synced via iCloud. Your data is never shared with third parties.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            aboutTapCount += 1
                        }
                }

                if aboutTapCount >= 3 {
                    Section("Debug") {
                        NavigationLink("Debug Tools") {
                            DebugScreen()
                        }
                        LabeledContent("APNs Token") {
                            Text(UserDefaults.standard.string(forKey: "apns_device_token") ?? "Not registered")
                                .font(.caption2)
                                .monospaced()
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(colorTheme.accent)
                }
            }
            .sheet(isPresented: $showingCitySearch) {
                CitySearchView(
                    selectedCity: $selectedCity,
                    selectedState: $selectedState,
                    selectedCountry: $selectedCountry,
                    selectedLatitude: $selectedLatitude,
                    selectedLongitude: $selectedLongitude
                )
            }
            .onChange(of: selectedCity) { _, newCity in
                guard let newCity else { return }
                let key = CityDisplayFormatter.cityKey(city: newCity, state: selectedState, country: selectedCountry)
                settings.homeCityKey = key
                try? context.save()
            }
            .task {
                let status = await UNUserNotificationCenter.current().notificationSettings()
                systemNotificationsDenied = (status.authorizationStatus == .denied)
            }
            .alert("Restart Required", isPresented: $showSyncRestartAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("iCloud sync change takes effect next time you open the app.")
            }
        }
    }

    private var selectedTheme: Binding<ColorTheme> {
        Binding(
            get: { ColorTheme(rawValue: colorThemeRaw) ?? .earthy },
            set: { colorThemeRaw = $0.rawValue }
        )
    }

    private var homeCityDisplay: String {
        guard let key = settings.homeCityKey else { return "Not set" }
        let parts = key.split(separator: "|")
        guard let city = parts.first else { return "Not set" }
        let state = parts.count > 1 ? String(parts[1]) : nil
        let country = parts.count > 2 ? String(parts[2]) : nil
        return CityDisplayFormatter.format(city: String(city), state: state, country: country)
    }
}
