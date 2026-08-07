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
        private var isNavigationBarFaded = false

        private let fadeDuration: TimeInterval = 0.2
        private let fadeTranslationThreshold: CGFloat = 8
        private let fadeVelocityThreshold: CGFloat = 20

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
            navigationController.barHideOnSwipeGestureRecognizer.addTarget(
                self,
                action: #selector(navigationBarSwipeChanged(_:))
            )
            configuredNavigationController = navigationController
        }

        func disableScrollHiding() {
            guard let configuredNavigationController else { return }

            configuredNavigationController.barHideOnSwipeGestureRecognizer.removeTarget(
                self,
                action: #selector(navigationBarSwipeChanged(_:))
            )
            configuredNavigationController.navigationBar.layer.removeAllAnimations()
            configuredNavigationController.navigationBar.alpha = 1
            configuredNavigationController.hidesBarsOnSwipe = previousHidesBarsOnSwipe
            isNavigationBarFaded = false
            self.configuredNavigationController = nil
        }

        @objc
        private func navigationBarSwipeChanged(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .began || gesture.state == .changed else { return }

            let translation = gesture.translation(in: gesture.view).y
            guard abs(translation) >= fadeTranslationThreshold else { return }

            let velocity = gesture.velocity(in: gesture.view).y

            if velocity <= -fadeVelocityThreshold {
                setNavigationBarFaded(true)
            } else if velocity >= fadeVelocityThreshold {
                setNavigationBarFaded(false)
            }
        }

        private func setNavigationBarFaded(_ isFaded: Bool) {
            guard isNavigationBarFaded != isFaded,
                  let navigationBar = configuredNavigationController?.navigationBar else {
                return
            }

            isNavigationBarFaded = isFaded

            UIView.animate(
                withDuration: fadeDuration,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]
            ) {
                navigationBar.alpha = isFaded ? 0 : 1
            }
        }
    }
}

extension View {
    func scrollHideNavigationBar() -> some View {
        modifier(ScrollHideNavigationBarViewModifier())
    }
}
