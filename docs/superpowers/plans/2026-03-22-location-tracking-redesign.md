# Location Tracking Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unreliable BGTaskScheduler-based capture system with a CLVisit-based pipeline featuring last-known-city propagation, confidence levels, and travel day detection.

**Architecture:** CLVisit monitoring captures location passively (iOS-managed wake-ups). A VisitPipeline orchestrator processes visits through geocoding and aggregation into DailyEntry records. For stationary users, last-known-city propagation fills gaps. Three redundant triggers (foreground, BGTask, push) ensure the pipeline runs daily. Confidence levels (high/medium/low) distinguish certain from uncertain entries.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (dual container: local + CloudKit), Core Location (CLVisit monitoring), CLGeocoder, BGTaskScheduler (lightweight trigger only), XcodeGen

**Spec:** `docs/superpowers/specs/2026-03-22-location-tracking-redesign.md`

---

## File Structure

### New Files to Create

**Models:**
- `Roam/Models/RawVisit.swift` — Local-only CLVisit record (spec §2.1)
- `Roam/Models/DailyEntry.swift` — Synced one-per-day record with confidence (spec §2.2)
- `Roam/Models/CityRecord.swift` — Synced per-city stats with colorIndex (spec §2.3)
- `Roam/Models/PipelineEvent.swift` — Local-only structured log entry (spec §2.4)
- `Roam/Models/EntrySource.swift` — String-backed enum for DailyEntry.sourceRaw
- `Roam/Models/EntryConfidence.swift` — String-backed enum for DailyEntry.confidenceRaw
- `Roam/Models/VisitData.swift` — Struct passed from LocationProvider to pipeline

**Services:**
- `Roam/Services/PipelineLogger.swift` — @ModelActor structured logger (spec §7)
- `Roam/Services/LocationProvider.swift` — Protocol + LiveLocationProvider + MockLocationProvider (spec §3)
- `Roam/Services/CityResolver.swift` — Geocoding with coordinate cache and retry (spec §4)
- `Roam/Services/DailyAggregator.swift` — Core aggregation + propagation logic (spec §5)
- `Roam/Services/VisitPipeline.swift` — Central orchestrator (spec §6)
- `Roam/Services/LegacyMigrator.swift` — NightLog → DailyEntry migration (spec §9)
- `Roam/Services/DateHelpers.swift` — noonUTC() helper extracted from DateNormalization

**Views:**
- `Roam/Views/Settings/DebugScreen.swift` — Main debug view (spec §8)
- `Roam/Views/Settings/DebugLogViewer.swift` — PipelineEvent log viewer
- `Roam/Views/Settings/DebugScenarios.swift` — Preset scenarios + injection
- `Roam/Views/Settings/DebugPipelineInspector.swift` — RawVisit/DailyEntry/CityRecord inspector
- `Roam/Views/Shared/ConfidenceBanner.swift` — Replaces UnresolvedBanner

**Tests:**
- `RoamTests/DailyAggregatorTests.swift` — Aggregation, midnight splitting, thresholds, travel days
- `RoamTests/CityPropagationTests.swift` — Last-known-city propagation, departure detection, upgrades
- `RoamTests/CityResolverTests.swift` — Coordinate cache, retry behavior
- `RoamTests/LegacyMigratorTests.swift` — Migration output, travel day inference, color preservation
- `RoamTests/VisitPipelineTests.swift` — End-to-end pipeline with mock provider and geocoder
- `RoamTests/CatchupTests.swift` — Foreground catch-up gap detection and trigger behavior

### Files to Modify
- `Roam/RoamApp.swift` — New container config, pipeline init, migration trigger
- `Roam/AppDelegate.swift` — Push triggers pipeline catch-up instead of capture
- `Roam/ContentView.swift` — Swap NightLog queries for DailyEntry, confidence banner, remove foreground capture
- `Roam/Models/UserSettings.swift` — Remove capture schedule fields (no longer needed)
- `Roam/Services/AnalyticsService.swift` — Rewrite queries against DailyEntry
- `Roam/Services/CityDisplayFormatter.swift` — Adapt for new city identity format
- `Roam/Services/DeduplicationService.swift` — Adapt for DailyEntry deduplication
- `Roam/Views/Dashboard/DashboardView.swift` — Query DailyEntry
- `Roam/Views/Dashboard/CurrentCityBanner.swift` — Use DailyEntry
- `Roam/Views/Dashboard/QuickStatsRow.swift` — Use DailyEntry
- `Roam/Views/Dashboard/TopCitiesList.swift` — Use CityRecord
- `Roam/Views/Dashboard/YearSummaryBar.swift` — Use DailyEntry
- `Roam/Views/Timeline/TimelineView.swift` — Query DailyEntry, travel day indicators
- `Roam/Views/Timeline/CalendarGridView.swift` — Use DailyEntry + CityRecord for colors
- `Roam/Views/Timeline/DayCell.swift` — Confidence indicator, travel day badge
- `Roam/Views/Timeline/DayDetailSheet.swift` — Show confidence, travel info, edit button
- `Roam/Views/Timeline/MiniMonthGridView.swift` — Use DailyEntry
- `Roam/Views/Timeline/YearDotGridView.swift` — Use DailyEntry
- `Roam/Views/Insights/InsightsView.swift` — Use updated AnalyticsService
- `Roam/Views/Settings/SettingsView.swift` — Add debug screen entry, remove capture schedule
- `Roam/Views/Onboarding/OnboardingView.swift` — Update copy for passive monitoring
- `Roam/Info.plist` — Update location usage descriptions
- `project.yml` — Add new source files (auto-discovery, just verify)

### Files to Delete (after migration is stable)
- `Roam/Services/BackgroundTaskService.swift`
- `Roam/Services/LocationCaptureService.swift`
- `Roam/Services/SignificantLocationService.swift`
- `Roam/Services/CaptureResultSaver.swift`
- `Roam/Services/BackfillService.swift`
- `Roam/Services/UnresolvedFilter.swift`
- `Roam/Services/HeartbeatService.swift`
- `Roam/Services/DeviceTokenService.swift`
- `Roam/Services/SupabaseClient.swift`
- `Roam/Services/SupabaseConfig.swift`
- `Roam/Services/DateNormalization.swift`
- `Roam/Services/CityColorService.swift`
- `Roam/Views/Shared/UnresolvedBanner.swift`
- `Roam/Views/Shared/UnresolvedResolutionView.swift`
- `RoamTests/BackfillServiceTests.swift`
- `RoamTests/CaptureResultSaverTests.swift`
- `RoamTests/CityColorServiceTests.swift`
- `RoamTests/DateNormalizationTests.swift`
- `RoamTests/DeduplicationServiceTests.swift`
- `RoamTests/LocationValidationTests.swift`
- `RoamTests/SignificantLocationServiceTests.swift`
- `RoamTests/UnresolvedFilterTests.swift`

---

## Task 1: New Data Models + Enums

**Files:**
- Create: `Roam/Models/EntrySource.swift`
- Create: `Roam/Models/EntryConfidence.swift`
- Create: `Roam/Models/VisitData.swift`
- Create: `Roam/Models/RawVisit.swift`
- Create: `Roam/Models/DailyEntry.swift`
- Create: `Roam/Models/CityRecord.swift`
- Create: `Roam/Models/PipelineEvent.swift`
- Create: `Roam/Services/DateHelpers.swift`

- [ ] **Step 1: Create EntrySource enum**

```swift
// Roam/Models/EntrySource.swift
import Foundation

enum EntrySource: String, Codable, CaseIterable {
    case visit
    case manual
    case propagated
    case fallback
    case migrated
    case debug

    static let visitRaw = "visit"
    static let manualRaw = "manual"
    static let propagatedRaw = "propagated"
    static let fallbackRaw = "fallback"
    static let migratedRaw = "migrated"
    static let debugRaw = "debug"
}
```

- [ ] **Step 2: Create EntryConfidence enum**

```swift
// Roam/Models/EntryConfidence.swift
import Foundation

enum EntryConfidence: String, Codable, CaseIterable {
    case high
    case medium
    case low

    static let highRaw = "high"
    static let mediumRaw = "medium"
    static let lowRaw = "low"
}
```

- [ ] **Step 3: Create VisitData struct**

```swift
// Roam/Models/VisitData.swift
import Foundation
import CoreLocation

struct VisitData: Sendable {
    let latitude: Double
    let longitude: Double
    let arrivalDate: Date
    let departureDate: Date
    let horizontalAccuracy: Double
    let source: String  // "live" | "debug" | "fallback"

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(coordinate: CLLocationCoordinate2D, arrivalDate: Date, departureDate: Date,
         horizontalAccuracy: Double, source: String) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.horizontalAccuracy = horizontalAccuracy
        self.source = source
    }
}
```

- [ ] **Step 4: Create RawVisit model**

