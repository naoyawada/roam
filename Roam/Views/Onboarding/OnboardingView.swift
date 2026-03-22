import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @ObservedObject var locationService: LocationCaptureService
    @Binding var hasCompletedOnboarding: Bool

    @State private var step: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case locationExplanation
        case requestingPermission
        case complete
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            switch step {
            case .welcome:
                welcomeView
            case .locationExplanation:
                locationExplanationView
            case .requestingPermission:
                requestingView
            case .complete:
                completeView
            }

            Spacer()
        }
        .padding(32)
        .grainBackground()
        .tint(RoamTheme.accent)
        .onChange(of: locationService.authorizationStatus) { oldStatus, newStatus in
            guard oldStatus != newStatus else { return }
            switch newStatus {
            case .authorizedWhenInUse:
                // Request Always upgrade — iOS grants it provisionally in the background.
                // Don't wait for .authorizedAlways; it won't arrive during onboarding.
                locationService.requestAlwaysAuthorization()
                step = .complete
            case .authorizedAlways:
                step = .complete
            case .denied, .restricted:
                step = .complete
            default:
                break
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Welcome to Roam")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Track which city you sleep in each night, automatically.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Get Started") {
                step = .locationExplanation
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top)
        }
    }

    private var locationExplanationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Location Access")
                .font(.title2)
                .fontWeight(.bold)
            Text("Roam passively monitors your location to automatically track which cities you visit. This requires \"Always\" location access so it can detect city changes in the background.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Your location data stays on your device and in your private iCloud account. It is never shared.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Allow Location Access") {
                let current = locationService.authorizationStatus
                if current == .authorizedWhenInUse || current == .authorizedAlways || current == .denied || current == .restricted {
                    // Permission already determined — skip the spinner
                    if current == .authorizedWhenInUse {
                        locationService.requestAlwaysAuthorization()
                    }
                    step = .complete
                } else {
                    step = .requestingPermission
                    locationService.requestWhenInUseAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip for Now") {
                step = .complete
            }
            .foregroundStyle(.secondary)
        }
    }

    private var requestingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Waiting for permission...")
                .foregroundStyle(.secondary)
        }
    }

    private var completeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("You're all set!")
                .font(.title2)
                .fontWeight(.bold)

            let hasAlways = locationService.authorizationStatus == .authorizedAlways
            Text(hasAlways
                 ? "Roam will automatically log your city each night."
                 : "Roam will log your city when you open the app. Enable \"Always\" in Settings for automatic tracking.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Start Using Roam") {
                hasCompletedOnboarding = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
