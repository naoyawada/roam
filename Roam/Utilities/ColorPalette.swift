import SwiftUI

enum ColorPalette {
    /// Top 5 city colors — earthy, warm, distinguishable
    static let colors: [Color] = [
        Color(red: 0.478, green: 0.361, blue: 0.267),  // leather  #7A5C44
        Color(red: 0.604, green: 0.494, blue: 0.392),  // tan      #9A7E64
        Color(red: 0.369, green: 0.490, blue: 0.431),  // sage     #5E7D6E
        Color(red: 0.690, green: 0.604, blue: 0.525),  // sand     #B09A86
        Color(red: 0.545, green: 0.420, blue: 0.353),  // umber    #8B6B5A
    ]

    /// Color for cities ranked 6+
    static let otherColor = Color(red: 0.149, green: 0.145, blue: 0.118).opacity(0.1)

    /// Unresolved: uses theme tokens
    static let unresolvedColor = RoamTheme.unresolvedFill

    /// Max number of individually colored cities
    static let maxColoredCities = 5

    static func color(for index: Int) -> Color {
        if index < colors.count {
            return colors[index]
        }
        return otherColor
    }
}
