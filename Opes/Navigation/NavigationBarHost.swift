import SwiftUI
import UIKit

/// The app-wide stores, carried across the UIKit boundary.
///
/// A view controller presented or pushed by UIKit does not inherit the SwiftUI
/// environment of the view that asked for it, so every hosted view is dressed
/// in the stores again on the way out.
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

/// Owns a tab's navigation bar: it builds the bar's items in UIKit, drives the
/// hide-on-swipe behaviour and performs pushes and zooming presentations.
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
        navigationController.hidesBarsOnSwipe = true
    }

    /// Rebuilds the bar from `configuration`.
    func apply(_ configuration: NavigationBarConfiguration) {
        guard let rootItem else { return }

        rootItem.leftBarButtonItem = makeTitleItem(configuration.title)

        // A pushed screen reads its back button's title from the item it was
        // pushed from, which is the only place the title is still needed as
        // text rather than as a view.
        rootItem.backButtonTitle = configuration.title

        // UIKit orders right bar button items from the trailing edge inwards,
        // the opposite of how they are declared.
        rootItem.rightBarButtonItems = configuration.items
            .reversed()
            .map(makeItem)
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

        // A label carried as a custom view keeps its size, weight and leading
        // position in every orientation, which is the whole reason the title is
        // not left to the bar's own title handling.
        let item = UIBarButtonItem(customView: label)

        // Bar button items are grouped into a shared Liquid Glass background by
        // default, which puts the title in a capsule as though it were an
        // action. A title is not a control, so it opts out.
        item.hidesSharedBackground = true

        return item
    }

    private func makeItem(_ item: NavigationBarItem) -> UIBarButtonItem {
        switch item {
        case .button(let button): makeButtonItem(button)
        case .toggle(let toggle): makeToggleItem(toggle)
        case .menu(let menu): makeMenuItem(menu)
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

    private func makeToggleItem(_ toggle: NavigationBarToggle) -> UIBarButtonItem {
        let isActive = toggle.isActive.wrappedValue

        return UIBarButtonItem(
            title: isActive ? toggle.activeLabel : toggle.label,
            primaryAction: UIAction { _ in
                toggle.isActive.wrappedValue.toggle()
            }
        )
    }

    private func makeMenuItem(_ menu: NavigationBarMenu) -> UIBarButtonItem {
        let selection = menu.selection.wrappedValue

        let actions = menu.options.map { option in
            UIAction(
                title: option.title,
                image: UIImage(systemName: option.systemImage),
                state: option.id == selection ? .on : .off
            ) { _ in
                menu.selection.wrappedValue = option.id
            }
        }

        let item = UIBarButtonItem(
            image: UIImage(systemName: menu.systemImage),
            menu: UIMenu(children: actions)
        )
        item.accessibilityLabel = menu.label
        return item
    }

    private func makeZoomingSheetItem(
        _ sheet: NavigationBarZoomingSheet
    ) -> UIBarButtonItem {
        var configuration = UIButton.Configuration.glass()
        configuration.image = UIImage(systemName: sheet.systemImage)
        configuration.cornerStyle = .capsule

        // The zoom transition needs a view to grow out of, and a standard bar
        // button item does not expose one, so this button is built by hand.
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
        // Only the tab's root screen swipes its bar away. A pushed screen keeps
        // its bar so that its back button is always reachable.
        let isRoot = viewController === navigationController.viewControllers.first
        navigationController.hidesBarsOnSwipe = isRoot

        if navigationController.isNavigationBarHidden {
            navigationController.setNavigationBarHidden(false, animated: animated)
        }
    }
}
