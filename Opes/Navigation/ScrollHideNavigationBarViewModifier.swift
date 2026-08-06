import SwiftUI

private struct ScrollHideNavigationBarViewModifier: ViewModifier {
    @State private var isHeaderHidden = false
    @State private var previousOffset: CGFloat = 0

    private let scrollThreshold: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .toolbarVisibility(
                isHeaderHidden ? .hidden : .visible,
                for: .navigationBar
            )
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newOffset in
                if newOffset <= 0 {
                    isHeaderHidden = false
                    previousOffset = 0
                    return
                }

                let difference = newOffset - previousOffset

                guard abs(difference) >= scrollThreshold else {
                    return
                }

                isHeaderHidden = difference > 0
                previousOffset = newOffset
            }
    }
}

extension View {
    func scrollHideNavigationBar() -> some View {
        modifier(ScrollHideNavigationBarViewModifier())
    }
}
