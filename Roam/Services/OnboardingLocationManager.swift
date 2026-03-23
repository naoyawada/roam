import CoreLocation
import Foundation

/// Lightweight location manager used exclusively during onboarding to
/// request authorization and reflect the current authorization status.
@MainActor
final class OnboardingLocationManager: NSObject, ObservableObject {

    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus

    override init() {
        authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }
}

extension OnboardingLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.authorizationStatus = status
        }
    }
}
