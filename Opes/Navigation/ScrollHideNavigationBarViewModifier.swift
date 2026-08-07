import SwiftUI
import UIKit

/// Hands the navigation bar's hide-on-scroll behaviour to UIKit.
///
/// `toolbarVisibility(_:for:)` cannot express this on iOS 26. It withdraws the
/// bar's background and the scroll edge effect that goes with it, but leaves
/// the floating Liquid Glass items in place, so the content runs under the
/// buttons with no surface left to dissolve into.
/// `UINavigationController.hidesBarsOnSwipe` moves the bar, the items inside it
/// and the scroll view's content insets from one place, which is what makes the
/// transition read as a single coordinated movement rather than as two things
/// animating past each other.
private struct ScrollHideNavigationBarViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(NavigationBarSwipeHider())
    }
}

/// Turns `hidesBarsOnSwipe` on for the navigation controller backing the
/// surrounding `NavigationStack`.
private struct NavigationBarSwipeHider: UIViewControllerRepresentable {
    func makeUIViewController(
        context: Context
    ) -> NavigationBarSwipeHiderViewController {
        NavigationBarSwipeHiderViewController()
    }

    func updateUIViewController(
        _ controller: NavigationBarSwipeHiderViewController,
        context: Context
    ) {}
}

/// An inert child view controller, present only to reach the navigation
/// controller SwiftUI keeps to itself.
private final class NavigationBarSwipeHiderViewController: UIViewController {
    override func loadView() {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        self.view = view
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.hidesBarsOnSwipe = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        guard let navigationController else { return }

        // A pushed screen shares this navigation controller, so leave it as it
        // was found rather than letting it inherit a bar that swipes away, or
        // worse, one that is currently hidden.
        navigationController.hidesBarsOnSwipe = false

        if navigationController.isNavigationBarHidden {
            navigationController.setNavigationBarHidden(false, animated: animated)
        }
    }
}

extension View {

    /// Hides the navigation bar while the user swipes up through the content
    /// and restores it when they swipe back down.
    /// - Returns: A view whose navigation bar follows the scroll direction.
    func scrollHideNavigationBar() -> some View {
        modifier(ScrollHideNavigationBarViewModifier())
    }
}
