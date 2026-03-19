import SwiftUI

struct GrainBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoamTheme.background.ignoresSafeArea(edges: [.top, .horizontal]))
            .overlay {
                Canvas { context, size in
                    // Draw subtle noise grain
                    for _ in 0..<Int(size.width * size.height * 0.03) {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let opacity = Double.random(in: 0.02...0.06)
                        let dotSize = CGFloat.random(in: 0.5...1.5)
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                            with: .color(RoamTheme.grainColor.opacity(opacity))
                        )
                    }
                }
                .ignoresSafeArea(edges: [.top, .horizontal])
                .allowsHitTesting(false)
                .drawingGroup()
            }
    }
}

extension View {
    func grainBackground() -> some View {
        modifier(GrainBackground())
    }
}
