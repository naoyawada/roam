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

    func makeUIViewController(context: Context) -> TabBarHost<Content> {
        let tabBarHost = TabBarHost<Content>()

        // 3 empty VCs provide tab bar items. They get selected/deselected
        // by UIKit but are always behind our hosting view.
        let vc0 = UIViewController()
        vc0.tabBarItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "chart.bar.fill"), tag: 0)
        vc0.view.isUserInteractionEnabled = false

        let vc1 = UIViewController()
        vc1.tabBarItem = UITabBarItem(title: "Timeline", image: UIImage(systemName: "calendar"), tag: 1)
        vc1.view.isUserInteractionEnabled = false

        let vc2 = UIViewController()
        vc2.tabBarItem = UITabBarItem(title: "Insights", image: UIImage(systemName: "lightbulb.fill"), tag: 2)
        vc2.view.isUserInteractionEnabled = false

        tabBarHost.viewControllers = [vc0, vc1, vc2]
        tabBarHost.delegate = context.coordinator
        tabBarHost.tabBar.tintColor = UIColor(RoamTheme.accent)

        // Hosting controller inserted as a persistent child — always visible
        // regardless of which empty VC is "selected" for the tab bar highlight.
        // Pinned edge-to-edge so content extends behind the translucent tab bar.
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        tabBarHost.addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        tabBarHost.view.insertSubview(hostingController.view, belowSubview: tabBarHost.tabBar)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: tabBarHost.view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: tabBarHost.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: tabBarHost.view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: tabBarHost.view.bottomAnchor),
        ])
        hostingController.didMove(toParent: tabBarHost)

        tabBarHost.swiftUIHostingController = hostingController
        context.coordinator.hostingController = hostingController

        // Window background for status bar and home indicator areas
        DispatchQueue.main.async {
            tabBarHost.view.window?.backgroundColor = Self.themeBackground
        }

        return tabBarHost
    }

    func updateUIViewController(_ tabBarHost: TabBarHost<Content>, context: Context) {
        // selectedIndex updates the tab bar highlight AND switches the empty VC
        // (which is fine — our hosting view is always on top of the empty VCs)
        if tabBarHost.selectedIndex != selection {
            tabBarHost.selectedIndex = selection
        }
        context.coordinator.hostingController?.rootView = content
        tabBarHost.view.window?.backgroundColor = Self.themeBackground
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
            // Return true — UIKit switches the empty VC (invisible behind our
            // hosting view) and updates the tab bar highlight naturally.
            return true
        }
    }
}

/// Subclass that propagates tab bar safe area to the hosting controller
/// so ScrollViews properly inset content above the tab bar.
@MainActor
final class TabBarHost<Content: View>: UITabBarController {
    var swiftUIHostingController: UIHostingController<Content>?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let hosting = swiftUIHostingController else { return }
        let tabBarHeight = tabBar.frame.height
        let currentAdditional = hosting.additionalSafeAreaInsets.bottom
        let inherited = hosting.view.safeAreaInsets.bottom - currentAdditional
        let needed = max(0, tabBarHeight - inherited)
        if abs(currentAdditional - needed) > 0.5 {
            hosting.additionalSafeAreaInsets.bottom = needed
        }
    }
}
