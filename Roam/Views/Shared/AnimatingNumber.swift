import SwiftUI

struct AnimatingNumber: View, @preconcurrency Animatable {
    var value: Double
    var suffix: String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value))\(suffix)")
    }
}
