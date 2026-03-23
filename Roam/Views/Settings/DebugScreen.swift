// Roam/Views/Settings/DebugScreen.swift
import SwiftUI
import SwiftData

@MainActor
struct DebugScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorTheme) private var colorTheme

    private var pipeline: VisitPipeline? { AppDelegate.visitPipeline }

    @Query private var rawVisits: [RawVisit]
    @Query private var dailyEntries: [DailyEntry]
    @Query private var cityRecords: [CityRecord]
    @Query private var pipelineEvents: [PipelineEvent]

    @State private var isInjecting = false
    @State private var lastAction: String? = nil
    @State private var showWipeConfirm = false

    var body: some View {
        List {
            quickInjectSection
            scenariosSection
            navigationSection
            dataControlsSection
            statsSection
        }
        .navigationTitle("Debug Tools")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Wipe All Data?", isPresented: $showWipeConfirm, titleVisibility: .visible) {
            Button("Wipe All Data", role: .destructive) {
                wipeAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all RawVisits, DailyEntries, CityRecords, and PipelineEvents.")
        }
        .overlay(alignment: .bottom) {
            if let action = lastAction {
                Text(action)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            withAnimation { lastAction = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Quick Inject Section

    private var quickInjectSection: some View {
        Section("Quick Inject") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(DebugCity.allPresets, id: \.name) { city in
                    Button {
                        Task { await injectSingleVisit(city: city) }
                    } label: {
                        Text(city.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(colorTheme.accentLight, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(colorTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(isInjecting || pipeline == nil)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Scenarios Section

    private var scenariosSection: some View {
        Section("Scenarios") {
            ForEach(DebugScenarios.allScenarios, id: \.name) { scenario in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scenario.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(scenario.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Play") {
                        Task { await playScenario(scenario) }
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(colorTheme.accent)
                    .disabled(isInjecting || pipeline == nil)
                }
            }
        }
    }

    // MARK: - Navigation Section

    private var navigationSection: some View {
        Section("Inspect") {
            NavigationLink("Pipeline Inspector") {
                DebugPipelineInspector()
            }
            NavigationLink("Log Viewer") {
                DebugLogViewer()
            }
        }
    }

    // MARK: - Data Controls Section

    private var dataControlsSection: some View {
        Section("Data Controls") {
            Button("Re-aggregate All") {
                Task { await reaggregateAll() }
            }
            .foregroundStyle(colorTheme.accent)
            .disabled(isInjecting || pipeline == nil)

            Button("Export Pipeline Log as JSON") {
                exportPipelineLog()
            }
            .foregroundStyle(colorTheme.accent)

            Button("Infer Travel Days") {
                DataImportService.inferTravelDays(context: context)
                withAnimation { lastAction = "Travel days inferred from city transitions" }
            }
            .foregroundStyle(colorTheme.accent)

            Button("Wipe All Data", role: .destructive) {
                showWipeConfirm = true
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        Section("Stats") {
            LabeledContent("RawVisits", value: "\(rawVisits.count)")
            LabeledContent("DailyEntries", value: "\(dailyEntries.count)")
            LabeledContent("CityRecords", value: "\(cityRecords.count)")
            LabeledContent("PipelineEvents", value: "\(pipelineEvents.count)")
        }
    }

    // MARK: - Actions

    private func injectSingleVisit(city: DebugCity) async {
        guard let pipeline else { return }
        isInjecting = true
        defer { isInjecting = false }
        let now = Date()
        let arrival = now.addingTimeInterval(-4 * 3600)
        let vd = city.visitData(arrival: arrival, departure: now)
        pipeline.handleVisitForTesting(
            visitData: vd,
            resolvedCity: city.name,
            resolvedRegion: city.state,
            resolvedCountry: city.country
        )
        await pipeline.runCatchup()
        withAnimation { lastAction = "Injected \(city.name)" }
    }

    private func playScenario(_ scenario: DebugScenario) async {
        guard let pipeline else { return }
        isInjecting = true
        defer { isInjecting = false }
        for visit in scenario.visits {
            pipeline.handleVisitForTesting(
                visitData: visit.visitData,
                resolvedCity: visit.resolvedCity,
                resolvedRegion: visit.resolvedRegion,
                resolvedCountry: visit.resolvedCountry
            )
        }
        await pipeline.runCatchup()
        withAnimation { lastAction = "Played \"\(scenario.name)\" (\(scenario.visits.count) visits)" }
    }

    private func wipeAllData() {
        do {
            try context.delete(model: RawVisit.self)
            try context.delete(model: DailyEntry.self)
            try context.delete(model: CityRecord.self)
            try context.delete(model: PipelineEvent.self)
            try context.save()
            withAnimation { lastAction = "All data wiped" }
        } catch {
            withAnimation { lastAction = "Wipe failed: \(error.localizedDescription)" }
        }
    }

    private func reaggregateAll() async {
        guard let pipeline else { return }
        isInjecting = true
        defer { isInjecting = false }
        await pipeline.runCatchup()
        withAnimation { lastAction = "Re-aggregation complete" }
    }

    private func exportPipelineLog() {
        let formatter = ISO8601DateFormatter()
        let dicts: [[String: Any]] = pipelineEvents.sorted { $0.timestamp > $1.timestamp }.map { event in
            var dict: [String: Any] = [
                "id": event.id.uuidString,
                "timestamp": formatter.string(from: event.timestamp),
                "category": event.category,
                "event": event.event,
                "detail": event.detail,
                "appState": event.appState
            ]
            if let rawID = event.rawVisitID { dict["rawVisitID"] = rawID.uuidString }
            if let entryID = event.dailyEntryID { dict["dailyEntryID"] = entryID.uuidString }
            if let metaData = event.metadata.data(using: .utf8),
               let meta = try? JSONSerialization.jsonObject(with: metaData) {
                dict["metadata"] = meta
            }
            return dict
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            withAnimation { lastAction = "Export failed" }
            return
        }
        let av = UIActivityViewController(activityItems: [json], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
        withAnimation { lastAction = "Exported \(pipelineEvents.count) events" }
    }
}
