import Foundation
import SwiftData

@Model
final class CityColor {
    @Attribute(.unique) var cityKey: String
    var colorIndex: Int

    init(cityKey: String, colorIndex: Int) {
        self.cityKey = cityKey
        self.colorIndex = colorIndex
    }
}
