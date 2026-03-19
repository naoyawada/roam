import SwiftUI

struct SwipeableTabContainer<Tab0: View, Tab1: View, Tab2: View>: View {
    @Binding var selection: Int
    let tab0: Tab0
    let tab1: Tab1
    let tab2: Tab2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    tab0.id(0)
                        .containerRelativeFrame(.horizontal)
                    tab1.id(1)
                        .containerRelativeFrame(.horizontal)
                    tab2.id(2)
                        .containerRelativeFrame(.horizontal)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: Binding(
                get: { selection },
                set: { newValue in
                    if let newValue {
                        selection = newValue
                    }
                }
            ))
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.automatic)
            .onChange(of: selection) { _, newValue in
                let animation: Animation = reduceMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.3)
                withAnimation(animation) {
                    proxy.scrollTo(newValue, anchor: .leading)
                }
            }
        }
    }
}
