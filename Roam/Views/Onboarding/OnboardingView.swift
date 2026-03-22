import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @ObservedObject var locationService: OnboardingLocationManager
    @Binding var hasCompletedOnboarding: Bool

    @State private var step: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case locationExplanation
        case requestingPermission
        case needsSettingsUpgrade
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
            case .needsSettingsUpgrade:
                settingsUpgradeView
            case .complete:
                completeView
            }

            Spacer()
        }
        .padding(32)
        .grainBackground()
        .tint(RoamTheme.accent)
        .onChange(of: locationService.authorizationStatus) { oldStatus, newStatus in
            guard oldStatus != newStatus, step == .requestingPermission else { return }
            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // Got some level of authorization — proceed to complete.
                // ContentView will prompt for Always upgrade if needed.
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
                    // Permission already determined — proceed to complete.
                    // ContentView will prompt for Always upgrade if only When In Use.
                    step = .complete
                } else {
                    // Not determined — request Always directly.
                    // iOS will show: "Allow While Using", "Allow Once", "Don't Allow"
                    step = .requestingPermission
                    locationService.requestAlwaysAuthorization()
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

    private var settingsUpgradeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("One More Step")
                .font(.title2)
                .fontWeight(.bold)
            Text("Roam needs \"Always\" location access to track your city in the background. Please open Settings and change location access to \"Always\".")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Continue Without Background Tracking") {
                step = .complete
            }
            .foregroundStyle(.secondary)
            .font(.callout)
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
