import SwiftUI
import UIKit

/// The app-wide stores, carried across the UIKit boundary.
///
/// A view controller pushed by UIKit does not inherit the SwiftUI environment
/// of the view that asked for it, so every hosted view is dressed in the stores
/// again on the way out.
struct NavigationEnvironment {
    let session: SessionStore
    let accountStore: AccountStore
    let dashboardStore: DashboardStore

    func decorate<Content: View>(_ content: Content) -> some View {
        content
            .environmentObject(session)
            .environmentObject(accountStore)
            .environmentObject(dashboardStore)
    }
}

/// Owns a tab's navigation controller: it performs pushes and decides which
/// screens get a navigation bar.
///
/// A tab's root screen carries its title and actions in its own scroll content
/// so they scroll away with the view, which leaves it nothing to put in a bar.
/// A pushed screen has a back button and so gets its bar back.
@MainActor
final class NavigationBarHost: NSObject {
    private let environment: NavigationEnvironment
    private weak var navigationController: UINavigationController?
    private weak var rootItem: UINavigationItem?

    init(environment: NavigationEnvironment) {
        self.environment = environment
    }

    func attach(
        to navigationController: UINavigationController,
        rootItem: UINavigationItem
    ) {
        self.navigationController = navigationController
        self.rootItem = rootItem

        navigationController.delegate = self
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    /// Sets the text a pushed screen shows in its back button.
    func setBackTitle(_ title: String) {
        rootItem?.backButtonTitle = title
    }

    /// Pushes `content` onto this tab's stack.
    func push<Content: View>(_ content: Content) {
        let controller = UIHostingController(rootView: environment.decorate(content))
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension NavigationBarHost: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        let isRoot = viewController === navigationController.viewControllers.first
        navigationController.setNavigationBarHidden(isRoot, animated: animated)
    }
}
