import SwiftUI

enum RoamTheme {

    // MARK: - Adaptive Color Helper

    private static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

    // MARK: - Core Colors

    static let background = adaptive(
        light: Color(red: 0.969, green: 0.969, blue: 0.957),   // #f7f7f4
        dark: Color(red: 0.098, green: 0.094, blue: 0.086)     // #191816
    )

    static let textPrimary = adaptive(
        light: Color(red: 0.149, green: 0.145, blue: 0.118),   // #26251e
        dark: Color(red: 0.910, green: 0.902, blue: 0.878)     // #e8e6e0
    )

    static let textSecondary = adaptive(
        light: Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.45),
        dark: Color(red: 0.910, green: 0.902, blue: 0.878).opacity(0.55)
    )

    static let textTertiary = adaptive(
        light: Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.3),
        dark: Color(red: 0.910, green: 0.902, blue: 0.878).opacity(0.35)
    )

    // MARK: - Accent

    static let accent = adaptive(
        light: Color(red: 0.478, green: 0.361, blue: 0.267),   // #7A5C44
        dark: Color(red: 0.698, green: 0.565, blue: 0.459)     // #B29075
    )

    static let accentLight = adaptive(
        light: Color(red: 0.478, green: 0.361, blue: 0.267).opacity(0.12),
        dark: Color(red: 0.698, green: 0.565, blue: 0.459).opacity(0.15)
    )

    static let accentBorder = adaptive(
        light: Color(red: 0.478, green: 0.361, blue: 0.267).opacity(0.2),
        dark: Color(red: 0.698, green: 0.565, blue: 0.459).opacity(0.3)
    )

    // MARK: - Surfaces

    static let border = adaptive(
        light: Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.08),
        dark: Color(red: 0.910, green: 0.902, blue: 0.878).opacity(0.1)
    )

    static let borderStrong = adaptive(
        light: Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.12),
        dark: Color(red: 0.910, green: 0.902, blue: 0.878).opacity(0.15)
    )

    static let borderWarm = adaptive(
        light: Color(red: 0.843, green: 0.808, blue: 0.780),   // #D7CEC7
        dark: Color(red: 0.353, green: 0.337, blue: 0.318)     // warm gray for dark
    )

    static let surfaceSubtle = adaptive(
        light: Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.03),
        dark: Color(red: 0.910, green: 0.902, blue: 0.878).opacity(0.05)
    )

    static let bannerBackground = adaptive(
        light: Color(red: 0.478, green: 0.361, blue: 0.267),   // leather solid
        dark: Color(red: 0.353, green: 0.267, blue: 0.196)     // darker leather #5A4432
    )

    // MARK: - Unresolved

    static let unresolvedFill = adaptive(
        light: Color(red: 0.478, green: 0.361, blue: 0.267).opacity(0.08),
        dark: Color(red: 0.698, green: 0.565, blue: 0.459).opacity(0.12)
    )

    static let unresolvedBorder = adaptive(
        light: Color(red: 0.478, green: 0.361, blue: 0.267).opacity(0.4),
        dark: Color(red: 0.698, green: 0.565, blue: 0.459).opacity(0.4)
    )

    // MARK: - Grain

    static let grainColor = adaptive(
        light: Color(red: 0.149, green: 0.145, blue: 0.118),
        dark: Color(red: 0.910, green: 0.902, blue: 0.878)
    )

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
