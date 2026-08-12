import UIKit

/// Presents a view controller as a bottom card that flies in right to left, starting
/// at the size and position of a source view so it reads as coming out of it.
///
/// This replaces `UISheetPresentationController` rather than decorating it — sheets
/// drive their own presentation and ignore a custom animator — so the fixed-height
/// card supplies its own grabber and dismissal gestures instead of using detents.
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
    private let grabberView = SheetGrabberView()
    private lazy var dismissPanGesture = UIPanGestureRecognizer(
        target: self,
        action: #selector(self.handleDismissPan(_:))
    )

    private var isCompletingPanDismissal = false

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

            self.grabberView.onAccessibilityActivate = { [weak self] in
                self?.dismissPresentedViewController()
            }
            let doubleTapGesture = UITapGestureRecognizer(
                target: self,
                action: #selector(self.handleGrabberDoubleTap)
            )
            doubleTapGesture.numberOfTapsRequired = 2
            self.grabberView.addGestureRecognizer(doubleTapGesture)
            presentedView.addSubview(self.grabberView)

            self.dismissPanGesture.delegate = self
            presentedView.addGestureRecognizer(self.dismissPanGesture)
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

        guard let presentedView = self.presentedView else {
            return
        }

        let grabberHitWidth = max(
            DesignTokens.minimumTapTarget * 2,
            DesignTokens.grabberSize.width
        )
        self.grabberView.frame = CGRect(
            x: (presentedView.bounds.width - grabberHitWidth) / 2,
            y: 0,
            width: grabberHitWidth,
            height: DesignTokens.minimumTapTarget
        )
        presentedView.bringSubviewToFront(self.grabberView)
    }

    @objc private func handleDimmingTap() {
        self.dismissPresentedViewController()
    }

    @objc private func handleGrabberDoubleTap() {
        self.dismissPresentedViewController()
    }

    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        guard
            !self.isCompletingPanDismissal,
            let presentedView = self.presentedView
        else {
            return
        }

        let translation = gesture.translation(in: presentedView)
        let downwardTranslation = max(translation.y, 0)

        switch gesture.state {
        case .changed:
            presentedView.transform = CGAffineTransform(
                translationX: 0,
                y: downwardTranslation
            )

            let fadeDistance = max(presentedView.bounds.height * 0.5, 1)
            self.dimmingView.alpha = max(1 - downwardTranslation / fadeDistance, 0)

        case .ended:
            let downwardVelocity = gesture.velocity(in: presentedView).y
            let dismissalDistance = min(presentedView.bounds.height * 0.2, 180)

            if downwardTranslation >= dismissalDistance || downwardVelocity >= 900 {
                self.completePanDismissal(of: presentedView)
            } else {
                self.cancelPanDismissal(of: presentedView)
            }

        case .cancelled, .failed:
            self.cancelPanDismissal(of: presentedView)

        default:
            break
        }
    }

    private func completePanDismissal(of presentedView: UIView) {
        self.isCompletingPanDismissal = true
        presentedView.isUserInteractionEnabled = false

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseOut],
            animations: {
                presentedView.transform = CGAffineTransform(
                    translationX: 0,
                    y: presentedView.bounds.height
                )
                self.dimmingView.alpha = 0
            },
            completion: { [weak self] _ in
                // The card has already completed its visual dismissal, so asking
                // UIKit to tear down the presentation without a second animation
                // avoids a direction change back toward the source tile.
                self?.presentedViewController.dismiss(animated: false)
            }
        )
    }

    private func cancelPanDismissal(of presentedView: UIView) {
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: {
                presentedView.transform = .identity
                self.dimmingView.alpha = 1
            }
        )
    }

    private func dismissPresentedViewController() {
        guard !self.isCompletingPanDismissal else {
            return
        }

        self.presentedViewController.dismiss(animated: true)
    }
}

extension SlideFromSourcePresentationController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard
            gestureRecognizer === self.dismissPanGesture,
            let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
            let presentedView = self.presentedView
        else {
            return true
        }

        let touchLocation = panGesture.location(in: presentedView)
        let velocity = panGesture.velocity(in: presentedView)

        return touchLocation.y <= DesignTokens.cardDragRegionHeight
            && velocity.y > 0
            && velocity.y > abs(velocity.x)
    }
}

/// A system-sized grabber with a larger transparent hit target. VoiceOver's normal
/// activation gesture follows the same dismissal path as a pointer double-click.
private final class SheetGrabberView: UIView {
    private let indicatorView = UIView()
    var onAccessibilityActivate: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isAccessibilityElement = true
        self.accessibilityLabel = "Dismiss sheet"
        self.accessibilityHint = "Double-tap or swipe down to dismiss"
        self.accessibilityTraits = .button

        self.indicatorView.backgroundColor = .tertiaryLabel
        self.indicatorView.layer.cornerRadius = DesignTokens.grabberSize.height / 2
        self.indicatorView.isUserInteractionEnabled = false
        self.addSubview(self.indicatorView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.indicatorView.frame = CGRect(
            x: (self.bounds.width - DesignTokens.grabberSize.width) / 2,
            y: DesignTokens.grabberTopInset,
            width: DesignTokens.grabberSize.width,
            height: DesignTokens.grabberSize.height
        )
    }

    override func accessibilityActivate() -> Bool {
        self.onAccessibilityActivate?()
        return true
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
        let controllerKey: UITransitionContextViewControllerKey = self.isPresenting ? .to : .from

        guard
            let view = transitionContext.view(forKey: viewKey),
            let viewController = transitionContext.viewController(forKey: controllerKey)
        else {
            transitionContext.completeTransition(false)
            return
        }

        let restingFrame = self.isPresenting
            ? transitionContext.finalFrame(for: viewController)
            : transitionContext.initialFrame(for: viewController)

        if self.isPresenting {
            view.frame = restingFrame
            containerView.addSubview(view)
        }

        let offsetTransform = self.offsetTransform(
            for: restingFrame,
            in: containerView
        )

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
    private func offsetTransform(
        for restingFrame: CGRect,
        in containerView: UIView
    ) -> CGAffineTransform {
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
