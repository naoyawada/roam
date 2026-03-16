import SwiftUI

enum RoamTheme {
    // MARK: - Core Colors
    static let background = Color(red: 0.969, green: 0.969, blue: 0.957)       // #f7f7f4
    static let textPrimary = Color(red: 0.149, green: 0.145, blue: 0.118)      // #26251e
    static let textSecondary = Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.45)
    static let textTertiary = Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.3)

    // MARK: - Accent
    static let accent = Color(red: 0.478, green: 0.361, blue: 0.267)           // #7A5C44
    static let accentLight = Color(red: 0.478, green: 0.361, blue: 0.267).opacity(0.12)
    static let accentBorder = Color(red: 0.478, green: 0.361, blue: 0.267).opacity(0.2)

    // MARK: - Surfaces
    static let border = Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.08)
    static let borderStrong = Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.12)
    static let surfaceSubtle = Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.03)
    static let bannerBackground = Color(red: 0.478, green: 0.361, blue: 0.267) // leather solid

    // MARK: - Unresolved
    static let unresolvedFill = Color(red: 0.478, green: 0.361, blue: 0.267).opacity(0.08)
    static let unresolvedBorder = Color(red: 0.478, green: 0.361, blue: 0.267).opacity(0.4)

    // MARK: - Spacing
    static let cornerRadius: CGFloat = 14
    static let cornerRadiusSmall: CGFloat = 10
    static let cardPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 20

    // MARK: - Year Bar
    static let yearBarHeight: CGFloat = 8
    static let yearBarCornerRadius: CGFloat = 99

    // MARK: - Typography helpers
    static let headingTracking: CGFloat = -0.02
}
