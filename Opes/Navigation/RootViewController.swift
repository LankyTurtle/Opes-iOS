import UIKit

final class RootViewController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()

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
