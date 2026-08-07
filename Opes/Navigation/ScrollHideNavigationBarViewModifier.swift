import SwiftUI

/// Hides the navigation bar while the user scrolls down and restores it on
/// scroll up, letting the system fade the bar and its items together.
private struct ScrollHideNavigationBarViewModifier: ViewModifier {
    @State private var isNavigationBarHidden = false
    @State private var referenceOffset: CGFloat = 0

    /// Distance the user must travel against the current direction before the
    /// bar reacts, so small scroll corrections do not toggle it.
    private let scrollThreshold: CGFloat = 12

    private let transition = Animation.easeInOut(duration: 0.28)

    func body(content: Content) -> some View {
        content
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbarVisibility(
                isNavigationBarHidden ? .hidden : .visible,
                for: .navigationBar
            )
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newOffset in
                updateNavigationBarVisibility(for: newOffset)
            }
    }

    private func updateNavigationBarVisibility(for offset: CGFloat) {
        guard offset > 0 else {
            referenceOffset = 0
            setNavigationBar(hidden: false)
            return
        }

        let difference = offset - referenceOffset
        let isScrollingDown = difference > 0

        // While travelling in the direction the bar already reflects, keep the
        // reference at the furthest point reached so that a reversal is
        // measured from there rather than from the previous sample.
        guard isNavigationBarHidden != isScrollingDown else {
            referenceOffset = offset
            return
        }

        guard abs(difference) >= scrollThreshold else { return }

        referenceOffset = offset
        setNavigationBar(hidden: isScrollingDown)
    }

    private func setNavigationBar(hidden: Bool) {
        guard isNavigationBarHidden != hidden else { return }

        withAnimation(transition) {
            isNavigationBarHidden = hidden
        }
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