```swift
// Roam/Models/RawVisit.swift
import Foundation
import SwiftData
import CoreLocation

@Model
final class RawVisit {
    var id: UUID = UUID()
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var horizontalAccuracy: Double = 0.0
    var arrivalDate: Date = Date.distantPast
    var departureDate: Date = Date.distantFuture

    // City resolution
    var resolvedCity: String? = nil
    var resolvedRegion: String? = nil
    var resolvedCountry: String? = nil
    var isCityResolved: Bool = false
    var geocodeAttempts: Int = 0

    // Pipeline tracking
    var isProcessed: Bool = false
    var source: String = "live"
    var createdAt: Date = Date()

    // Computed
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var durationHours: Double {
        let end = departureDate == .distantFuture ? Date() : departureDate
        return end.timeIntervalSince(arrivalDate) / 3600.0
    }

    init(from visitData: VisitData) {
        self.latitude = visitData.latitude
        self.longitude = visitData.longitude
        self.horizontalAccuracy = visitData.horizontalAccuracy
        self.arrivalDate = visitData.arrivalDate
        self.departureDate = visitData.departureDate
        self.source = visitData.source
    }

    init() {}
}
```

- [ ] **Step 5: Create DailyEntry model**

```swift
// Roam/Models/DailyEntry.swift
import Foundation
import SwiftData

@Model
final class DailyEntry {
    var id: UUID = UUID()
    var date: Date = Date()  // Noon UTC on the calendar date
    var primaryCity: String = ""
    var primaryRegion: String = ""
    var primaryCountry: String = ""
    var primaryLatitude: Double = 0.0
    var primaryLongitude: Double = 0.0
    var isTravelDay: Bool = false
    var citiesVisitedJSON: String = "[]"
    var totalVisitHours: Double = 0.0
    var sourceRaw: String = EntrySource.visitRaw
    var confidenceRaw: String = EntryConfidence.highRaw
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .visit }
        set { sourceRaw = newValue.rawValue }
    }

    var confidence: EntryConfidence {
        get { EntryConfidence(rawValue: confidenceRaw) ?? .high }
        set { confidenceRaw = newValue.rawValue }
    }

    /// City key in pipe-delimited format for color lookups and analytics
    var cityKey: String {
        CityDisplayFormatter.cityKey(
            city: primaryCity,
            state: primaryRegion,
            country: primaryCountry
        )
    }

    init() {}
}
```

- [ ] **Step 6: Create CityRecord model**

```swift
// Roam/Models/CityRecord.swift
import Foundation
import SwiftData

@Model
final class CityRecord {
    var id: UUID = UUID()
    var cityName: String = ""
    var region: String = ""
    var country: String = ""
    var canonicalLatitude: Double = 0.0
    var canonicalLongitude: Double = 0.0
    var colorIndex: Int = 0
    var totalDays: Int = 0
    var firstVisitedDate: Date = Date()
    var lastVisitedDate: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// City key in pipe-delimited format for lookups
    var cityKey: String {
        CityDisplayFormatter.cityKey(
            city: cityName,
            state: region,
            country: country
        )
    }

    init() {}
}
```

- [ ] **Step 7: Create PipelineEvent model**

```swift
// Roam/Models/PipelineEvent.swift
import Foundation
import SwiftData

@Model
final class PipelineEvent {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var category: String = ""
    var event: String = ""
    var detail: String = ""
    var metadata: String = "{}"
    var appState: String = "foreground"
    var rawVisitID: UUID? = nil
    var dailyEntryID: UUID? = nil

    init() {}

    init(category: String, event: String, detail: String = "", metadata: String = "{}",
         appState: String = "foreground", rawVisitID: UUID? = nil, dailyEntryID: UUID? = nil) {
        self.category = category
        self.event = event
        self.detail = detail
        self.metadata = metadata
        self.appState = appState
        self.rawVisitID = rawVisitID
        self.dailyEntryID = dailyEntryID
    }
}
```

- [ ] **Step 8: Create DateHelpers**

Extract the noon-UTC helper from DateNormalization. This is the only piece we keep.

```swift
// Roam/Services/DateHelpers.swift
import Foundation

enum DateHelpers {
    /// Convert a calendar date to noon UTC for stable storage.
    /// Input: any Date representing a calendar day.
    /// Output: noon UTC on that same calendar day.
    static func noonUTC(from date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        var noonComponents = DateComponents()
        noonComponents.year = components.year
        noonComponents.month = components.month
        noonComponents.day = components.day
        noonComponents.hour = 12
        noonComponents.minute = 0
        noonComponents.second = 0

        return utcCalendar.date(from: noonComponents)!
    }

    /// Returns the start of the calendar day (midnight) in the given timezone.
    static func startOfDay(for date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    /// Returns the start of the next calendar day in the given timezone.
    static func endOfDay(for date: Date, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }
}
```

- [ ] **Step 9: Build to verify all models compile**

Run: `xcodegen generate && xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

- [ ] **Step 10: Commit**

```
git add Roam/Models/EntrySource.swift Roam/Models/EntryConfidence.swift Roam/Models/VisitData.swift Roam/Models/RawVisit.swift Roam/Models/DailyEntry.swift Roam/Models/CityRecord.swift Roam/Models/PipelineEvent.swift Roam/Services/DateHelpers.swift
git commit -m "feat: add new data models for CLVisit pipeline"
```

---

## Task 2: PipelineLogger

**Files:**
- Create: `Roam/Services/PipelineLogger.swift`

- [ ] **Step 1: Create PipelineLogger as @ModelActor**

```swift
// Roam/Services/PipelineLogger.swift
import Foundation
import SwiftData
import os

@ModelActor
actor PipelineLogger {
    private static let osLog = Logger(subsystem: "com.naoyawada.roam", category: "Pipeline")

    func log(
        category: String,
        event: String,
        detail: String = "",
        metadata: [String: Any] = [:],
        appState: String = "foreground",
        rawVisitID: UUID? = nil,
        dailyEntryID: UUID? = nil
    ) {
        let entry = PipelineEvent(
            category: category,
            event: event,
            detail: detail,
            metadata: Self.encodeMetadata(metadata),
            appState: appState,
            rawVisitID: rawVisitID,
            dailyEntryID: dailyEntryID
        )
        modelContext.insert(entry)
        try? modelContext.save()

        Self.osLog.info("[\(category)] \(event) — \(detail)")
    }

    func pruneOldEvents(olderThan days: Int = 7) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let descriptor = FetchDescriptor<PipelineEvent>(
            predicate: #Predicate<PipelineEvent> { $0.timestamp < cutoff }
        )
        if let old = try? modelContext.fetch(descriptor) {
            for event in old {
                modelContext.delete(event)
            }
            try? modelContext.save()
        }
    }

    private static func encodeMetadata(_ metadata: [String: Any]) -> String {
        guard !metadata.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: metadata),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

- [ ] **Step 3: Commit**

```
git add Roam/Services/PipelineLogger.swift
git commit -m "feat: add PipelineLogger as @ModelActor"
```

---

## Task 3: LocationProvider Protocol + Implementations

**Files:**
- Create: `Roam/Services/LocationProvider.swift`

- [ ] **Step 1: Create LocationProvider protocol, LiveLocationProvider, and MockLocationProvider**

```swift
// Roam/Services/LocationProvider.swift
import Foundation
import CoreLocation

protocol LocationProvider: AnyObject {
    func startMonitoring()
    func stopMonitoring()
    var onVisitReceived: (@Sendable (VisitData) -> Void)? { get set }
}

@MainActor
final class LiveLocationProvider: NSObject, LocationProvider, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onVisitReceived: (@Sendable (VisitData) -> Void)?

    func startMonitoring() {
        manager.delegate = self
        manager.requestAlwaysAuthorization()
        manager.allowsBackgroundLocationUpdates = true
        manager.startMonitoringVisits()
    }

    func stopMonitoring() {
        manager.stopMonitoringVisits()
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    /// Request a single location fix (for fallback catch-up)
    func requestCurrentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = SingleLocationDelegate(continuation: continuation)
            let tempManager = CLLocationManager()
            tempManager.delegate = delegate
            // Store delegate to prevent deallocation
            objc_setAssociatedObject(tempManager, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            tempManager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let data = VisitData(
            coordinate: visit.coordinate,
            arrivalDate: visit.arrivalDate,
            departureDate: visit.departureDate,
            horizontalAccuracy: visit.horizontalAccuracy,
            source: "live"
        )
        Task { @MainActor in
            onVisitReceived?(data)
        }
    }
}

// Helper for one-shot location request
private final class SingleLocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<CLLocation, Error>?

    init(continuation: CheckedContinuation<CLLocation, Error>) {
        self.continuation = continuation
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            continuation?.resume(returning: location)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

final class MockLocationProvider: LocationProvider {
    var onVisitReceived: (@Sendable (VisitData) -> Void)?

    func startMonitoring() {}
    func stopMonitoring() {}

    func injectVisit(_ visit: VisitData) {
        onVisitReceived?(visit)
    }

    func injectScenario(_ visits: [VisitData]) {
        for visit in visits {
            onVisitReceived?(visit)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

- [ ] **Step 3: Commit**

```
git add Roam/Services/LocationProvider.swift
git commit -m "feat: add LocationProvider protocol with live and mock implementations"
```

---

## Task 4: CityResolver with Coordinate Cache

**Files:**
- Create: `Roam/Services/CityResolver.swift`
- Test: `RoamTests/CityResolverTests.swift`

- [ ] **Step 1: Write failing tests for coordinate cache logic**

```swift
// RoamTests/CityResolverTests.swift
import Testing
import CoreLocation
@testable import Roam

