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

/// Owns a tab's navigation controller: it performs pushes, builds an optional
/// root toolbar and decides which screens get a navigation bar.
///
/// Most tab roots carry their headers in their scroll content and keep the bar
/// hidden. A root can opt into a toolbar, while pushed screens always show the
/// bar for their back button.
@MainActor
final class NavigationBarHost: NSObject {
    private let environment: NavigationEnvironment
    private weak var navigationController: UINavigationController?
    private weak var rootItem: UINavigationItem?
    private var hasRootToolbar = false

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

    /// Rebuilds the root screen's top toolbar from `configuration`.
    func apply(_ configuration: NavigationBarConfiguration) {
        guard let rootItem, let navigationController else { return }

        hasRootToolbar = true
        rootItem.leftBarButtonItem = makeTitleItem(configuration.title)
        rootItem.backButtonTitle = configuration.title

        // UIKit orders right bar button items from the trailing edge inwards.
        rootItem.rightBarButtonItems = configuration.items
            .reversed()
            .map(makeItem)

        if navigationController.topViewController === navigationController.viewControllers.first {
            navigationController.hidesBarsOnSwipe = true
            navigationController.setNavigationBarHidden(false, animated: false)
        }
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

    private func makeTitleItem(_ title: String) -> UIBarButtonItem {
        let label = UILabel()
        label.text = title
        label.textColor = .label
        label.font = UIFontMetrics(forTextStyle: .title2)
            .scaledFont(for: .systemFont(ofSize: 22, weight: .bold))
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits.insert(.header)
        label.sizeToFit()

        let item = UIBarButtonItem(customView: label)
        item.hidesSharedBackground = true
        return item
    }

    private func makeItem(_ item: NavigationBarItem) -> UIBarButtonItem {
        switch item {
        case .button(let button): makeButtonItem(button)
        case .zoomingSheet(let sheet): makeZoomingSheetItem(sheet)
        }
    }

    private func makeButtonItem(_ button: NavigationBarButton) -> UIBarButtonItem {
        let item = UIBarButtonItem(
            image: UIImage(systemName: button.systemImage),
            primaryAction: UIAction { _ in button.action() }
        )
        item.accessibilityLabel = button.label
        return item
    }

    private func makeZoomingSheetItem(
        _ sheet: NavigationBarZoomingSheet
    ) -> UIBarButtonItem {
        var configuration = UIButton.Configuration.glass()
        configuration.image = UIImage(systemName: sheet.systemImage)
        configuration.cornerStyle = .capsule

        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = sheet.label
        button.addAction(
            UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }
                self.present(sheet, from: button)
            },
            for: .primaryActionTriggered
        )

        return UIBarButtonItem(customView: button)
    }

    private func present(
        _ sheet: NavigationBarZoomingSheet,
        from sourceView: UIView
    ) {
        let controller = UIHostingController(
            rootView: environment.decorate(sheet.content())
        )
        controller.preferredTransition = .zoom { _ in sourceView }
        navigationController?.present(controller, animated: true)
    }
}

extension NavigationBarHost: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        let isRoot = viewController === navigationController.viewControllers.first
        navigationController.hidesBarsOnSwipe = isRoot && hasRootToolbar
        navigationController.setNavigationBarHidden(
            isRoot && !hasRootToolbar,
            animated: animated
        )
    }
}
