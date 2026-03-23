// Roam/Views/Settings/DebugPipelineInspector.swift
import SwiftUI
import SwiftData

@MainActor
struct DebugPipelineInspector: View {
    @Query(sort: \RawVisit.arrivalDate, order: .reverse)
    private var rawVisits: [RawVisit]

    @Query(sort: \DailyEntry.date, order: .reverse)
    private var dailyEntries: [DailyEntry]

    @Query(sort: \CityRecord.totalDays, order: .reverse)
    private var cityRecords: [CityRecord]

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                Text("Raw Visits").tag(0)
                Text("Daily Entries").tag(1)
                Text("City Records").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            switch selectedTab {
            case 0:
                rawVisitsList
            case 1:
                dailyEntriesList
            default:
                cityRecordsList
            }
        }
        .navigationTitle("Pipeline Inspector")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Raw Visits

    private var rawVisitsList: some View {
        List {
            if rawVisits.isEmpty {
                ContentUnavailableView("No Raw Visits", systemImage: "location.slash")
            } else {
                ForEach(rawVisits) { visit in
                    RawVisitRow(visit: visit)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Daily Entries

    private var dailyEntriesList: some View {
        List {
            if dailyEntries.isEmpty {
                ContentUnavailableView("No Daily Entries", systemImage: "calendar.badge.exclamationmark")
            } else {
                ForEach(dailyEntries) { entry in
                    DailyEntryRow(entry: entry)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - City Records

    private var cityRecordsList: some View {
        List {
            if cityRecords.isEmpty {
                ContentUnavailableView("No City Records", systemImage: "building.2.crop.circle")
            } else {
                ForEach(cityRecords) { record in
                    CityRecordRow(record: record)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Row Views

private struct RawVisitRow: View {
    let visit: RawVisit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(visit.isCityResolved ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(visit.resolvedCity ?? "Unresolved")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(visit.isProcessed ? "processed" : "pending")
                    .font(.caption2)
                    .foregroundStyle(visit.isProcessed ? Color.green : Color.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((visit.isProcessed ? Color.green : Color.orange).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 4))
            }
            HStack(spacing: 12) {
                Label(String(format: "%.4f, %.4f", visit.latitude, visit.longitude),
                      systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(visit.arrivalDate.formatted(date: .abbreviated, time: .shortened))
                Text("→")
                if visit.departureDate == .distantFuture {
                    Text("ongoing")
                } else {
                    Text(visit.departureDate.formatted(date: .omitted, time: .shortened))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let region = visit.resolvedRegion, let country = visit.resolvedCountry {
                Text("\(region) · \(country) · \(visit.geocodeAttempts) attempt(s)")
                    .font(.caption2)
                    .foregroundStyle(RoamTheme.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DailyEntryRow: View {
    @Environment(\.colorTheme) private var colorTheme
    let entry: DailyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Spacer()
                if entry.isTravelDay {
                    Label("Travel", systemImage: "airplane")
                        .font(.caption2)
                        .foregroundStyle(colorTheme.accent)
                }
            }
            HStack(spacing: 4) {
                Text(CityDisplayFormatter.format(
                    city: entry.primaryCity.isEmpty ? nil : entry.primaryCity,
                    state: entry.primaryRegion.isEmpty ? nil : entry.primaryRegion,
                    country: entry.primaryCountry.isEmpty ? nil : entry.primaryCountry
                ))
                .font(.subheadline)
                .foregroundStyle(entry.primaryCity.isEmpty ? .secondary : .primary)
            }
            HStack(spacing: 8) {
                confidenceBadge(entry.confidenceRaw)
                sourceBadge(entry.sourceRaw)
                Text(String(format: "%.1fh", entry.totalVisitHours))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func confidenceBadge(_ raw: String) -> some View {
        let color: Color = switch raw {
        case EntryConfidence.highRaw: .green
        case EntryConfidence.mediumRaw: .orange
        default: .red
        }
        Text(raw)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private func sourceBadge(_ raw: String) -> some View {
        Text(raw)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct CityRecordRow: View {
    @Environment(\.colorTheme) private var colorTheme
    let record: CityRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(CityDisplayFormatter.format(
                    city: record.cityName,
                    state: record.region.isEmpty ? nil : record.region,
                    country: record.country.isEmpty ? nil : record.country
                ))
                .font(.subheadline)
                .fontWeight(.medium)
                HStack(spacing: 8) {
                    Label("\(record.totalDays)d", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let first = Optional(record.firstVisitedDate) {
                        Text("since \(first.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                colorIndexDot(index: record.colorIndex)
                Text("#\(record.colorIndex)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorIndexDot(index: Int) -> some View {
        let color = ColorPalette.color(for: index, theme: colorTheme)
        return Circle()
            .fill(color)
            .frame(width: 16, height: 16)
    }
}