struct CityResolverTests {

    @Test func coordinateCacheReturnsHitWithin5km() {
        let cache = CoordinateCache()
        cache.store(
            latitude: 45.5152, longitude: -122.6784,
            city: "Portland", region: "OR", country: "US"
        )

        // ~1km away from Portland
        let result = cache.lookup(latitude: 45.5200, longitude: -122.6784)
        #expect(result != nil)
        #expect(result?.city == "Portland")
    }

    @Test func coordinateCacheReturnsMissBeyond5km() {
        let cache = CoordinateCache()
        cache.store(
            latitude: 45.5152, longitude: -122.6784,
            city: "Portland", region: "OR", country: "US"
        )

        // San Francisco — well beyond 5km
        let result = cache.lookup(latitude: 37.7749, longitude: -122.4194)
        #expect(result == nil)
    }

    @Test func coordinateCacheHandlesMultipleCities() {
        let cache = CoordinateCache()
        cache.store(latitude: 45.5152, longitude: -122.6784, city: "Portland", region: "OR", country: "US")
        cache.store(latitude: 37.7749, longitude: -122.4194, city: "San Francisco", region: "CA", country: "US")

        let portland = cache.lookup(latitude: 45.5100, longitude: -122.6800)
        #expect(portland?.city == "Portland")

        let sf = cache.lookup(latitude: 37.7800, longitude: -122.4200)
        #expect(sf?.city == "San Francisco")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/CityResolverTests -quiet`
Expected: FAIL — CoordinateCache not defined

- [ ] **Step 3: Implement CityResolver and CoordinateCache**

```swift
// Roam/Services/CityResolver.swift
import Foundation
import CoreLocation

struct CachedCity {
    let city: String
    let region: String
    let country: String
}

final class CoordinateCache: @unchecked Sendable {
    private var entries: [(latitude: Double, longitude: Double, city: CachedCity)] = []
    private let thresholdMeters: Double = 5000.0  // 5.0 km

    func store(latitude: Double, longitude: Double, city: String, region: String, country: String) {
        entries.append((latitude, longitude, CachedCity(city: city, region: region, country: country)))
    }

    func lookup(latitude: Double, longitude: Double) -> CachedCity? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        for entry in entries {
            let entryLocation = CLLocation(latitude: entry.latitude, longitude: entry.longitude)
            if location.distance(from: entryLocation) <= thresholdMeters {
                return entry.city
            }
        }
        return nil
    }

    func clear() {
        entries.removeAll()
    }
}

/// Non-actor class — called from VisitPipeline which owns the ModelContext.
/// Not an actor because ModelContext is not Sendable and must stay on the caller's isolation domain.
final class CityResolver {
    private let geocoder = CLGeocoder()
    let cache = CoordinateCache()
    private let maxAttempts = 5

    @MainActor
    func resolve(visit: RawVisit, context: ModelContext) async -> Bool {
        // Check cache first
        if let cached = cache.lookup(latitude: visit.latitude, longitude: visit.longitude) {
            visit.resolvedCity = cached.city
            visit.resolvedRegion = cached.region
            visit.resolvedCountry = cached.country
            visit.isCityResolved = true
            try? context.save()
            return true
        }

        // Geocode
        do {
            let location = CLLocation(latitude: visit.latitude, longitude: visit.longitude)
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return false }

            let city = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown"
            let region = placemark.administrativeArea ?? ""
            let country = placemark.isoCountryCode ?? ""

            visit.resolvedCity = city
            visit.resolvedRegion = region
            visit.resolvedCountry = country
            visit.isCityResolved = true

            cache.store(latitude: visit.latitude, longitude: visit.longitude,
                       city: city, region: region, country: country)

            try? context.save()
            return true
        } catch {
            visit.geocodeAttempts += 1
            try? context.save()
            return false
        }
    }

    func shouldRetry(visit: RawVisit) -> Bool {
        !visit.isCityResolved && visit.geocodeAttempts < maxAttempts
    }

    func rebuildCache(from visits: [RawVisit]) {
        cache.clear()
        for visit in visits where visit.isCityResolved {
            if let city = visit.resolvedCity, let region = visit.resolvedRegion, let country = visit.resolvedCountry {
                cache.store(latitude: visit.latitude, longitude: visit.longitude,
                           city: city, region: region, country: country)
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/CityResolverTests -quiet`
Expected: PASS

- [ ] **Step 5: Commit**

```
git add Roam/Services/CityResolver.swift RoamTests/CityResolverTests.swift
git commit -m "feat: add CityResolver with coordinate cache"
```

---

## Task 5: DailyAggregator — Core Aggregation Logic

**Files:**
- Create: `Roam/Services/DailyAggregator.swift`
- Test: `RoamTests/DailyAggregatorTests.swift`

- [ ] **Step 1: Write failing tests for aggregation**

```swift
// RoamTests/DailyAggregatorTests.swift
import Testing
import Foundation
@testable import Roam

struct DailyAggregatorTests {
    let aggregator = DailyAggregator()

    // Helper: create a RawVisit with resolved city
    private func makeVisit(
        city: String, region: String, country: String,
        lat: Double, lng: Double,
        arrival: Date, departure: Date
    ) -> RawVisit {
        let v = RawVisit()
        v.latitude = lat
        v.longitude = lng
        v.arrivalDate = arrival
        v.departureDate = departure
        v.resolvedCity = city
        v.resolvedRegion = region
        v.resolvedCountry = country
        v.isCityResolved = true
        return v
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func singleCityFullDay() {
        let visits = [
            makeVisit(city: "Portland", region: "OR", country: "US",
                     lat: 45.5, lng: -122.6,
                     arrival: date(2026, 3, 22, 8),
                     departure: date(2026, 3, 22, 23))
        ]
        let result = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result != nil)
        #expect(result?.primaryCity == "Portland")
        #expect(result?.isTravelDay == false)
        #expect(result?.confidenceRaw == EntryConfidence.highRaw)
    }

    @Test func travelDayTwoCities() {
        let visits = [
            makeVisit(city: "Portland", region: "OR", country: "US",
                     lat: 45.5, lng: -122.6,
                     arrival: date(2026, 3, 22, 7),
                     departure: date(2026, 3, 22, 11)),
            makeVisit(city: "San Francisco", region: "CA", country: "US",
                     lat: 37.7, lng: -122.4,
                     arrival: date(2026, 3, 22, 15),
                     departure: date(2026, 3, 22, 23))
        ]
        let result = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result != nil)
        #expect(result?.primaryCity == "San Francisco")  // 8 hours vs 4 hours
        #expect(result?.isTravelDay == true)
    }

    @Test func layoverFilteredOut() {
        let visits = [
            makeVisit(city: "Portland", region: "OR", country: "US",
                     lat: 45.5, lng: -122.6,
                     arrival: date(2026, 3, 22, 7),
                     departure: date(2026, 3, 22, 11)),
            makeVisit(city: "Denver", region: "CO", country: "US",
                     lat: 39.7, lng: -104.9,
                     arrival: date(2026, 3, 22, 14),
                     departure: date(2026, 3, 22, 15, 30)),  // 90 min layover
            makeVisit(city: "San Francisco", region: "CA", country: "US",
                     lat: 37.7, lng: -122.4,
                     arrival: date(2026, 3, 22, 18),
                     departure: date(2026, 3, 22, 23))
        ]
        let result = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result != nil)
        #expect(result?.isTravelDay == true)
        // Denver should be filtered (< 2 hours)
        // citiesVisitedJSON should not contain Denver
        let json = result?.citiesVisitedJSON ?? "[]"
        #expect(!json.contains("Denver"))
    }

    @Test func midnightSplitCountsCorrectDay() {
        // Visit spans midnight: arrives 10 PM, departs 8 AM next day
        let visits = [
            makeVisit(city: "Portland", region: "OR", country: "US",
                     lat: 45.5, lng: -122.6,
                     arrival: date(2026, 3, 22, 22),
                     departure: date(2026, 3, 23, 8))
        ]
        // For March 22: 10 PM to midnight = 2 hours
        let result22 = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result22 != nil)
        #expect(result22!.totalVisitHours >= 1.9 && result22!.totalVisitHours <= 2.1)

        // For March 23: midnight to 8 AM = 8 hours
        let result23 = aggregator.aggregate(visits: visits, for: date(2026, 3, 23, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result23 != nil)
        #expect(result23!.totalVisitHours >= 7.9 && result23!.totalVisitHours <= 8.1)
    }

    @Test func allBelowThresholdFallsBackToLongest() {
        let visits = [
            makeVisit(city: "Denver", region: "CO", country: "US",
                     lat: 39.7, lng: -104.9,
                     arrival: date(2026, 3, 22, 10),
                     departure: date(2026, 3, 22, 11, 30)),
            makeVisit(city: "Chicago", region: "IL", country: "US",
                     lat: 41.8, lng: -87.6,
                     arrival: date(2026, 3, 22, 14),
                     departure: date(2026, 3, 22, 15))
        ]
        let result = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result != nil)
        #expect(result?.primaryCity == "Denver")  // 1.5 hours > 1 hour
        #expect(result?.confidenceRaw == EntryConfidence.lowRaw)  // all below threshold
    }

    @Test func noVisitsReturnsNil() {
        let result = aggregator.aggregate(visits: [], for: date(2026, 3, 22, 0))
        #expect(result == nil)
    }

    @Test func ongoingVisitClampedToNow() {
        let visits = [
            makeVisit(city: "Portland", region: "OR", country: "US",
                     lat: 45.5, lng: -122.6,
                     arrival: date(2026, 3, 22, 8),
                     departure: Date.distantFuture)
        ]
        let result = aggregator.aggregate(visits: visits, for: date(2026, 3, 22, 0), timeZone: TimeZone(identifier: "UTC")!)
        #expect(result != nil)
        // Should not have absurdly large hours
        #expect(result!.totalVisitHours < 24.1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DailyAggregatorTests -quiet`
Expected: FAIL — DailyAggregator not defined

- [ ] **Step 3: Implement DailyAggregator**

```swift
// Roam/Services/DailyAggregator.swift
import Foundation

struct DailyAggregator {
    static let minimumVisitHours: Double = 2.0

    func aggregate(visits: [RawVisit], for date: Date, timeZone: TimeZone = .current) -> DailyEntry? {
        let dayStart = DateHelpers.startOfDay(for: date, timeZone: timeZone)
        let dayEnd = DateHelpers.endOfDay(for: date, timeZone: timeZone)
        let now = Date()

        let relevantVisits = visits.filter { visit in
            visit.isCityResolved &&
            visit.arrivalDate < dayEnd &&
            (visit.departureDate == .distantFuture ? now : visit.departureDate) > dayStart
        }

        guard !relevantVisits.isEmpty else { return nil }

        // Calculate hours per city for this calendar date
        var cityHours: [String: Double] = [:]
        var cityDetails: [String: (region: String, country: String, lat: Double, lng: Double)] = [:]

        for visit in relevantVisits {
            let effectiveDeparture = visit.departureDate == .distantFuture ? min(now, dayEnd) : visit.departureDate
            let overlapStart = max(visit.arrivalDate, dayStart)
            let overlapEnd = min(effectiveDeparture, dayEnd)
            let hours = max(0, overlapEnd.timeIntervalSince(overlapStart) / 3600.0)

            let key = "\(visit.resolvedCity ?? ""), \(visit.resolvedRegion ?? "")"
            cityHours[key, default: 0] += hours

            if cityDetails[key] == nil {
                cityDetails[key] = (
                    region: visit.resolvedRegion ?? "",
                    country: visit.resolvedCountry ?? "",
                    lat: visit.latitude,
                    lng: visit.longitude
                )
            }
        }

        // Filter short visits
        let meaningfulCities = cityHours.filter { $0.value >= Self.minimumVisitHours }
        let allBelowThreshold = meaningfulCities.isEmpty
        let citiesToConsider = allBelowThreshold ? cityHours : meaningfulCities

        // Longest stay wins
        guard let (primaryKey, _) = citiesToConsider.max(by: { $0.value < $1.value }),
              let details = cityDetails[primaryKey] else {
            return nil
        }

        let isTravelDay = citiesToConsider.count > 1

        // Chronological city list
        let orderedCities = citiesToConsider.keys.sorted { a, b in
            let aVisit = relevantVisits.first { "\($0.resolvedCity ?? ""), \($0.resolvedRegion ?? "")" == a }
            let bVisit = relevantVisits.first { "\($0.resolvedCity ?? ""), \($0.resolvedRegion ?? "")" == b }
            return (aVisit?.arrivalDate ?? .distantPast) < (bVisit?.arrivalDate ?? .distantPast)
        }

        // Build citiesVisitedJSON as structured objects
        let cityObjects = orderedCities.compactMap { key -> [String: String]? in
            guard let detail = cityDetails[key] else { return nil }
            let cityName = key.components(separatedBy: ", ").first ?? key
            return ["city": cityName, "region": detail.region, "country": detail.country]
        }
        let citiesJSON = (try? JSONEncoder().encode(cityObjects))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        // Build entry
        let entry = DailyEntry()
        entry.date = DateHelpers.noonUTC(from: date, timeZone: timeZone)
        entry.primaryCity = primaryKey.components(separatedBy: ", ").first ?? primaryKey
        entry.primaryRegion = details.region
        entry.primaryCountry = details.country
        entry.primaryLatitude = details.lat
        entry.primaryLongitude = details.lng
        entry.isTravelDay = isTravelDay
        entry.citiesVisitedJSON = citiesJSON
        entry.totalVisitHours = citiesToConsider.values.reduce(0, +)
        entry.sourceRaw = EntrySource.visitRaw
        entry.confidenceRaw = allBelowThreshold ? EntryConfidence.lowRaw : EntryConfidence.highRaw
        entry.updatedAt = Date()

        return entry
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/DailyAggregatorTests -quiet`
Expected: PASS

- [ ] **Step 5: Commit**

```
git add Roam/Services/DailyAggregator.swift RoamTests/DailyAggregatorTests.swift
git commit -m "feat: add DailyAggregator with threshold filtering and midnight splitting"
```

---

## Task 6: Last-Known-City Propagation Tests + Logic

**Files:**
- Test: `RoamTests/CityPropagationTests.swift`
- Modify: `Roam/Services/DailyAggregator.swift` (add propagation method)

- [ ] **Step 1: Write failing tests for propagation**

```swift
// RoamTests/CityPropagationTests.swift
import Testing
import Foundation
import SwiftData
@testable import Roam

struct CityPropagationTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: RawVisit.self, DailyEntry.self, CityRecord.self, PipelineEvent.self,
            configurations: config
        )
    }

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateHelpers.noonUTC(
            from: {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(identifier: "UTC")!
                return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
            }(),
            timeZone: TimeZone(identifier: "UTC")!
        )
    }

    @Test func propagatesLastKnownCityWhenNoDeparture() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Existing entry: March 20 in Portland
        let existing = DailyEntry()
        existing.date = noonUTC(2026, 3, 20)
        existing.primaryCity = "Portland"
        existing.primaryRegion = "OR"
        existing.primaryCountry = "US"
        existing.primaryLatitude = 45.5
        existing.primaryLongitude = -122.6
        existing.sourceRaw = EntrySource.visitRaw
        existing.confidenceRaw = EntryConfidence.highRaw
        context.insert(existing)
        try context.save()

        let aggregator = DailyAggregator()
        let result = aggregator.propagate(
            for: noonUTC(2026, 3, 21),
            lastEntry: existing,
            recentVisits: [],  // No visits at a different city
            context: context
        )

        #expect(result != nil)
        #expect(result?.primaryCity == "Portland")
        #expect(result?.confidenceRaw == EntryConfidence.mediumRaw)
        #expect(result?.sourceRaw == EntrySource.propagatedRaw)
    }

    @Test func detectsDepartureWhenVisitAtDifferentCity() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = DailyEntry()
        existing.date = noonUTC(2026, 3, 20)
        existing.primaryCity = "Portland"
        existing.primaryRegion = "OR"
        existing.primaryCountry = "US"
        existing.sourceRaw = EntrySource.visitRaw
        context.insert(existing)

        // A visit at San Francisco after March 20 = departure detected
        let sfVisit = RawVisit()
        sfVisit.resolvedCity = "San Francisco"
        sfVisit.resolvedRegion = "CA"
        sfVisit.resolvedCountry = "US"
        sfVisit.arrivalDate = noonUTC(2026, 3, 21)
        sfVisit.isCityResolved = true
        context.insert(sfVisit)
        try context.save()

        let aggregator = DailyAggregator()
        let result = aggregator.propagate(
            for: noonUTC(2026, 3, 21),
            lastEntry: existing,
            recentVisits: [sfVisit],
            context: context
        )

        // Should NOT propagate Portland — departure was detected
        #expect(result == nil)
    }

    @Test func sameVisitDoesNotCountAsDeparture() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let existing = DailyEntry()
        existing.date = noonUTC(2026, 3, 20)
        existing.primaryCity = "Portland"
        existing.primaryRegion = "OR"
        existing.primaryCountry = "US"
        existing.sourceRaw = EntrySource.visitRaw
        context.insert(existing)

        // A visit at Portland (same city) — not a departure
        let pdxVisit = RawVisit()
        pdxVisit.resolvedCity = "Portland"
        pdxVisit.resolvedRegion = "OR"
        pdxVisit.resolvedCountry = "US"
        pdxVisit.arrivalDate = noonUTC(2026, 3, 21)
        pdxVisit.isCityResolved = true
        context.insert(pdxVisit)
        try context.save()

        let aggregator = DailyAggregator()
        let result = aggregator.propagate(
            for: noonUTC(2026, 3, 21),
            lastEntry: existing,
            recentVisits: [pdxVisit],
            context: context
        )

        #expect(result != nil)
        #expect(result?.primaryCity == "Portland")
        #expect(result?.confidenceRaw == EntryConfidence.mediumRaw)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/CityPropagationTests -quiet`
Expected: FAIL — `propagate` method not defined

- [ ] **Step 3: Add propagation method to DailyAggregator**

Add to `Roam/Services/DailyAggregator.swift`:

```swift
/// Propagate the last known city when no visits exist for a date.
/// Returns nil if a departure was detected (visit at a different city exists).
func propagate(
    for date: Date,
    lastEntry: DailyEntry,
    recentVisits: [RawVisit],
    context: ModelContext
) -> DailyEntry? {
    // Check if any resolved visit exists at a different city
    let departureDetected = recentVisits.contains { visit in
        visit.isCityResolved &&
        (visit.resolvedCity != lastEntry.primaryCity ||
         visit.resolvedRegion != lastEntry.primaryRegion)
    }

    if departureDetected {
        return nil  // Can't propagate — user left
    }

    // Propagate last known city
    let entry = DailyEntry()
    entry.date = date
    entry.primaryCity = lastEntry.primaryCity
    entry.primaryRegion = lastEntry.primaryRegion
    entry.primaryCountry = lastEntry.primaryCountry
    entry.primaryLatitude = lastEntry.primaryLatitude
    entry.primaryLongitude = lastEntry.primaryLongitude
    entry.isTravelDay = false
    entry.citiesVisitedJSON = "[]"
    entry.totalVisitHours = 0
    entry.sourceRaw = EntrySource.propagatedRaw
    entry.confidenceRaw = EntryConfidence.mediumRaw
    entry.updatedAt = Date()

    return entry
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/CityPropagationTests -quiet`
Expected: PASS

- [ ] **Step 5: Commit**

```
git add Roam/Services/DailyAggregator.swift RoamTests/CityPropagationTests.swift
git commit -m "feat: add last-known-city propagation to DailyAggregator"
```

---

## Task 7: VisitPipeline Orchestrator

**Files:**
- Create: `Roam/Services/VisitPipeline.swift`
- Test: `RoamTests/VisitPipelineTests.swift`

- [ ] **Step 1: Write failing test for pipeline end-to-end**

```swift
// RoamTests/VisitPipelineTests.swift
import Testing
import Foundation
import SwiftData
import CoreLocation
@testable import Roam

struct VisitPipelineTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: RawVisit.self, DailyEntry.self, CityRecord.self, PipelineEvent.self,
            configurations: config
        )
    }

    @Test func handleVisitCreatesRawVisitAndDailyEntry() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let logger = PipelineLogger(modelContainer: container)
        let pipeline = VisitPipeline(modelContainer: container, logger: logger)

        let visitDate = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            return cal.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 8))!
        }()
        let departureDate = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            return cal.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 23))!
        }()

        // Use pipeline with mock geocoder
        await pipeline.handleVisitForTesting(
            visitData: VisitData(
                coordinate: CLLocationCoordinate2D(latitude: 45.5152, longitude: -122.6784),
                arrivalDate: visitDate,
                departureDate: departureDate,
                horizontalAccuracy: 10.0,
                source: "debug"
            ),
            resolvedCity: "Portland",
            resolvedRegion: "OR",
            resolvedCountry: "US"
        )

        // Verify RawVisit was created
        let rawVisits = try context.fetch(FetchDescriptor<RawVisit>())
        #expect(rawVisits.count == 1)
        #expect(rawVisits.first?.isCityResolved == true)

        // Verify DailyEntry was created
        let entries = try context.fetch(FetchDescriptor<DailyEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.primaryCity == "Portland")
        #expect(entries.first?.confidenceRaw == EntryConfidence.highRaw)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/VisitPipelineTests -quiet`
Expected: FAIL — VisitPipeline not defined

- [ ] **Step 3: Implement VisitPipeline**

```swift
// Roam/Services/VisitPipeline.swift
import Foundation
import SwiftData
import CoreLocation

@MainActor
final class VisitPipeline {
    private let modelContainer: ModelContainer
    private let logger: PipelineLogger
    private let aggregator = DailyAggregator()
    private let cityResolver = CityResolver()
    private let accuracyThreshold: Double = 1000.0

    init(modelContainer: ModelContainer, logger: PipelineLogger) {
        self.modelContainer = modelContainer
        self.logger = logger
    }

    // MARK: - Handle Incoming Visit

    func handleVisit(_ visitData: VisitData) async {
        let context = ModelContext(modelContainer)

        // Filter by accuracy
        guard visitData.horizontalAccuracy <= accuracyThreshold else {
            await logger.log(category: "visit_delivery", event: "visit_accuracy_rejected",
                           detail: "accuracy: \(visitData.horizontalAccuracy)m")
            return
        }

        await logger.log(category: "visit_delivery", event: "visit_received",
                        detail: "\(visitData.coordinate.latitude), \(visitData.coordinate.longitude)")

        // Save RawVisit
        let rawVisit = RawVisit(from: visitData)
        context.insert(rawVisit)
        try? context.save()

        // Resolve city
        let resolved = await cityResolver.resolve(visit: rawVisit, context: context)
        if resolved {
            await logger.log(category: "geocoding", event: "geocode_success",
                           detail: "\(rawVisit.resolvedCity ?? ""), \(rawVisit.resolvedRegion ?? ""), \(rawVisit.resolvedCountry ?? "")",
                           rawVisitID: rawVisit.id)
        } else {
            await logger.log(category: "geocoding", event: "geocode_failed",
                           detail: "attempt \(rawVisit.geocodeAttempts)",
                           rawVisitID: rawVisit.id)
        }

        // Aggregate affected dates
        if resolved {
            await aggregateDates(for: rawVisit, context: context)
        }
    }

    // MARK: - Catch-up (triggered by foreground/BGTask/push)

    func runCatchup() async {
        let context = ModelContext(modelContainer)

        await logger.log(category: "trigger", event: "trigger_foreground")

        // Retry unresolved geocoding
        await retryUnresolvedGeocoding(context: context)

        // Find dates needing entries
        let lastEntry = fetchLastEntry(context: context)
        let today = DateHelpers.noonUTC(from: Date())
        let missingDates = findMissingDates(from: lastEntry?.date, to: today)

        for date in missingDates {
            // Check for unprocessed visits for this date
            let visits = fetchVisits(for: date, context: context)
            if !visits.isEmpty {
                let entry = aggregator.aggregate(visits: visits, for: date)
                if let entry = entry {
                    upsertEntry(entry, context: context)
                    await updateCityRecord(for: entry, context: context)
                    await logger.log(category: "aggregation", event: "entry_created",
                                   detail: "\(entry.primaryCity)", dailyEntryID: entry.id)
                    continue
                }
            }

            // No visits — propagate last known city or create fallback
            if let lastEntry = fetchLastEntryBefore(date: date, context: context) {
                let recentVisits = fetchVisitsAfter(date: lastEntry.date, context: context)
                if let propagated = aggregator.propagate(for: date, lastEntry: lastEntry,
                                                         recentVisits: recentVisits, context: context) {
                    upsertEntry(propagated, context: context)
                    await logger.log(category: "aggregation", event: "city_propagated",
                                   detail: "\(propagated.primaryCity)", dailyEntryID: propagated.id)
                } else {
                    // Departure detected but no arrival — create low-confidence fallback
                    let fallback = DailyEntry()
                    fallback.date = date
                    fallback.sourceRaw = EntrySource.fallbackRaw
                    fallback.confidenceRaw = EntryConfidence.lowRaw
                    // Use the departure city from the most recent visit at a different city
                    if let departureVisit = recentVisits.first(where: {
                        $0.resolvedCity != lastEntry.primaryCity || $0.resolvedRegion != lastEntry.primaryRegion
                    }) {
                        fallback.primaryCity = departureVisit.resolvedCity ?? ""
                        fallback.primaryRegion = departureVisit.resolvedRegion ?? ""
                        fallback.primaryCountry = departureVisit.resolvedCountry ?? ""
                        fallback.primaryLatitude = departureVisit.latitude
                        fallback.primaryLongitude = departureVisit.longitude
                    }
                    fallback.updatedAt = Date()
                    upsertEntry(fallback, context: context)
                    await logger.log(category: "aggregation", event: "entry_created",
                                   detail: "fallback: \(fallback.primaryCity)", dailyEntryID: fallback.id)
                }
            }
        }
    }

    // MARK: - Testing Helper (bypasses real geocoding)

    func handleVisitForTesting(visitData: VisitData, resolvedCity: String, resolvedRegion: String, resolvedCountry: String) async {
        let context = ModelContext(modelContainer)

        let rawVisit = RawVisit(from: visitData)
        rawVisit.resolvedCity = resolvedCity
        rawVisit.resolvedRegion = resolvedRegion
        rawVisit.resolvedCountry = resolvedCountry
        rawVisit.isCityResolved = true
        context.insert(rawVisit)
        try? context.save()

        await aggregateDates(for: rawVisit, context: context)
    }

    // MARK: - Private Helpers

    private func aggregateDates(for visit: RawVisit, context: ModelContext) async {
        let affectedDates = determineDates(for: visit)
        for date in affectedDates {
            let allVisits = fetchVisits(for: date, context: context)
            if let entry = aggregator.aggregate(visits: allVisits, for: date) {
                upsertEntry(entry, context: context)
                await updateCityRecord(for: entry, context: context)
                await logger.log(category: "aggregation", event: "entry_created",
                               detail: "\(entry.primaryCity)", dailyEntryID: entry.id)
            }
        }
    }

    private func determineDates(for visit: RawVisit) -> [Date] {
        var dates: [Date] = []
        var cursor = DateHelpers.startOfDay(for: visit.arrivalDate)
        let effectiveDeparture = visit.departureDate == .distantFuture ? Date() : visit.departureDate
        let endDay = DateHelpers.startOfDay(for: effectiveDeparture)

        while cursor <= endDay {
            dates.append(cursor)
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)!
        }
        return dates
    }

    /// Returns the old city key if the entry's primary city changed, for CityRecord stat adjustment.
    private func upsertEntry(_ entry: DailyEntry, context: ModelContext) -> String? {
        // Fetch existing entry for this date
        // Note: noon-UTC date equality is safe because dates are always created by DateHelpers.noonUTC()
        let targetDate = entry.date
        let descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { $0.date == targetDate }
        )
        var oldCityKey: String? = nil
        if let existing = try? context.fetch(descriptor).first {
            // Track if city changed for CityRecord stat adjustment
            if existing.primaryCity != entry.primaryCity || existing.primaryRegion != entry.primaryRegion {
                oldCityKey = existing.cityKey
            }
            // Update existing
            existing.primaryCity = entry.primaryCity
            existing.primaryRegion = entry.primaryRegion
            existing.primaryCountry = entry.primaryCountry
            existing.primaryLatitude = entry.primaryLatitude
            existing.primaryLongitude = entry.primaryLongitude
            existing.isTravelDay = entry.isTravelDay
            existing.citiesVisitedJSON = entry.citiesVisitedJSON
            existing.totalVisitHours = entry.totalVisitHours
            existing.sourceRaw = entry.sourceRaw
            existing.confidenceRaw = entry.confidenceRaw
            existing.updatedAt = Date()
        } else {
            context.insert(entry)
        }
        try? context.save()
        return oldCityKey
    }

    private func updateCityRecord(for entry: DailyEntry, context: ModelContext) async {
        let cityName = entry.primaryCity
        let region = entry.primaryRegion
        let country = entry.primaryCountry

        let descriptor = FetchDescriptor<CityRecord>(
            predicate: #Predicate<CityRecord> {
                $0.cityName == cityName && $0.region == region && $0.country == country
            }
        )

        let record: CityRecord
        if let existing = try? context.fetch(descriptor).first {
            record = existing
        } else {
            record = CityRecord()
            record.cityName = cityName
            record.region = region
            record.country = country
            record.canonicalLatitude = entry.primaryLatitude
            record.canonicalLongitude = entry.primaryLongitude
            record.firstVisitedDate = entry.date
            // Assign next color index
            let allRecords = (try? context.fetch(FetchDescriptor<CityRecord>())) ?? []
            record.colorIndex = (allRecords.map(\.colorIndex).max() ?? -1) + 1
            context.insert(record)
        }

        // Recount total days for this city
        let allEntries = (try? context.fetch(FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> {
                $0.primaryCity == cityName && $0.primaryRegion == region && $0.primaryCountry == country
            }
        ))) ?? []
        record.totalDays = allEntries.count
        record.lastVisitedDate = allEntries.map(\.date).max() ?? entry.date
        record.updatedAt = Date()

        try? context.save()
    }

    private func fetchLastEntry(context: ModelContext) -> DailyEntry? {
        var descriptor = FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchLastEntryBefore(date: Date, context: ModelContext) -> DailyEntry? {
        var descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate<DailyEntry> { $0.date < date },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchVisits(for date: Date, context: ModelContext) -> [RawVisit] {
        let dayStart = DateHelpers.startOfDay(for: date)
        let dayEnd = DateHelpers.endOfDay(for: date)
        let descriptor = FetchDescriptor<RawVisit>(
            predicate: #Predicate<RawVisit> {
                $0.isCityResolved && $0.arrivalDate < dayEnd && $0.departureDate > dayStart
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchVisitsAfter(date: Date, context: ModelContext) -> [RawVisit] {
        let descriptor = FetchDescriptor<RawVisit>(
            predicate: #Predicate<RawVisit> { $0.isCityResolved && $0.arrivalDate > date }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func findMissingDates(from lastDate: Date?, to today: Date) -> [Date] {
        guard let lastDate = lastDate else { return [today] }
        var missing: [Date] = []
        var cursor = DateHelpers.noonUTC(
            from: Calendar.current.date(byAdding: .day, value: 1, to: lastDate)!
        )
        while cursor <= today {
            missing.append(cursor)
            cursor = DateHelpers.noonUTC(
                from: Calendar.current.date(byAdding: .day, value: 1, to: cursor)!
            )
        }
        return missing
    }

    private func retryUnresolvedGeocoding(context: ModelContext) async {
        let maxAttempts = 5
        let descriptor = FetchDescriptor<RawVisit>(
            predicate: #Predicate<RawVisit> {
                $0.isCityResolved == false && $0.geocodeAttempts < maxAttempts
            }
        )
        guard let unresolved = try? context.fetch(descriptor) else { return }
        for visit in unresolved {
            let resolved = await cityResolver.resolve(visit: visit, context: context)
            if resolved {
                await logger.log(category: "geocoding", event: "geocode_retry_success",
                               detail: "\(visit.resolvedCity ?? "")", rawVisitID: visit.id)
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/VisitPipelineTests -quiet`
Expected: PASS

- [ ] **Step 5: Commit**

```
git add Roam/Services/VisitPipeline.swift RoamTests/VisitPipelineTests.swift
git commit -m "feat: add VisitPipeline orchestrator"
```

---

## Task 8: Legacy Migration

**Files:**
- Create: `Roam/Services/LegacyMigrator.swift`
- Test: `RoamTests/LegacyMigratorTests.swift`

- [ ] **Step 1: Write failing tests for migration**

```swift
// RoamTests/LegacyMigratorTests.swift
import Testing
import Foundation
import SwiftData
@testable import Roam

struct LegacyMigratorTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: NightLog.self, CityColor.self, RawVisit.self, DailyEntry.self, CityRecord.self, PipelineEvent.self,
            configurations: config
        )
    }

    private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func migratesSingleEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = NightLog(
            date: noonUTC(2026, 3, 1),
            city: "Atlanta", state: "GA", country: "US",
            latitude: 33.749, longitude: -84.388,
            capturedAt: Date(),
            source: .manual, status: .confirmed
        )
        context.insert(log)
        try context.save()

        let migrator = LegacyMigrator()
        migrator.migrate(context: context)

        let entries = try context.fetch(FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date)]))
        #expect(entries.count == 1)
        #expect(entries[0].primaryCity == "Atlanta")
        #expect(entries[0].sourceRaw == EntrySource.migratedRaw)
        #expect(entries[0].confidenceRaw == EntryConfidence.mediumRaw)
    }

    @Test func infersTravelDayOnCityTransition() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log1 = NightLog(date: noonUTC(2026, 1, 3), city: "Atlanta", state: "GA", country: "US",
                           latitude: 33.749, longitude: -84.388, capturedAt: Date(), source: .manual, status: .confirmed)
        let log2 = NightLog(date: noonUTC(2026, 1, 4), city: "Asheville", state: "NC", country: "US",
                           latitude: 35.595, longitude: -82.551, capturedAt: Date(), source: .manual, status: .confirmed)
        context.insert(log1)
        context.insert(log2)
        try context.save()

        let migrator = LegacyMigrator()
        migrator.migrate(context: context)

        let entries = try context.fetch(FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date)]))
        #expect(entries.count == 2)
        #expect(entries[0].isTravelDay == false)  // Atlanta — no previous city
        #expect(entries[1].isTravelDay == true)   // Asheville — city changed
        #expect(entries[1].citiesVisitedJSON.contains("Atlanta"))
        #expect(entries[1].citiesVisitedJSON.contains("Asheville"))
    }

    @Test func preservesColorIndexFromCityColor() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = NightLog(date: noonUTC(2026, 3, 1), city: "Atlanta", state: "GA", country: "US",
                          latitude: 33.749, longitude: -84.388, capturedAt: Date(), source: .manual, status: .confirmed)
        let color = CityColor(cityKey: "Atlanta|GA|US", colorIndex: 5)
        context.insert(log)
        context.insert(color)
        try context.save()

        let migrator = LegacyMigrator()
        migrator.migrate(context: context)

        let records = try context.fetch(FetchDescriptor<CityRecord>())
        #expect(records.count == 1)
        #expect(records[0].colorIndex == 5)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/LegacyMigratorTests -quiet`
Expected: FAIL — LegacyMigrator not defined

- [ ] **Step 3: Implement LegacyMigrator**

```swift
// Roam/Services/LegacyMigrator.swift
import Foundation
import SwiftData

struct LegacyMigrator {

    /// Known city coordinates for entries missing lat/lng
    static let cityCoordinates: [String: (lat: Double, lng: Double)] = [
        "Atlanta|GA|US":       (33.7490, -84.3880),
        "Asheville|NC|US":     (35.5951, -82.5515),
        "San Francisco|CA|US": (37.7749, -122.4194),
    ]

    static let migrationCompleteKey = "legacyMigrationComplete"

    static var isMigrationComplete: Bool {
        UserDefaults.standard.bool(forKey: migrationCompleteKey)
    }

    func migrate(context: ModelContext) {
        guard !Self.isMigrationComplete else { return }

        let logs = (try? context.fetch(
            FetchDescriptor<NightLog>(sortBy: [SortDescriptor(\.date)])
        )) ?? []

        guard !logs.isEmpty else {
            UserDefaults.standard.set(true, forKey: Self.migrationCompleteKey)
            return
        }

        // Load existing CityColor mappings
        let cityColors = (try? context.fetch(FetchDescriptor<CityColor>())) ?? []
        let colorMap = Dictionary(uniqueKeysWithValues: cityColors.map { ($0.cityKey, $0.colorIndex) })

        var previousCity: String? = nil
        var cityStats: [String: (count: Int, firstDate: Date, lastDate: Date, lat: Double, lng: Double)] = [:]

        for log in logs {
            let city = log.city ?? "Unknown"
            let state = log.state ?? ""
            let country = log.country ?? "US"
            let cityKey = CityDisplayFormatter.cityKey(city: city, state: state, country: country)

            // Resolve coordinates
            let lat: Double
            let lng: Double
            if let logLat = log.latitude, let logLng = log.longitude, logLat != 0 {
                lat = logLat
                lng = logLng
            } else {
                let pipeKey = "\(city)|\(state)|\(country)"
                let coords = Self.cityCoordinates[pipeKey]
                lat = coords?.lat ?? 0.0
                lng = coords?.lng ?? 0.0
            }

            // Determine travel day
            let isTravelDay = previousCity != nil && previousCity != cityKey

            // Build citiesVisitedJSON
            var cityObjects: [[String: String]] = [["city": city, "region": state, "country": country]]
            if isTravelDay, let prev = previousCity {
                let parts = prev.components(separatedBy: "|")
                if parts.count >= 3 {
                    cityObjects.insert(["city": parts[0], "region": parts[1], "country": parts[2]], at: 0)
                }
            }
            let citiesJSON = (try? JSONEncoder().encode(cityObjects))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

            // Create DailyEntry
            let entry = DailyEntry()
            entry.date = log.date
            entry.primaryCity = city
            entry.primaryRegion = state
            entry.primaryCountry = country
            entry.primaryLatitude = lat
            entry.primaryLongitude = lng
            entry.isTravelDay = isTravelDay
            entry.citiesVisitedJSON = citiesJSON
            entry.totalVisitHours = 24.0
            entry.sourceRaw = EntrySource.migratedRaw
            entry.confidenceRaw = EntryConfidence.mediumRaw
            entry.createdAt = log.capturedAt
            entry.updatedAt = Date()
            context.insert(entry)

            // Track city stats
            if var stats = cityStats[cityKey] {
                stats.count += 1
                stats.lastDate = log.date
                cityStats[cityKey] = stats
            } else {
                cityStats[cityKey] = (count: 1, firstDate: log.date, lastDate: log.date, lat: lat, lng: lng)
            }

            previousCity = cityKey
        }

        // Build CityRecords
        var maxColorIndex = colorMap.values.max() ?? -1
        for (cityKey, stats) in cityStats {
            let parts = cityKey.components(separatedBy: "|")
            let record = CityRecord()
            record.cityName = parts.count > 0 ? parts[0] : ""
            record.region = parts.count > 1 ? parts[1] : ""
            record.country = parts.count > 2 ? parts[2] : ""
            record.canonicalLatitude = stats.lat
            record.canonicalLongitude = stats.lng
            record.totalDays = stats.count
            record.firstVisitedDate = stats.firstDate
            record.lastVisitedDate = stats.lastDate

            // Preserve color from CityColor if it exists
            if let existingColor = colorMap[cityKey] {
                record.colorIndex = existingColor
            } else {
                maxColorIndex += 1
                record.colorIndex = maxColorIndex
            }

            record.updatedAt = Date()
            context.insert(record)
        }

        try? context.save()

        // Mark migration complete
        UserDefaults.standard.set(true, forKey: Self.migrationCompleteKey)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RoamTests/LegacyMigratorTests -quiet`
Expected: PASS

- [ ] **Step 5: Commit**

```
git add Roam/Services/LegacyMigrator.swift RoamTests/LegacyMigratorTests.swift
git commit -m "feat: add LegacyMigrator for NightLog to DailyEntry migration"
```

---

## Task 9: Wire Up App Entry Point

**Files:**
- Modify: `Roam/RoamApp.swift`
- Modify: `Roam/AppDelegate.swift`
- Modify: `Roam/ContentView.swift`
- Modify: `Roam/Models/UserSettings.swift`

This is the integration task — connect the pipeline to the app lifecycle.

- [ ] **Step 1: Update RoamApp.swift**

Replace the ModelContainer setup and service initialization:
- Create dual container config (local: RawVisit + PipelineEvent + UserSettings, synced: DailyEntry + CityRecord)
- Include legacy models (NightLog, CityColor, CaptureSource, LogStatus) so migration can read them
- Create PipelineLogger, LiveLocationProvider, VisitPipeline at app launch
- Run `LegacyMigrator.migrate()` if `!LegacyMigrator.isMigrationComplete`
- Start CLVisit monitoring
- Register lightweight BGTask: `BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.roamapp.dailyAggregation", using: nil) { task in ... pipeline.runCatchup() ... task.setTaskCompleted(success: true) }`. Schedule with `BGAppRefreshTaskRequest(identifier:)` earliest begin date ~3 AM.
- Prune old PipelineEvents on launch
- Wire foreground catch-up: on scene phase change to `.active`, call `pipeline.runCatchup()`
- Check `CLLocationManager.authorizationStatus` on foreground — if not `.authorizedAlways`, show permission prompt

- [ ] **Step 2: Update AppDelegate.swift**

- Keep push notification registration (for Supabase triggers)
- Change push handler to call `VisitPipeline.runCatchup()` instead of `BackgroundTaskService.performCapture()`
- Remove references to old services

- [ ] **Step 3: Update ContentView.swift**

- Replace all `NightLog` queries with `DailyEntry` queries
- Replace `UnresolvedBanner` with `ConfidenceBanner` (low-confidence entries)
- Remove foreground capture logic
- Replace unresolved resolution sheet with manual editing sheet
- Call `VisitPipeline.runCatchup()` on foreground instead of old capture flow
- Update deduplication to use new `DeduplicationService` for DailyEntry

- [ ] **Step 4: Update UserSettings.swift**

Remove capture schedule fields (`primaryCheckHour`, `primaryCheckMinute`, `retryCheckHour`, `retryCheckMinute`) — no longer needed with CLVisit monitoring.

- [ ] **Step 4b: Update Info.plist**

Replace BGTask identifiers: remove `com.roamapp.nightCapture` and `com.roamapp.nightCaptureRetry`, add `com.roamapp.dailyAggregation`. Update location usage description strings per spec §13.

- [ ] **Step 5: Build to verify**

Run: `xcodegen generate && xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

- [ ] **Step 6: Commit**

```
git commit -m "feat: wire up VisitPipeline to app lifecycle"
```

---

## Task 10: Adapt AnalyticsService

**Files:**
- Modify: `Roam/Services/AnalyticsService.swift`

- [ ] **Step 1: Rewrite AnalyticsService queries against DailyEntry**

Replace all NightLog references with DailyEntry. Key changes:
- `confirmedLogs(year:)` → `entries(year:)` — fetch DailyEntry excluding `"low"` confidence
- `allConfirmedLogs()` → `allEntries()` — fetch all DailyEntry
- All city key generation uses `entry.cityKey` (the computed property on DailyEntry)
- Preserve all method signatures and return types so views need minimal changes
- `StreakInfo`, `HomeAwayRatio`, `MonthlyBreakdown` structs remain the same

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

- [ ] **Step 3: Commit**

```
git commit -m "refactor: adapt AnalyticsService for DailyEntry"
```

---

## Task 11: Adapt View Layer — Dashboard + Timeline

**Files:**
- Modify: `Roam/Views/Dashboard/DashboardView.swift`
- Modify: `Roam/Views/Dashboard/CurrentCityBanner.swift`
- Modify: `Roam/Views/Dashboard/QuickStatsRow.swift`
- Modify: `Roam/Views/Dashboard/TopCitiesList.swift`
- Modify: `Roam/Views/Dashboard/YearSummaryBar.swift`
- Modify: `Roam/Views/Timeline/TimelineView.swift`
- Modify: `Roam/Views/Timeline/CalendarGridView.swift`
- Modify: `Roam/Views/Timeline/DayCell.swift`
- Modify: `Roam/Views/Timeline/DayDetailSheet.swift`
- Modify: `Roam/Views/Timeline/MiniMonthGridView.swift`
- Modify: `Roam/Views/Timeline/YearDotGridView.swift`
- Create: `Roam/Views/Shared/ConfidenceBanner.swift`
- Modify: `Roam/Views/Insights/InsightsView.swift`

- [ ] **Step 1: Create ConfidenceBanner**

Replaces UnresolvedBanner. Shows when recent entries have `low` confidence. Tapping opens list for user to resolve.

- [ ] **Step 2: Update Dashboard views**

Swap `@Query` for `NightLog` to `DailyEntry`. Use `CityRecord` for color lookups via `colorIndex` instead of separate `CityColor` queries.

- [ ] **Step 3: Update Timeline views**

- Swap NightLog queries for DailyEntry
- Add travel day badge to DayCell (small icon when `isTravelDay == true`)
- Add confidence indicator to DayCell (subtle dimming for `medium`, clear indicator for `low`)
- Update DayDetailSheet to show travel info (cities visited list) and confidence source
- Add manual edit button for `medium`/`low` confidence entries

- [ ] **Step 4: Update Insights views**

These views consume AnalyticsService methods, which have the same signatures. Minimal changes needed — just ensure the data source is correct.

- [ ] **Step 5: Build and visually verify in simulator**

Run: `xcodegen generate && xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

- [ ] **Step 6: Commit**

```
git commit -m "feat: update views for DailyEntry with confidence and travel day display"
```

---

## Task 12: Adapt Remaining Services

**Files:**
- Modify: `Roam/Services/CityDisplayFormatter.swift`
- Modify: `Roam/Services/DeduplicationService.swift`
- Modify: `Roam/Services/DataExportService.swift`
- Modify: `Roam/Services/DataImportService.swift`
- Modify: `Roam/Views/Settings/SettingsView.swift`
- Modify: `Roam/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Adapt CityDisplayFormatter**

Ensure it works with DailyEntry fields. The `cityKey()` function uses pipe-delimited format — verify it works with `primaryCity`/`primaryRegion`/`primaryCountry` field names.

- [ ] **Step 2: Adapt DeduplicationService**

Rewrite for DailyEntry:
- Deduplicate by noon-UTC date
- Prefer most recently updated entry (no LogStatus priority)
- Remove CityColor deduplication (replaced by CityRecord)
- Add CityRecord deduplication (by cityName + region + country)

- [ ] **Step 3: Adapt DataExportService / DataImportService**

Export/import DailyEntry + CityRecord instead of NightLog.

- [ ] **Step 4: Update SettingsView**

- Remove capture schedule settings
- Add debug screen entry point (hidden behind triple-tap gesture or toggle)

- [ ] **Step 5: Update OnboardingView**

Update copy: "checks your location once nightly" → "passively monitors your location" (or similar wording that reflects CLVisit monitoring).

- [ ] **Step 6: Build to verify**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

- [ ] **Step 7: Commit**

```
git commit -m "refactor: adapt services and settings for new pipeline"
```

---

## Task 13: Debug Screen

**Files:**
- Create: `Roam/Views/Settings/DebugScreen.swift`
- Create: `Roam/Views/Settings/DebugLogViewer.swift`
- Create: `Roam/Views/Settings/DebugScenarios.swift`
- Create: `Roam/Views/Settings/DebugPipelineInspector.swift`

- [ ] **Step 1: Create DebugScenarios with preset cities and scenarios**

Preset cities (Portland, SF, NYC, LA, Denver, Chicago, Tokyo, London, Sydney) with coordinates. Preset scenarios (Normal Week, Stationary Week, Trip with Layover, Red-Eye, Day Trip, Data Gap, Date Line Crossing) as arrays of VisitData.

- [ ] **Step 2: Create DebugScreen**

Main debug view with sections:
- Quick Inject (city buttons)
- Scenario Player (scenario list with "Play" buttons)
- Navigation to Pipeline Inspector and Log Viewer
- Data Controls (wipe all, wipe local, re-aggregate, export JSON)
- Provider Toggle (live/mock)

- [ ] **Step 3: Create DebugPipelineInspector**

Lists of RawVisits, DailyEntries, CityRecords with counts and status indicators.

- [ ] **Step 4: Create DebugLogViewer**

Chronological PipelineEvent feed. Category filter toggles. App state color indicators. Expandable metadata rows. JSON export button.

- [ ] **Step 5: Build and visually verify**

Run: `xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

- [ ] **Step 6: Commit**

```
git commit -m "feat: add debug screen with scenarios, inspector, and log viewer"
```

---

## Task 14: Remove Legacy Code

**Files to delete:** See "Files to Delete" in the file structure section above.

- [ ] **Step 1: Delete old service files**

Remove: `BackgroundTaskService.swift`, `LocationCaptureService.swift`, `SignificantLocationService.swift`, `CaptureResultSaver.swift`, `BackfillService.swift`, `UnresolvedFilter.swift`, `HeartbeatService.swift`, `DeviceTokenService.swift`, `SupabaseClient.swift`, `SupabaseConfig.swift`, `DateNormalization.swift`, `CityColorService.swift`

- [ ] **Step 2: Verify old model files are retained**

Keep: `NightLog.swift`, `CityColor.swift`, `CaptureSource.swift`, `LogStatus.swift` — NightLog references CaptureSource and LogStatus, and all remain in the schema for migration compatibility.

- [ ] **Step 3: Delete old view files**

Remove: `UnresolvedBanner.swift`, `UnresolvedResolutionView.swift`

- [ ] **Step 4: Delete old test files**

Remove: `BackfillServiceTests.swift`, `CaptureResultSaverTests.swift`, `CityColorServiceTests.swift`, `DateNormalizationTests.swift`, `DeduplicationServiceTests.swift`, `LocationValidationTests.swift`, `SignificantLocationServiceTests.swift`, `UnresolvedFilterTests.swift`

- [ ] **Step 5: Build to verify nothing is broken**

Run: `xcodegen generate && xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

- [ ] **Step 6: Run remaining tests**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`

- [ ] **Step 7: Commit**

```
git commit -m "refactor: remove legacy capture system and unused services"
```

---

## Task 15: Final Integration Test + Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full test suite**

Run: `xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
Expected: All tests pass

- [ ] **Step 2: Run the app in simulator and verify**

- Launch app, verify onboarding works
- Verify dashboard loads (may be empty if no migrated data in simulator)
- Verify timeline loads
- Open debug screen from settings
- Inject a "Normal Week" scenario via scenario player
- Verify DailyEntries appear in timeline
- Inject a "Stationary Week" scenario
- Verify propagated entries appear with medium confidence
- Inject a "Trip with Layover" scenario
- Verify travel day detection, Denver layover filtered
- Check Pipeline Inspector shows correct data
- Check Log Viewer shows event sequence

- [ ] **Step 3: Update CLAUDE.md**

Update project structure, key concepts, and model descriptions to reflect the new architecture:
- Replace NightLog/CityColor references with DailyEntry/CityRecord/RawVisit
- Update Key Concepts section with CLVisit pipeline, confidence levels, propagation
- Update Working with SwiftData Predicates with new enum patterns
- Update Testing Strategy with new test files
- Keep build/test commands the same

- [ ] **Step 4: Commit**

```
git commit -m "docs: update CLAUDE.md for new location tracking architecture"
```
