import UIKit

final class RootViewController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set on the bar rather than the controller's view, so it tints the selected
        // tab without every screen inheriting it in place of the app's accent colour.
        self.tabBar.tintColor = .systemTeal

        self.tabs = AppTab.allCases.map { tab in
            UITab(
                title: tab.title,
                image: tab.image,
                identifier: tab.rawValue
            ) { _ in
                tab.makeNavigationController()
            }
        }
    }
}
