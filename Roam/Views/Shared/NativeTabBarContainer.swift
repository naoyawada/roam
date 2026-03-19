import SwiftUI

struct NativeTabBarContainer<Content: View>: UIViewControllerRepresentable {
    @Binding var selection: Int
    let content: Content

    init(selection: Binding<Int>, @ViewBuilder content: () -> Content) {
        self._selection = selection
        self.content = content()
    }

    func makeUIViewController(context: Context) -> UITabBarController {
        let tabBarController = UITabBarController()

        // Create 3 empty VCs with tab bar items (for the native tab bar)
        let vc0 = UIViewController()
        vc0.tabBarItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "chart.bar.fill"), tag: 0)
        vc0.view.backgroundColor = .clear
        vc0.view.isUserInteractionEnabled = false

        let vc1 = UIViewController()
        vc1.tabBarItem = UITabBarItem(title: "Timeline", image: UIImage(systemName: "calendar"), tag: 1)
        vc1.view.backgroundColor = .clear
        vc1.view.isUserInteractionEnabled = false

        let vc2 = UIViewController()
        vc2.tabBarItem = UITabBarItem(title: "Insights", image: UIImage(systemName: "lightbulb.fill"), tag: 2)
        vc2.view.backgroundColor = .clear
        vc2.view.isUserInteractionEnabled = false

        tabBarController.viewControllers = [vc0, vc1, vc2]
        tabBarController.delegate = context.coordinator
        tabBarController.tabBar.tintColor = UIColor(RoamTheme.accent)

        // Host the SwiftUI paging content behind the tab bar
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        tabBarController.addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        // Insert directly below the tab bar: above VC content, below tab bar
        tabBarController.view.insertSubview(hostingController.view, belowSubview: tabBarController.tabBar)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: tabBarController.view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: tabBarController.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: tabBarController.view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: tabBarController.view.bottomAnchor),
        ])
        hostingController.didMove(toParent: tabBarController)

        context.coordinator.hostingController = hostingController

        return tabBarController
    }

    func updateUIViewController(_ tabBarController: UITabBarController, context: Context) {
        // Sync tab bar selection with SwiftUI state
        if tabBarController.selectedIndex != selection {
            tabBarController.selectedIndex = selection
        }
        // Update the SwiftUI content
        context.coordinator.hostingController?.rootView = content
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
            }
            // Return true so the tab bar visually updates its selection
            return true
        }
    }
}
