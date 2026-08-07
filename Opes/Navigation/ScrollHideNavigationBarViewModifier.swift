import SwiftUI

/// Hides the navigation bar while the user scrolls down and restores it on
/// scroll up, fading the bar and every item in it as a single unit.
private struct ScrollHideNavigationBarViewModifier: ViewModifier {
    @State private var isNavigationBarHidden = false
    @State private var isScrollDrivenByUser = false

    /// The offset the current direction is measured from.
    @State private var anchorOffset: CGFloat = 0

    /// The top content inset the anchor was taken against. A change means the
    /// safe area resized rather than the user scrolling.
    @State private var anchorInset: CGFloat?

    /// Set while the scroll view is still absorbing a bar toggle, so the offset
    /// that toggle produces is never read back as user input.
    @State private var isSettlingAfterToggle = false

    /// Distance the user must travel against the current direction before the
    /// bar reacts, so small scroll corrections do not toggle it. Doubles as the
    /// band at the top of the content within which the bar is always shown.
    private let scrollThreshold: CGFloat = 24

    private let transition = Animation.easeInOut(duration: 0.25)

    func body(content: Content) -> some View {
        content
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbarVisibility(
                isNavigationBarHidden ? .hidden : .visible,
                for: .navigationBar
            )
            .onScrollPhaseChange { _, phase in
                isScrollDrivenByUser = phase.isDrivenByUser
            }
            .onScrollGeometryChange(for: ScrollSample.self) { geometry in
                ScrollSample(
                    offset: geometry.contentOffset.y,
                    topInset: geometry.contentInsets.top
                )
            } action: { _, sample in
                react(to: sample)
            }
    }

    private func react(to sample: ScrollSample) {
        // Showing or hiding the bar resizes the safe area, which moves the
        // content offset without the user having scrolled. Reading that back as
        // a direction change is what makes the bar oscillate, so re-anchor on
        // it and wait for the next genuine sample instead.
        guard anchorInset == sample.topInset, !isSettlingAfterToggle else {
            reanchor(at: sample)
            return
        }

        // The top of the content, and the rubber band above it, always show the
        // bar so the user can never be left without it.
        guard sample.offset + sample.topInset > scrollThreshold else {
            anchorOffset = sample.offset
            setNavigationBar(hidden: false)
            return
        }

        // Momentum counts as the user scrolling; a programmatic scroll or a
        // layout pass does not.
        guard isScrollDrivenByUser else {
            anchorOffset = sample.offset
            return
        }

        let travel = sample.offset - anchorOffset
        let isScrollingDown = travel > 0

        // While travelling in the direction the bar already reflects, keep the
        // anchor at the furthest point reached so that a reversal is measured
        // from there rather than from the previous sample.
        guard isNavigationBarHidden != isScrollingDown else {
            anchorOffset = sample.offset
            return
        }

        guard abs(travel) >= scrollThreshold else { return }

        anchorOffset = sample.offset
        setNavigationBar(hidden: isScrollingDown)
    }

    private func reanchor(at sample: ScrollSample) {
        anchorInset = sample.topInset
        anchorOffset = sample.offset
        isSettlingAfterToggle = false
    }

    private func setNavigationBar(hidden: Bool) {
        guard isNavigationBarHidden != hidden else { return }

        isSettlingAfterToggle = true

        withAnimation(transition) {
            isNavigationBarHidden = hidden
        }
    }
}

/// The part of a scroll view's geometry the bar reacts to.
private struct ScrollSample: Equatable {
    let offset: CGFloat
    let topInset: CGFloat
}

private extension ScrollPhase {

    /// Whether the offset is moving because of the user rather than because of
    /// code or a layout change.
    var isDrivenByUser: Bool {
        self == .interacting || self == .decelerating
    }
}

extension View {

    /// Fades the navigation bar out as the view scrolls down and back in as it
    /// scrolls up.
    /// - Returns: A view whose navigation bar follows the scroll direction.
    func scrollHideNavigationBar() -> some View {
        modifier(ScrollHideNavigationBarViewModifier())
    }
}
