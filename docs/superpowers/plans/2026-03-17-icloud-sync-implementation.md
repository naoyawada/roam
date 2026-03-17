# iCloud Sync Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up iCloud sync via CloudKit for NightLog and CityColor models, with a user-controllable toggle backed by UserDefaults.

**Architecture:** Two-configuration ModelContainer split — a "cloud" config for NightLog/CityColor (CloudKit-backed or local based on UserDefaults preference) and a "local" config for UserSettings (always local). The sync toggle in Settings writes to UserDefaults and requires an app restart to take effect.

**Tech Stack:** SwiftData, CloudKit, SwiftUI, UserDefaults

**Spec:** `docs/superpowers/specs/2026-03-17-icloud-sync-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `Roam/Roam.entitlements` | Modify | Add CloudKit + iCloud container keys |
| `project.yml` | Modify | Add iCloud capability to Roam target |
| `Roam/Models/UserSettings.swift` | Modify | Remove `iCloudSyncEnabled` property |
| `Roam/RoamApp.swift` | Modify | Two-config ModelContainer based on UserDefaults |
| `Roam/Views/Settings/SettingsView.swift` | Modify | Toggle writes UserDefaults, shows restart alert |
| `RoamTests/AnalyticsServiceTests.swift` | Modify | Two-config test container setup |

---

## Chunk 1: Entitlements and Project Config

### Task 1: Add CloudKit entitlements

**Files:**
- Modify: `Roam/Roam.entitlements`

- [ ] **Step 1: Update entitlements file**

Replace the empty `<dict/>` in `Roam/Roam.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.icloud-containers</key>
    <array>
        <string>iCloud.com.naoyawada.roam</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Commit**

```bash
git add Roam/Roam.entitlements
git commit -m "feat: add CloudKit entitlements for iCloud sync"
```

### Task 2: Add iCloud capability to project.yml and regenerate

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Add entitlements build setting and iCloud capability to Roam target**

In `project.yml`, under `targets.Roam.settings.base`, add:

```yaml
CODE_SIGN_ENTITLEMENTS: Roam/Roam.entitlements
```

And under `targets.Roam`, add the `attributes` block:

```yaml
    attributes:
      SystemCapabilities:
        com.apple.iCloud:
          enabled: 1
```

The full Roam target should look like:

```yaml
  Roam:
    type: application
    platform: iOS
    sources:
      - path: Roam
    configFiles:
      Debug: Config/BuildNumber.xcconfig
      Release: Config/BuildNumber.xcconfig
    settings:
      base:
        INFOPLIST_FILE: Roam/Info.plist
        GENERATE_INFOPLIST_FILE: "YES"
        PRODUCT_BUNDLE_IDENTIFIER: com.naoyawada.roam
        MARKETING_VERSION_BASE: "1.0"
        CODE_SIGN_ENTITLEMENTS: Roam/Roam.entitlements
    attributes:
      SystemCapabilities:
        com.apple.iCloud:
          enabled: 1
```

Note: `CODE_SIGN_ENTITLEMENTS` is required for Xcode to apply the entitlements from Task 1. Without it, the entitlements file is ignored.

- [ ] **Step 2: Regenerate Xcode project**

```bash
xcodegen generate
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add project.yml Roam.xcodeproj
git commit -m "feat: add iCloud + CloudKit capability to project config"
```

---

## Chunk 2: Wire Up iCloud Sync (Atomic Change)

All three files must be changed together to keep the build green. The model removes `iCloudSyncEnabled`, RoamApp adds the two-config container, and SettingsView switches the toggle to UserDefaults.

### Task 3: Update UserSettings, RoamApp, and SettingsView atomically

**Files:**
- Modify: `Roam/Models/UserSettings.swift`
- Modify: `Roam/RoamApp.swift`
- Modify: `Roam/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Remove iCloudSyncEnabled from UserSettings**

In `Roam/Models/UserSettings.swift`, remove:
- The `var iCloudSyncEnabled: Bool = true` stored property (line 12)
- The `iCloudSyncEnabled: Bool = true` parameter from `init` (line 22)
- The `self.iCloudSyncEnabled = iCloudSyncEnabled` assignment in `init` (line 31)

The file should become:

```swift
import Foundation
import SwiftData

@Model
final class UserSettings {
    var homeCityKey: String?
    var primaryCheckHour: Int = 2
    var primaryCheckMinute: Int = 0
    var retryCheckHour: Int = 5
    var retryCheckMinute: Int = 0
    var hasCompletedOnboarding: Bool = false
    var notificationsEnabled: Bool = true

    init(
        homeCityKey: String? = nil,
        primaryCheckHour: Int = 2,
        primaryCheckMinute: Int = 0,
        retryCheckHour: Int = 5,
        retryCheckMinute: Int = 0,
        hasCompletedOnboarding: Bool = false,
        notificationsEnabled: Bool = true
    ) {
        self.homeCityKey = homeCityKey
        self.primaryCheckHour = primaryCheckHour
        self.primaryCheckMinute = primaryCheckMinute
        self.retryCheckHour = retryCheckHour
        self.retryCheckMinute = retryCheckMinute
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationsEnabled = notificationsEnabled
    }
}
```

- [ ] **Step 2: Rewrite RoamApp.swift with two-config ModelContainer**

Replace the contents of `Roam/RoamApp.swift` with:

```swift
import SwiftUI
import SwiftData

