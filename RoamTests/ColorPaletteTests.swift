import XCTest
import SwiftUI
@testable import Roam

final class ColorPaletteTests: XCTestCase {

    func testEarthyThemeHasFiveColors() {
        XCTAssertEqual(ColorTheme.earthy.colors.count, 5)
    }

    func testCoolThemeHasFiveColors() {
        XCTAssertEqual(ColorTheme.cool.colors.count, 5)
    }

    func testVibrantThemeHasFiveColors() {
        XCTAssertEqual(ColorTheme.vibrant.colors.count, 5)
    }

    func testSunsetThemeHasFiveColors() {
        XCTAssertEqual(ColorTheme.sunset.colors.count, 5)
    }

    func testMoodyThemeHasFiveColors() {
        XCTAssertEqual(ColorTheme.moody.colors.count, 5)
    }

    func testColorForIndexWithinRange() {
        for theme in ColorTheme.allCases {
            for i in 0..<5 {
                XCTAssertEqual(
                    ColorPalette.color(for: i, theme: theme),
                    theme.colors[i],
                    "Theme \(theme.rawValue) index \(i) mismatch"
                )
            }
        }
    }

    func testColorForIndexOutOfRangeReturnsFallback() {
        for theme in ColorTheme.allCases {
            let color = ColorPalette.color(for: 5, theme: theme)
            XCTAssertEqual(color, ColorPalette.otherColor)

            let color99 = ColorPalette.color(for: 99, theme: theme)
            XCTAssertEqual(color99, ColorPalette.otherColor)
        }
    }

    func testRawValueRoundTrip() {
        for theme in ColorTheme.allCases {
            XCTAssertEqual(ColorTheme(rawValue: theme.rawValue), theme)
        }
    }

    func testDefaultThemeIsEarthy() {
        XCTAssertEqual(ColorTheme.default, .earthy)
    }
}
