import SwiftUI
import SwiftData

enum TimelineMode {
    case month
    case year
}

struct TimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DailyEntry.date) private var allEntries: [DailyEntry]
    @Query private var cityRecords: [CityRecord]

    @State private var displayedMonth = Calendar.current.component(.month, from: Date())
    @State private var displayedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedEntry: DailyEntry?
    @State private var mode: TimelineMode = .month
    @State private var navigatingForward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var zoomAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.35)
    }

    private var currentViewHasEntries: Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return allEntries.contains { entry in
            cal.component(.year, from: entry.date) == displayedYear &&
            (mode == .year || cal.component(.month, from: entry.date) == displayedMonth)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let firstWeekday = Calendar.current.firstWeekday - 1
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZStack {
                    if mode == .month {
                        monthContent
                            .transition(.asymmetric(
                                insertion: .scale(scale: 1.0).combined(with: .opacity),
                                removal: .scale(scale: 0.3).combined(with: .opacity)
                            ))
                    }
                    if mode == .year {
                        yearContent
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.3).combined(with: .opacity),
                                removal: .scale(scale: 1.0).combined(with: .opacity)
                            ))
                    }
                }

                if !currentViewHasEntries {
                    Text("No days logged")
                        .font(.subheadline)
                        .foregroundStyle(RoamTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                }

                legend
            }
            .padding()
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.large)
        .grainBackground()
        .sheet(item: $selectedEntry) { entry in
            DayDetailSheet(entry: entry)
        }
    }

    // MARK: - Month View

    private var monthContent: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    navigatingForward = false
                    withAnimation { previousMonth() }
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthYearString)
                    .font(.subheadline)
                    .fontWeight(.regular)
                Spacer()
                Button {
                    navigatingForward = true
                    withAnimation { nextMonth() }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            // Weekday headers
            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid with slide transition
            CalendarGridView(
                year: displayedYear,
                month: displayedMonth,
                entries: allEntries,
                cityRecords: cityRecords
            ) { entry, date in
                if let entry {
                    selectedEntry = entry
                } else {
                    let newEntry = DailyEntry()
                    newEntry.date = date
                    newEntry.source = .manual
                    newEntry.confidence = .low
                    context.insert(newEntry)
                    try? context.save()
                    selectedEntry = newEntry
                }
            }
            .id("\(displayedYear)-\(displayedMonth)")
            .transition(.asymmetric(
                insertion: .move(edge: navigatingForward ? .trailing : .leading),
                removal: .move(edge: navigatingForward ? .leading : .trailing)
            ))
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        guard abs(horizontal) > abs(vertical) else { return }
                        if horizontal < 0 {
                            navigatingForward = true
                            withAnimation { nextMonth() }
                        } else {
                            navigatingForward = false
                            withAnimation { previousMonth() }
                        }
                    }
            )
            .gesture(
                MagnifyGesture()
                    .onEnded { value in
                        if value.magnification < 0.7 {
                            HapticService.medium()
                            withAnimation(zoomAnimation) {
                                mode = .year
                            }
                        }
                    }
            )
        }
        .clipped()
    }

    // MARK: - Year View

    private var yearContent: some View {
        VStack(spacing: 16) {
            // Year navigation
            HStack {
                Button(action: previousYear) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(String(displayedYear))
                    .font(.subheadline)
                    .fontWeight(.regular)
                Spacer()
                Button(action: nextYear) {
                    Image(systemName: "chevron.right")
                }
            }

            YearDotGridView(
                year: displayedYear,
                entries: allEntries,
                cityRecords: cityRecords
            ) { month in
                displayedMonth = month
                HapticService.medium()
                withAnimation(zoomAnimation) {
                    mode = .month
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        guard abs(horizontal) > abs(vertical) else { return }
                        if horizontal < 0 {
                            withAnimation { nextYear() }
                        } else {
                            withAnimation { previousYear() }
                        }
                    }
            )
            .gesture(
                MagnifyGesture()
                    .onEnded { value in
                        if value.magnification > 1.3 {
                            let currentMonth = Calendar.current.component(.month, from: Date())
                            let currentYear = Calendar.current.component(.year, from: Date())
                            displayedMonth = (displayedYear == currentYear) ? currentMonth : 1
                            HapticService.medium()
                            withAnimation(zoomAnimation) {
                                mode = .month
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Navigation

    private var monthYearString: String {
        let components = DateComponents(year: displayedYear, month: displayedMonth)
        let date = Calendar.current.date(from: components)!
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func previousMonth() {
        HapticService.selection()
        if displayedMonth == 1 {
            displayedMonth = 12
            displayedYear -= 1
        } else {
            displayedMonth -= 1
        }
    }

    private func nextMonth() {
        HapticService.selection()
        if displayedMonth == 12 {
            displayedMonth = 1
            displayedYear += 1
        } else {
            displayedMonth += 1
        }
    }

    private func previousYear() {
        HapticService.selection()
        displayedYear -= 1
    }

    private func nextYear() {
        HapticService.selection()
        displayedYear += 1
    }

    // MARK: - Legend

    private var legendEntries: [DailyEntry] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return allEntries.filter {
            cal.component(.year, from: $0.date) == displayedYear
        }
    }

    private var legend: some View {
        var keyCounts: [String: Int] = [:]
        let lowRaw = EntryConfidence.lowRaw
        for entry in legendEntries where entry.confidenceRaw != lowRaw {
            keyCounts[entry.cityKey, default: 0] += 1
        }
        let sorted = cityRecords
            .filter { keyCounts[$0.cityKey] != nil }
            .sorted { keyCounts[$0.cityKey, default: 0] > keyCounts[$1.cityKey, default: 0] }

        return FlowLayout(spacing: 8) {
                ForEach(sorted, id: \.cityKey) { record in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ColorPalette.color(for: record.colorIndex))
                            .frame(width: 10, height: 10)
                        let parts = record.cityKey.split(separator: "|")
                        let city = parts.first.map(String.init)
                        let state = parts.count > 1 ? String(parts[1]) : nil
                        let country = parts.count > 2 ? String(parts[2]) : nil
                        Text(CityDisplayFormatter.format(city: city, state: state, country: country))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(RoamTheme.unresolvedFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(RoamTheme.unresolvedBorder, style: StrokeStyle(lineWidth: 1, dash: [2]))
                        )
                        .frame(width: 10, height: 10)
                    Text("Low confidence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
    }
}