@main
struct RoamApp: App {
    @Environment(\.scenePhase) private var scenePhase
    let modelContainer: ModelContainer
    let significantLocationService: SignificantLocationService

    init() {
        let iCloudSyncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true

        do {
            // "cloud" config: NightLog + CityColor
            // Uses the same store name regardless of toggle so data is preserved when switching.
            let cloudConfig = ModelConfiguration(
                "cloud",
                schema: Schema([NightLog.self, CityColor.self]),
                cloudKitDatabase: iCloudSyncEnabled ? .automatic : .none
            )

            // "local" config: UserSettings — always local, never syncs
            let localConfig = ModelConfiguration(
                "local",
                schema: Schema([UserSettings.self]),
                cloudKitDatabase: .none
            )

            modelContainer = try ModelContainer(
                for: NightLog.self, CityColor.self, UserSettings.self,
                configurations: cloudConfig, localConfig
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        significantLocationService = SignificantLocationService(modelContainer: modelContainer)

        BackgroundTaskService.register(modelContainer: modelContainer)
        BackgroundTaskService.schedulePrimaryCapture()
        significantLocationService.startMonitoring()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                BackgroundTaskService.schedulePrimaryCapture()
            }
        }
    }
}
```

- [ ] **Step 3: Update SettingsView iCloud toggle**

In `Roam/Views/Settings/SettingsView.swift`:

1. Add these two properties after the existing `@State` declarations (after line 17):

```swift
@AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true
@State private var showSyncRestartAlert = false
```

2. Replace the old iCloud toggle binding (lines 97-100):

Old code to find and replace:
```swift
Toggle("iCloud Sync", isOn: Binding(
    get: { settings.iCloudSyncEnabled },
    set: { settings.iCloudSyncEnabled = $0 }
))
```

New code:
```swift
Toggle("iCloud Sync", isOn: $iCloudSyncEnabled)
    .onChange(of: iCloudSyncEnabled) { oldValue, newValue in
        guard oldValue != newValue else { return }
        showSyncRestartAlert = true
    }
```

Note: The `guard oldValue != newValue` prevents a spurious alert on initial view load if `@AppStorage` triggers `onChange` during view setup.

3. Add the alert modifier after the `.sheet` modifier (after the closing `}` on line 124):

```swift
.alert("Restart Required", isPresented: $showSyncRestartAlert) {
    Button("OK", role: .cancel) { }
} message: {
    Text("iCloud sync change takes effect next time you open the app.")
}
```

- [ ] **Step 4: Build to verify everything compiles**

```bash
xcodebuild build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run all tests**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add Roam/Models/UserSettings.swift Roam/RoamApp.swift Roam/Views/Settings/SettingsView.swift
git commit -m "feat: wire up iCloud sync with two-config ModelContainer and UserDefaults toggle"
```

---

## Chunk 3: Test Updates

### Task 4: Update AnalyticsServiceTests to use two-config container

**Files:**
- Modify: `RoamTests/AnalyticsServiceTests.swift`

`AnalyticsServiceTests` includes `UserSettings.self` in its schema and needs to match the production two-config architecture. `CaptureResultSaverTests` only uses `NightLog` and `CityColor` (no `UserSettings`) so it does not need changes.

- [ ] **Step 1: Update AnalyticsServiceTests.setUp()**

In `RoamTests/AnalyticsServiceTests.swift`, replace the existing container setup:

Old code to find and replace:
```swift
let schema = Schema([NightLog.self, CityColor.self, UserSettings.self])
let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
container = try ModelContainer(for: schema, configurations: [config])
```

New code:
```swift
let cloudConfig = ModelConfiguration(
    "cloud",
    schema: Schema([NightLog.self, CityColor.self]),
    isStoredInMemoryOnly: true,
    cloudKitDatabase: .none
)
let localConfig = ModelConfiguration(
    "local",
    schema: Schema([UserSettings.self]),
    isStoredInMemoryOnly: true,
    cloudKitDatabase: .none
)
container = try ModelContainer(
    for: NightLog.self, CityColor.self, UserSettings.self,
    configurations: cloudConfig, localConfig
)
```

- [ ] **Step 2: Run all tests**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add RoamTests/AnalyticsServiceTests.swift
git commit -m "test: update AnalyticsServiceTests to two-config container architecture"
```

---

## Chunk 4: Final Verification

### Task 5: Full clean build and test verification

- [ ] **Step 1: Regenerate Xcode project**

```bash
xcodegen generate
```

- [ ] **Step 2: Clean build**

```bash
xcodebuild clean build -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run all tests**

```bash
xcodebuild test -scheme Roam -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

Expected: All tests pass.

- [ ] **Step 4: Commit if xcodegen produced changes**

```bash
git add project.yml Roam.xcodeproj
git diff --cached --quiet || git commit -m "chore: regenerate Xcode project with iCloud sync support"
```

---

## Manual QA Checklist (Post-Implementation)

These steps require a physical device and Apple Developer account:

1. Register `iCloud.com.naoyawada.roam` container in Apple Developer portal
2. Run a development build on a device to push the CloudKit schema
3. In CloudKit Dashboard, verify the schema was auto-generated (NightLog, CityColor record types)
4. Promote the schema to production before App Store release
5. Create a NightLog on Device A, verify it appears on Device B
6. Toggle iCloud sync off in Settings, restart app, verify data is still present locally
7. Toggle iCloud sync back on, restart app, verify sync resumes
