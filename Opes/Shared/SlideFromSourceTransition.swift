import UIKit

/// Presents a view controller as a bottom card that flies in right to left, starting
/// at the size and position of a source view so it reads as coming out of it.
///
/// This replaces `UISheetPresentationController` rather than decorating it — sheets
/// drive their own presentation and ignore a custom animator — so the grabber and
/// drag-to-resize/dismiss are traded away for the entrance animation. Height is
/// fixed at presentation time instead of being a detent the user can drag between.
final class SlideFromSourceTransition: NSObject {
    private weak var sourceView: UIView?

    init(sourceView: UIView) {
        self.sourceView = sourceView
        super.init()
    }
}

extension SlideFromSourceTransition: UIViewControllerTransitioningDelegate {
    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        SlideFromSourcePresentationController(
            presentedViewController: presented,
            presenting: presenting
        )
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        SlideFromSourceAnimator(sourceView: self.sourceView, isPresenting: true)
    }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        SlideFromSourceAnimator(sourceView: self.sourceView, isPresenting: false)
    }
}

/// Lays the card out along the bottom edge behind a dimmed backdrop.
final class SlideFromSourcePresentationController: UIPresentationController {
    private let dimmingView = UIView()

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = self.containerView else {
            return .zero
        }

        let bounds = containerView.bounds
        let top = containerView.safeAreaInsets.top + DesignTokens.sheetTopInset

        return CGRect(x: 0, y: top, width: bounds.width, height: bounds.height - top)
    }

    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()

        guard let containerView = self.containerView else {
            return
        }

        self.dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        self.dimmingView.alpha = 0
        self.dimmingView.frame = containerView.bounds
        self.dimmingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.dimmingView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(self.handleDimmingTap))
        )
        containerView.addSubview(self.dimmingView)

        if let presentedView = self.presentedView {
            presentedView.layer.cornerRadius = DesignTokens.cardCornerRadius
            presentedView.layer.cornerCurve = .continuous
            presentedView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            presentedView.clipsToBounds = true
        }

        _ = self.presentedViewController.transitionCoordinator?.animate { _ in
            self.dimmingView.alpha = 1
        }
    }

    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()

        _ = self.presentedViewController.transitionCoordinator?.animate { _ in
            self.dimmingView.alpha = 0
        }
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()

        self.presentedView?.frame = self.frameOfPresentedViewInContainerView
    }

    @objc private func handleDimmingTap() {
        // The only way out other than Done, now that there's no drag-to-dismiss.
        self.presentedViewController.dismiss(animated: true)
    }
}

/// Moves the card between its resting frame and the source view's frame, offset to
/// the right so the travel reads as right to left.
final class SlideFromSourceAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private weak var sourceView: UIView?
    private let isPresenting: Bool

    /// How far right of the source the card starts, as a fraction of the container
    /// width — enough travel to read as horizontal rather than as a plain zoom.
    private static let horizontalTravel: CGFloat = 0.5

    init(sourceView: UIView?, isPresenting: Bool) {
        self.sourceView = sourceView
        self.isPresenting = isPresenting
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.45
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        let viewKey: UITransitionContextViewKey = self.isPresenting ? .to : .from

        guard let view = transitionContext.view(forKey: viewKey) else {
            transitionContext.completeTransition(false)
            return
        }

        if self.isPresenting, let presented = transitionContext.viewController(forKey: .to) {
            view.frame = transitionContext.finalFrame(for: presented)
            containerView.addSubview(view)
        }

        let offsetTransform = self.offsetTransform(for: view, in: containerView)

        if self.isPresenting {
            view.transform = offsetTransform
            view.alpha = 0
        }

        UIView.animate(
            withDuration: self.transitionDuration(using: transitionContext),
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState],
            animations: {
                view.transform = self.isPresenting ? .identity : offsetTransform
                view.alpha = self.isPresenting ? 1 : 0
            },
            completion: { _ in
                let cancelled = transitionContext.transitionWasCancelled

                if !self.isPresenting && !cancelled {
                    view.removeFromSuperview()
                }

                view.transform = .identity
                transitionContext.completeTransition(!cancelled)
            }
        )
    }

    /// Maps the card's resting frame onto the source view's, then pushes it right.
    private func offsetTransform(for view: UIView, in containerView: UIView) -> CGAffineTransform {
        let restingFrame = view.frame
        let travel = containerView.bounds.width * Self.horizontalTravel

        guard restingFrame.width > 0, restingFrame.height > 0 else {
            return CGAffineTransform(translationX: travel, y: 0)
        }

        // No source view means no anchor to grow out of; slide in from the right only.
        guard
            let sourceView = self.sourceView,
            let sourceFrame = sourceView.superview?.convert(sourceView.frame, to: containerView)
        else {
            return CGAffineTransform(translationX: travel, y: 0)
        }

        return CGAffineTransform(
            translationX: sourceFrame.midX - restingFrame.midX + travel,
            y: sourceFrame.midY - restingFrame.midY
        )
        .scaledBy(
            x: sourceFrame.width / restingFrame.width,
            y: sourceFrame.height / restingFrame.height
        )
    }
}
