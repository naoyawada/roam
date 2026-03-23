import SwiftUI

private struct ColorThemeKey: EnvironmentKey {
    static let defaultValue: ColorTheme = .earthy
}

extension EnvironmentValues {
    var colorTheme: ColorTheme {
        get { self[ColorThemeKey.self] }
        set { self[ColorThemeKey.self] = newValue }
    }
}
