import SwiftUI

/// Creates a selectable tab whose content has an independent navigation stack.
///
/// - Parameters:
///   - title: The label displayed in the system tab bar.
///   - image: The SF Symbol name displayed alongside the title.
///   - tag: The value that identifies this tab in its parent `TabView` selection.
///   - environment: The stores handed to every screen the stack hosts.
///   - content: The root view displayed when the tab is selected.
/// - Returns: A tab that can be placed inside a `TabView`.
func createTabNavigationStack<Content: View, Tag: Hashable>(
    title: String,
    image: String,
    tag: Tag,
    environment: NavigationEnvironment,
    @ViewBuilder content: @escaping () -> Content
) -> some TabContent<Tag> {
    Tab(title, systemImage: image, value: tag) {
        UIKitNavigationStack(environment: environment, root: content)
            // The bar reaches the top of the screen so that content can pass
            // beneath it. The tab bar's inset at the bottom is left alone.
            .ignoresSafeArea(edges: .top)
    }
}
