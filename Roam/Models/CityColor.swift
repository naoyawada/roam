import Foundation
import SwiftData

@Model
final class CityColor {
    var cityKey: String = ""
    var colorIndex: Int = 0

    init(cityKey: String, colorIndex: Int) {
        self.cityKey = cityKey
        self.colorIndex = colorIndex
    }
}
