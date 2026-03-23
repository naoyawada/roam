import SwiftUI
import SwiftData

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
                            HStack(spacing: 6) {
                                ForEach(0..<5, id: \.self) { i in
                                    Circle()
                                        .fill(theme.colors[i])
                                        .frame(width: 12, height: 12)
                                }
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

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

                #if DEBUG
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
                #endif
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
