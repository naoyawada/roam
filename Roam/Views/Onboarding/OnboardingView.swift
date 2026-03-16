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
            Text("Roam checks your location once at night (around 2 AM) to determine which city you're in. This requires \"Always\" location access so it can work while you sleep.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Your location data stays on your device and in your private iCloud account. It is never shared.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Allow Location Access") {
                step = .requestingPermission
                locationService.requestWhenInUseAuthorization()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip for Now") {
                step = .complete
            }
            .foregroundStyle(.secondary)
        }
        .onChange(of: locationService.authorizationStatus) { oldStatus, newStatus in
            guard oldStatus != newStatus else { return }
            switch newStatus {
            case .authorizedWhenInUse:
                // Got "While Using" — now request upgrade to "Always"
                locationService.requestAlwaysAuthorization()
            case .authorizedAlways:
                // Got "Always" — done
                step = .complete
            case .denied, .restricted:
                // User denied — move on
                step = .complete
            default:
                break
            }
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
