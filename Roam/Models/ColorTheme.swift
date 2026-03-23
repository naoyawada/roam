import SwiftUI

enum ColorTheme: String, CaseIterable, Identifiable {
    case earthy
    case cool
    case vibrant
    case sunset
    case moody

    var id: String { rawValue }

    static let `default`: ColorTheme = .earthy

    var displayName: String {
        switch self {
        case .earthy:   "Earthy"
        case .cool:     "Cool"
        case .vibrant:  "Vibrant"
        case .sunset:   "Sunset"
        case .moody:    "Moody"
        }
    }

    var colors: [Color] {
        switch self {
        case .earthy:
            [
                Color(red: 0.478, green: 0.361, blue: 0.267),  // leather  #7A5C44
                Color(red: 0.604, green: 0.494, blue: 0.392),  // tan      #9A7E64
                Color(red: 0.369, green: 0.490, blue: 0.431),  // sage     #5E7D6E
                Color(red: 0.690, green: 0.604, blue: 0.525),  // sand     #B09A86
                Color(red: 0.545, green: 0.420, blue: 0.353),  // umber    #8B6B5A
            ]
        case .cool:
            [
                Color(red: 0.314, green: 0.416, blue: 0.510),  // blue fusion   #506A82
                Color(red: 0.482, green: 0.702, blue: 0.816),  // baltic sea    #7BB3D0
                Color(red: 0.608, green: 0.561, blue: 0.678),  // quiet violet  #9B8FAD
                Color(red: 0.447, green: 0.420, blue: 0.396),  // hematite      #726B65
                Color(red: 0.761, green: 0.831, blue: 0.753),  // veiled vista  #C2D4C0
            ]
        case .vibrant:
            [
                Color(red: 0.000, green: 0.737, blue: 0.831),  // blue curacao  #00BCD4
                Color(red: 0.941, green: 0.565, blue: 0.502),  // desert flower #F09080
                Color(red: 0.580, green: 0.306, blue: 0.549),  // orchid        #944E8C
                Color(red: 0.769, green: 0.588, blue: 0.227),  // spicy mustard #C4963A
                Color(red: 0.251, green: 0.447, blue: 0.502),  // dragonfly     #407280
            ]
        case .sunset:
            [
                Color(red: 0.769, green: 0.588, blue: 0.227),  // mango mojito  #C4963A
                Color(red: 0.941, green: 0.451, blue: 0.549),  // pink lemonade #F0738C
                Color(red: 0.690, green: 0.510, blue: 0.392),  // caramel       #B08264
                Color(red: 0.549, green: 0.557, blue: 0.471),  // tea           #8C8E78
                Color(red: 0.976, green: 0.698, blue: 0.502),  // papaya        #F9B280
            ]
        case .moody:
            [
                Color(red: 0.192, green: 0.376, blue: 0.416),  // dragonfly     #31606A
                Color(red: 0.698, green: 0.129, blue: 0.176),  // scarlet smile #B2212D
                Color(red: 0.608, green: 0.443, blue: 0.502),  // bordeaux      #9B7180
                Color(red: 0.322, green: 0.333, blue: 0.255),  // graphite      #525541
                Color(red: 0.502, green: 0.494, blue: 0.494),  // micron        #807E7E
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
