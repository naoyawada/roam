import SwiftUI

struct NativeTabBarContainer<Content: View>: UIViewControllerRepresentable {
    @Binding var selection: Int
    let content: Content

    init(selection: Binding<Int>, @ViewBuilder content: () -> Content) {
        self._selection = selection
        self.content = content()
    }

    private static var themeBackground: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.098, green: 0.094, blue: 0.086, alpha: 1)
                : UIColor(red: 0.969, green: 0.969, blue: 0.957, alpha: 1)
        }
    }

    func makeUIViewController(context: Context) -> UITabBarController {
        let tabBarController = UITabBarController()

        // The hosting controller IS the managed VC0.
        // UITabBarController will properly propagate safe area insets
        // (including the tab bar height) to this VC, so ScrollViews
        // automatically inset content above the tab bar while allowing
        // content to scroll behind the translucent glass.
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.tabBarItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "chart.bar.fill"), tag: 0)

        // Placeholder VCs just provide tab bar items — never actually displayed
        let vc1 = UIViewController()
        vc1.tabBarItem = UITabBarItem(title: "Timeline", image: UIImage(systemName: "calendar"), tag: 1)

        let vc2 = UIViewController()
        vc2.tabBarItem = UITabBarItem(title: "Insights", image: UIImage(systemName: "lightbulb.fill"), tag: 2)

        tabBarController.viewControllers = [hostingController, vc1, vc2]
        tabBarController.delegate = context.coordinator
        tabBarController.tabBar.tintColor = UIColor(RoamTheme.accent)

        context.coordinator.hostingController = hostingController

        // Set window background for status bar and home indicator areas
        DispatchQueue.main.async {
            tabBarController.view.window?.backgroundColor = Self.themeBackground
        }

        return tabBarController
    }

    func updateUIViewController(_ tabBarController: UITabBarController, context: Context) {
        // Sync tab bar highlight with SwiftUI state (visual only, no VC switch)
        let items = tabBarController.tabBar.items ?? []
        if selection < items.count, tabBarController.tabBar.selectedItem !== items[selection] {
            tabBarController.tabBar.selectedItem = items[selection]
        }
        // Update the SwiftUI content
        context.coordinator.hostingController?.rootView = content
        // Keep window background in sync for trait changes
        tabBarController.view.window?.backgroundColor = Self.themeBackground
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    @MainActor
    class Coordinator: NSObject, UITabBarControllerDelegate {
        @Binding var selection: Int
        var hostingController: UIHostingController<Content>?

        init(selection: Binding<Int>) {
            _selection = selection
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            if let index = tabBarController.viewControllers?.firstIndex(of: viewController) {
                withAnimation(.smooth(duration: 0.3)) {
                    selection = index
                }
                // Manually update the tab bar highlight
                DispatchQueue.main.async {
                    tabBarController.tabBar.selectedItem = tabBarController.tabBar.items?[index]
                }
            }
            // Return false to prevent VC switching — VC0 always stays displayed
            return false
        }
    }
}
