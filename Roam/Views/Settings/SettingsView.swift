import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsArray: [UserSettings]
    @Query(
        filter: #Predicate<NightLog> {
            $0.statusRaw != "unresolved"
        },
        sort: \NightLog.capturedAt,
        order: .reverse
    ) private var confirmedLogs: [NightLog]
    @State private var showingCitySearch = false
    @State private var selectedCity: String?
    @State private var selectedState: String?
    @State private var selectedCountry: String?

    private var settings: UserSettings {
        if let existing = settingsArray.first {
            return existing
        }
        let new = UserSettings()
        context.insert(new)
        try? context.save()
        return new
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

                Section("Capture Schedule") {
                    DatePicker(
                        "Primary check",
                        selection: Binding(
                            get: { timeFromComponents(hour: settings.primaryCheckHour, minute: settings.primaryCheckMinute) },
                            set: { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                settings.primaryCheckHour = comps.hour ?? 2
                                settings.primaryCheckMinute = comps.minute ?? 0
                                BackgroundTaskService.schedulePrimaryCapture(hour: settings.primaryCheckHour, minute: settings.primaryCheckMinute)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "Retry check",
                        selection: Binding(
                            get: { timeFromComponents(hour: settings.retryCheckHour, minute: settings.retryCheckMinute) },
                            set: { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                settings.retryCheckHour = comps.hour ?? 5
                                settings.retryCheckMinute = comps.minute ?? 0
                                BackgroundTaskService.scheduleRetryCapture(hour: settings.retryCheckHour, minute: settings.retryCheckMinute)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }

                Section("Capture Status") {
                    if let latest = confirmedLogs.first {
                        LabeledContent("Last capture") {
                            VStack(alignment: .trailing) {
                                Text(latest.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                if let city = latest.city {
                                    Text(city)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        LabeledContent("Last capture", value: "None yet")
                    }
                    LabeledContent("Next scheduled") {
                        Text(nextScheduledTime)
                    }
                }

                Section("Data") {
                    Toggle("iCloud Sync", isOn: Binding(
                        get: { settings.iCloudSyncEnabled },
                        set: { settings.iCloudSyncEnabled = $0 }
                    ))
                    Toggle("Unresolved Night Notifications", isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: { settings.notificationsEnabled = $0 }
                    ))
                    NavigationLink("Export Data") {
                        DataExportView()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    Text("Roam tracks your location once nightly to log which city you sleep in. Location data is stored on-device and synced via iCloud. Your data is never shared with third parties.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCitySearch) {
                CitySearchView(
                    selectedCity: $selectedCity,
                    selectedState: $selectedState,
                    selectedCountry: $selectedCountry
                )
            }
            .onChange(of: selectedCity) { _, newCity in
                guard let newCity else { return }
                let key = CityDisplayFormatter.cityKey(city: newCity, state: selectedState, country: selectedCountry)
                settings.homeCityKey = key
                try? context.save()
            }
        }
    }

    private var homeCityDisplay: String {
        guard let key = settings.homeCityKey else { return "Not set" }
        let parts = key.split(separator: "|")
        guard let city = parts.first else { return "Not set" }
        let state = parts.count > 1 ? String(parts[1]) : nil
        let country = parts.count > 2 ? String(parts[2]) : nil
        return CityDisplayFormatter.format(city: String(city), state: state, country: country)
    }

    private var nextScheduledTime: String {
        let hour = settings.primaryCheckHour
        let minute = settings.primaryCheckMinute
        let time = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
        return "Tonight, \(time.formatted(date: .omitted, time: .shortened))"
    }

    private func timeFromComponents(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
    }
}
