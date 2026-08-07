import SwiftUI
import UIKit

private struct ScrollHideNavigationBarViewModifier: ViewModifier {
    @State private var isNavigationBarHidden = false
    @State private var previousOffset: CGFloat = 0

    private let scrollThreshold: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newOffset in
                if newOffset <= 0 {
                    isNavigationBarHidden = false
                    previousOffset = 0
                    return
                }

                let difference = newOffset - previousOffset
                guard abs(difference) >= scrollThreshold else { return }

                isNavigationBarHidden = difference > 0
                previousOffset = newOffset
            }
            .background {
                NavigationBarFadingController(isHidden: isNavigationBarHidden)
                    .frame(width: 0, height: 0)
            }
    }
}

/// Crossfades the complete navigation bar while leaving its geometry fixed.
private struct NavigationBarFadingController: UIViewControllerRepresentable {
    let isHidden: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.update(isHidden: isHidden)
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: Void) {
        controller.restoreNavigationBar()
    }

    final class Controller: UIViewController {
        private weak var configuredNavigationController: UINavigationController?
        private var previousHidesBarsOnSwipe = false
        private var shouldHideNavigationBar = false
        private var appliedNavigationBarHidden: Bool?
        private weak var blurOverlay: UIVisualEffectView?

        private let transitionDuration: TimeInterval = 0.28

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configureNavigationControllerIfNeeded()
            applyNavigationBarVisibility(animated: false)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            restoreNavigationBar()
        }

        func update(isHidden: Bool) {
            shouldHideNavigationBar = isHidden
            configureNavigationControllerIfNeeded()
            applyNavigationBarVisibility(animated: true)
        }

        func restoreNavigationBar() {
            guard let configuredNavigationController else { return }

            configuredNavigationController.navigationBar.layer.removeAllAnimations()
            configuredNavigationController.navigationBar.alpha = 1
            blurOverlay?.layer.removeAllAnimations()
            blurOverlay?.removeFromSuperview()
            configuredNavigationController.hidesBarsOnSwipe = previousHidesBarsOnSwipe
            appliedNavigationBarHidden = nil
            self.configuredNavigationController = nil
        }

        private func configureNavigationControllerIfNeeded() {
            guard viewIfLoaded?.window != nil,
                  let navigationController,
                  navigationController !== configuredNavigationController else {
                return
            }

            restoreNavigationBar()
            previousHidesBarsOnSwipe = navigationController.hidesBarsOnSwipe
            navigationController.hidesBarsOnSwipe = false
            configuredNavigationController = navigationController
        }

        private func applyNavigationBarVisibility(animated: Bool) {
            guard appliedNavigationBarHidden != shouldHideNavigationBar,
                  let navigationBar = configuredNavigationController?.navigationBar else {
                return
            }

            appliedNavigationBarHidden = shouldHideNavigationBar

            let blurOverlay = prepareBlurOverlay(in: navigationBar)
            let changes = {
                navigationBar.alpha = self.shouldHideNavigationBar ? 0 : 1
                blurOverlay.alpha = self.shouldHideNavigationBar ? 1 : 0
            }

            guard animated else {
                navigationBar.layer.removeAllAnimations()
                blurOverlay.layer.removeAllAnimations()
                changes()
                removeBlurOverlayIfVisible()
                return
            }

            UIView.animate(
                withDuration: transitionDuration,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut],
                animations: changes
            ) { finished in
                guard finished else { return }
                self.removeBlurOverlayIfVisible()
            }
        }

        private func prepareBlurOverlay(in navigationBar: UINavigationBar) -> UIVisualEffectView {
            if let blurOverlay {
                navigationBar.bringSubviewToFront(blurOverlay)
                return blurOverlay
            }

            let blurOverlay = UIVisualEffectView(
                effect: UIBlurEffect(style: .systemUltraThinMaterial)
            )
            blurOverlay.frame = navigationBar.bounds
            blurOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurOverlay.isUserInteractionEnabled = false
            blurOverlay.alpha = shouldHideNavigationBar ? 0 : 1
            navigationBar.addSubview(blurOverlay)
            self.blurOverlay = blurOverlay
            return blurOverlay
        }

        private func removeBlurOverlayIfVisible() {
            guard !shouldHideNavigationBar else { return }
            blurOverlay?.removeFromSuperview()
        }
    }
}

extension View {
    func scrollHideNavigationBar() -> some View {
        modifier(ScrollHideNavigationBarViewModifier())
    }
}
