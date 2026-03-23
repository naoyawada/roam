import SwiftUI

enum ColorTheme: String, CaseIterable, Identifiable {
    case earthy
    case cool
    case vibrant
    case sunset
    case moody
    case botanical

    var id: String { rawValue }

    static let `default`: ColorTheme = .earthy

    var displayName: String {
        switch self {
        case .earthy:    "Earthy"
        case .cool:      "Cool"
        case .vibrant:   "Vibrant"
        case .sunset:    "Sunset"
        case .moody:     "Moody"
        case .botanical: "Botanical"
        }
    }

    var colors: [Color] {
        switch self {
        case .earthy:
            [
                Color(red: 0.478, green: 0.361, blue: 0.267),  // leather    #7A5C44
                Color(red: 0.604, green: 0.494, blue: 0.392),  // tan        #9A7E64
                Color(red: 0.369, green: 0.490, blue: 0.431),  // sage       #5E7D6E
                Color(red: 0.690, green: 0.604, blue: 0.525),  // sand       #B09A86
                Color(red: 0.545, green: 0.420, blue: 0.353),  // umber      #8B6B5A
            ]
        case .cool:
            [
                Color(red: 0.420, green: 0.498, blue: 0.557),  // fog        #6B7F8E
                Color(red: 0.561, green: 0.639, blue: 0.678),  // overcast   #8FA3AD
                Color(red: 0.553, green: 0.541, blue: 0.612),  // dusk       #8D8A9C
                Color(red: 0.478, green: 0.573, blue: 0.573),  // lichen     #7A9292
                Color(red: 0.627, green: 0.651, blue: 0.667),  // pewter     #A0A6AA
            ]
        case .vibrant:
            [
                Color(red: 0.769, green: 0.588, blue: 0.227),  // spicy mustard #C4963A
                Color(red: 0.851, green: 0.357, blue: 0.357),  // poppy        #D95B5B
                Color(red: 0.180, green: 0.545, blue: 0.545),  // teal         #2E8B8B
                Color(red: 0.482, green: 0.408, blue: 0.682),  // iris         #7B68AE
                Color(red: 0.910, green: 0.545, blue: 0.353),  // tangerine    #E88B5A
            ]
        case .sunset:
            [
                Color(red: 0.545, green: 0.227, blue: 0.290),  // mulberry    #8B3A4A
                Color(red: 0.831, green: 0.380, blue: 0.227),  // ember       #D4613A
                Color(red: 0.910, green: 0.596, blue: 0.353),  // marigold    #E8985A
                Color(red: 0.769, green: 0.478, blue: 0.420),  // terracotta  #C47A6B
                Color(red: 0.941, green: 0.722, blue: 0.439),  // honey       #F0B870
            ]
        case .moody:
            [
                Color(red: 0.290, green: 0.333, blue: 0.408),  // charcoal    #4A5568
                Color(red: 0.420, green: 0.357, blue: 0.431),  // plum ash    #6B5B6E
                Color(red: 0.361, green: 0.420, blue: 0.420),  // smoke       #5C6B6B
                Color(red: 0.478, green: 0.420, blue: 0.376),  // espresso    #7A6B60
                Color(red: 0.431, green: 0.482, blue: 0.510),  // slate       #6E7B82
            ]
        case .botanical:
            [
                Color(red: 0.322, green: 0.333, blue: 0.255),  // graphite    #525541
                Color(red: 0.549, green: 0.557, blue: 0.471),  // tea         #8C8E78
                Color(red: 0.659, green: 0.565, blue: 0.416),  // wheat       #A8926A
                Color(red: 0.420, green: 0.482, blue: 0.369),  // fern        #6B7B5E
                Color(red: 0.690, green: 0.659, blue: 0.565),  // parchment   #B0A890
            ]
        }
    }

    /// Primary accent color derived from the theme's dominant color
    var accent: Color {
        colors[0]
    }

    /// Lighter accent for backgrounds
    var accentLight: Color {
        colors[0].opacity(0.12)
    }

    /// Accent for borders
    var accentBorder: Color {
        colors[0].opacity(0.2)
    }

    /// Banner background — uses the primary theme color
    var bannerBackground: Color {
        colors[0]
    }
}
