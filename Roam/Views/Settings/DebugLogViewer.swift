// Roam/Views/Settings/DebugLogViewer.swift
import SwiftUI
import SwiftData

@MainActor
struct DebugLogViewer: View {
    @Query(sort: \PipelineEvent.timestamp, order: .reverse)
    private var events: [PipelineEvent]

    @State private var expandedIDs: Set<UUID> = []
    @State private var selectedCategory: String? = nil

    private var categories: [String] {
        let all = events.map(\.category)
        return Array(Set(all)).sorted()
    }

    private var filteredEvents: [PipelineEvent] {
        guard let cat = selectedCategory else { return events }
        return events.filter { $0.category == cat }
    }

    var body: some View {
        List {
            if !categories.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "All", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            ForEach(categories, id: \.self) { cat in
                                FilterChip(label: cat, isSelected: selectedCategory == cat) {
                                    selectedCategory = selectedCategory == cat ? nil : cat
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
            }

            if filteredEvents.isEmpty {
                ContentUnavailableView("No Events", systemImage: "list.bullet.clipboard")
            } else {
                ForEach(filteredEvents) { event in
                    PipelineEventRow(
                        event: event,
                        isExpanded: expandedIDs.contains(event.id)
                    ) {
                        if expandedIDs.contains(event.id) {
                            expandedIDs.remove(event.id)
                        } else {
                            expandedIDs.insert(event.id)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Log Viewer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(filteredEvents.count) events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected ? RoamTheme.accentLight : Color.secondary.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .foregroundStyle(isSelected ? RoamTheme.accent : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pipeline Event Row

private struct PipelineEventRow: View {
    let event: PipelineEvent
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    appStateIndicator
                    categoryIcon
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.event)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        if !event.detail.isEmpty {
                            Text(event.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(isExpanded ? nil : 1)
                        }
                    }
                    Spacer()
                    Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(RoamTheme.textTertiary)
                        .monospacedDigit()
                }

                if isExpanded {
                    expandedContent
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    private var appStateIndicator: some View {
        let color: Color = event.appState == "foreground" ? .green : .orange
        return Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }

    private var categoryIcon: some View {
        let (icon, color) = iconAndColor(for: event.category)
        return Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(color)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()

            HStack(spacing: 16) {
                Label(event.category, systemImage: "tag")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label(event.appState, systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(event.appState == "foreground" ? Color.green : Color.orange)
            }

            Text(event.timestamp.formatted(date: .abbreviated, time: .complete))
                .font(.caption2)
                .foregroundStyle(RoamTheme.textTertiary)
                .monospacedDigit()

            if let rawID = event.rawVisitID {
                HStack(spacing: 4) {
                    Text("RawVisit:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(rawID.uuidString)
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(RoamTheme.textTertiary)
                }
            }

            if let entryID = event.dailyEntryID {
                HStack(spacing: 4) {
                    Text("DailyEntry:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entryID.uuidString)
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(RoamTheme.textTertiary)
                }
            }

            if event.metadata != "{}" {
                Text("Metadata:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(prettyMetadata(event.metadata))
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(RoamTheme.textTertiary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.leading, 35)
    }

    // MARK: - Helpers

    private func iconAndColor(for category: String) -> (String, Color) {
        switch category {
        case "visit_delivery":  return ("location.fill", .blue)
        case "geocoding":       return ("mappin", .purple)
        case "aggregation":     return ("chart.bar.fill", RoamTheme.accent)
        case "trigger":         return ("bolt.fill", .yellow)
        case "background":      return ("moon.fill", .indigo)
        case "error":           return ("exclamationmark.triangle.fill", .red)
        default:                return ("dot.radiowaves.left.and.right", .secondary)
        }
    }

    private func prettyMetadata(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
              let str = String(data: pretty, encoding: .utf8) else {
            return raw
        }
        return str
    }
}
