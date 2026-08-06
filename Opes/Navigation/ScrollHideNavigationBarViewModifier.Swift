import SwiftUI

private struct ScrollHideNavigationBarViewModifier: ViewModifier {
    let threshold: CGFloat

    @State private var navigationBarHidden = false

    func body(content: Content) -> some View {
        content
            .toolbarVisibility(
                navigationBarHidden ? .hidden : .visible,
                for: .navigationBar
            )
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let offset =
                    geometry.contentOffset.y +
                    geometry.contentInsets.top

                return offset > threshold
            } action: { _, isPastThreshold in
                withAnimation {
                    navigationBarHidden = isPastThreshold
                }
            }
    }
}

extension View {
    func scrollHideNavigationBar(
        threshold: CGFloat = 60
    ) -> some View {
        modifier(
            ScrollHideNavigationBarViewModifier(
                threshold: threshold
            )
        )
    }
}
