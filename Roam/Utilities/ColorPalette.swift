import SwiftUI

enum ColorPalette {
    static let colors: [Color] = [
        Color(red: 0.39, green: 0.40, blue: 0.95),  // indigo
        Color(red: 0.55, green: 0.36, blue: 0.96),  // violet
        Color(red: 0.66, green: 0.33, blue: 0.97),  // purple
        Color(red: 0.75, green: 0.52, blue: 0.99),  // light purple
        Color(red: 0.24, green: 0.64, blue: 0.96),  // blue
        Color(red: 0.20, green: 0.78, blue: 0.82),  // teal
        Color(red: 0.30, green: 0.80, blue: 0.47),  // green
        Color(red: 0.96, green: 0.68, blue: 0.20),  // amber
        Color(red: 0.95, green: 0.45, blue: 0.32),  // coral
        Color(red: 0.92, green: 0.30, blue: 0.48),  // pink
    ]

    static let unresolvedColor = Color.yellow.opacity(0.3)

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
}
