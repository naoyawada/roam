import SwiftUI

enum ColorPalette {
    /// Color for cities ranked 6+
    static let otherColor = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.9, alpha: 0.12)
            : UIColor(red: 0.149, green: 0.145, blue: 0.118, alpha: 0.1)
    })

    /// Unresolved: uses theme tokens
    static let unresolvedColor = RoamTheme.unresolvedFill

    /// Max number of individually colored cities
    static let maxColoredCities = 5

    /// Theme-aware color lookup
    static func color(for index: Int, theme: ColorTheme) -> Color {
        if index < theme.colors.count {
            return theme.colors[index]
        }
        return otherColor
    }
}
