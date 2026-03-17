import CoreLocation
import os
import SwiftData

@MainActor
final class SignificantLocationService: NSObject, ObservableObject {

    private let locationManager = CLLocationManager()
    private let modelContainer: ModelContainer
    private nonisolated static let logger = Logger(subsystem: "com.naoyawada.roam", category: "SignificantLocation")

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        locationManager.delegate = self
    }

    func startMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            Self.logger.warning("Significant location monitoring not available")
            return
        }
        locationManager.startMonitoringSignificantLocationChanges()
        Self.logger.info("Significant location monitoring started")
    }

    /// Check if the given date falls within the capture window (12:00 AM - 5:59 AM local).
    nonisolated static func isInCaptureWindow(date: Date, timeZone: TimeZone = .current) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let hour = cal.component(.hour, from: date)
        return hour < 6
    }

    private func handleLocationUpdate() async {
        let now = Date.now

        guard Self.isInCaptureWindow(date: now) else {
            Self.logger.info("Outside capture window, ignoring")
            return
        }

        let context = modelContainer.mainContext
        let nightDate = DateNormalization.normalizedNightDate(from: now)

        let existing = try? context.fetch(
            FetchDescriptor<NightLog>(predicate: #Predicate { $0.date == nightDate })
        ).first

        let unresolvedRaw = LogStatus.unresolvedRaw
        if let existing, existing.statusRaw != unresolvedRaw {
            Self.logger.info("Confirmed entry already exists for \(nightDate), skipping")
            return
        }

        guard locationManager.authorizationStatus == .authorizedAlways else {
            Self.logger.error("Location not authorizedAlways, skipping capture")
            return
        }

        Self.logger.info("No confirmed entry for tonight, attempting capture")
        let service = LocationCaptureService()
        guard let result = await service.captureNight() else {
            Self.logger.error("Significant location capture failed")
            return
        }

        CaptureResultSaver.save(result: result, context: context)
        Self.logger.info("Significant location capture succeeded: \(result.city)")
    }
}

extension SignificantLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            await handleLocationUpdate()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        SignificantLocationService.logger.error("Significant location error: \(error.localizedDescription)")
    }
}
