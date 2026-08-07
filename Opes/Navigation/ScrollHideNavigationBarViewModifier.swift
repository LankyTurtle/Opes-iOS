import SwiftUI
import UIKit

private struct ScrollHideNavigationBarViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            NavigationBarScrollHidingController()
                .frame(width: 0, height: 0)
        }
    }
}

/// Enables UINavigationController's scroll-aware bar transition without
/// changing SwiftUI state while a scroll view is laying itself out.
private struct NavigationBarScrollHidingController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.enableScrollHiding()
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: Void) {
        controller.disableScrollHiding()
    }

    final class Controller: UIViewController {
        private weak var configuredNavigationController: UINavigationController?
        private var previousHidesBarsOnSwipe = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableScrollHiding()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            disableScrollHiding()
        }

        func enableScrollHiding() {
            guard viewIfLoaded?.window != nil,
                  let navigationController,
                  navigationController !== configuredNavigationController else {
                return
            }

            disableScrollHiding()
            previousHidesBarsOnSwipe = navigationController.hidesBarsOnSwipe
            navigationController.hidesBarsOnSwipe = true
            configuredNavigationController = navigationController
        }

        func disableScrollHiding() {
            guard let configuredNavigationController else { return }

            configuredNavigationController.hidesBarsOnSwipe = previousHidesBarsOnSwipe
            self.configuredNavigationController = nil
        }
    }
}

extension View {
    func scrollHideNavigationBar() -> some View {
        modifier(ScrollHideNavigationBarViewModifier())
    }
}
