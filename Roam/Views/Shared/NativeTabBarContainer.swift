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

        let vc0 = UIViewController()
        vc0.tabBarItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "chart.bar.fill"), tag: 0)
        vc0.view.isUserInteractionEnabled = false

        let vc1 = UIViewController()
        vc1.tabBarItem = UITabBarItem(title: "Timeline", image: UIImage(systemName: "calendar"), tag: 1)
        vc1.view.isUserInteractionEnabled = false

        let vc2 = UIViewController()
        vc2.tabBarItem = UITabBarItem(title: "Insights", image: UIImage(systemName: "lightbulb.fill"), tag: 2)
        vc2.view.isUserInteractionEnabled = false

        tabBarController.viewControllers = [vc0, vc1, vc2]
        tabBarController.delegate = context.coordinator
        tabBarController.tabBar.tintColor = UIColor(RoamTheme.accent)

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        tabBarController.addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        tabBarController.view.insertSubview(hostingController.view, belowSubview: tabBarController.tabBar)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: tabBarController.view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: tabBarController.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: tabBarController.view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: tabBarController.tabBar.topAnchor, constant: -20),
        ])
        hostingController.didMove(toParent: tabBarController)

        context.coordinator.hostingController = hostingController

        DispatchQueue.main.async {
            tabBarController.view.window?.backgroundColor = Self.themeBackground
        }

        return tabBarController
    }

    func updateUIViewController(_ tabBarController: UITabBarController, context: Context) {
        if tabBarController.selectedIndex != selection {
            tabBarController.selectedIndex = selection
        }
        context.coordinator.hostingController?.rootView = content
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
            }
            return true
        }
    }
}
