import SwiftUI

struct SwipeableTabContainer<Tab0: View, Tab1: View, Tab2: View>: View {
    @Binding var selection: Int
    let tab0: Tab0
    let tab1: Tab1
    let tab2: Tab2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let tabCount = 3

    init(selection: Binding<Int>,
         @ViewBuilder tab0: () -> Tab0,
         @ViewBuilder tab1: () -> Tab1,
         @ViewBuilder tab2: () -> Tab2) {
        self._selection = selection
        self.tab0 = tab0()
        self.tab1 = tab1()
        self.tab2 = tab2()
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            HStack(spacing: 0) {
                tab0.frame(width: width).clipped()
                    .allowsHitTesting(selection == 0)
                tab1.frame(width: width).clipped()
                    .allowsHitTesting(selection == 1)
                tab2.frame(width: width).clipped()
                    .allowsHitTesting(selection == 2)
            }
            .offset(x: -CGFloat(selection) * width + dragOffset)
        }
    }
}
