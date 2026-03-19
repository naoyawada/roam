import SwiftUI

struct SwipeableTabContainer<Tab0: View, Tab1: View, Tab2: View>: View {
    @Binding var selection: Int
    let tab0: Tab0
    let tab1: Tab1
    let tab2: Tab2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var animatedSelection: Int

    private let tabCount = 3
    private let edgeZoneWidth: CGFloat = 20

    private func isInEdgeZone(startX: CGFloat, screenWidth: CGFloat) -> Bool {
        startX <= edgeZoneWidth || startX >= screenWidth - edgeZoneWidth
    }

    init(selection: Binding<Int>,
         @ViewBuilder tab0: () -> Tab0,
         @ViewBuilder tab1: () -> Tab1,
         @ViewBuilder tab2: () -> Tab2) {
        self._selection = selection
        self._animatedSelection = State(initialValue: selection.wrappedValue)
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
            .offset(x: -CGFloat(animatedSelection) * width + dragOffset)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .updating($dragOffset) { value, state, _ in
                        guard isInEdgeZone(startX: value.startLocation.x, screenWidth: width) else {
                            return
                        }
                        isDragging = true

                        let translation = value.translation.width
                        let isAtLeadingEdge = selection == 0 && translation > 0
                        let isAtTrailingEdge = selection == tabCount - 1 && translation < 0

                        if isAtLeadingEdge || isAtTrailingEdge {
                            state = translation * 0.3
                        } else {
                            state = translation
                        }
                    }
                    .onEnded { value in
                        guard isDragging else { return }
                        isDragging = false

                        let translation = value.translation.width
                        let velocity = value.velocity.width
                        let commitThreshold = width * 0.4
                        let velocityThreshold: CGFloat = 500

                        var newSelection = selection

                        if translation < -commitThreshold || velocity < -velocityThreshold {
                            if selection < tabCount - 1 {
                                newSelection = selection + 1
                            }
                        } else if translation > commitThreshold || velocity > velocityThreshold {
                            if selection > 0 {
                                newSelection = selection - 1
                            }
                        }

                        withAnimation(.spring(duration: 0.3)) {
                            selection = newSelection
                            animatedSelection = newSelection
                        }
                    }
            )
            .onChange(of: selection) { oldValue, newValue in
                guard !isDragging else {
                    animatedSelection = newValue
                    return
                }
                withAnimation(.spring(duration: 0.3)) {
                    animatedSelection = newValue
                }
            }
        }
    }
}
