import SwiftUI

private struct ScrollHideNavigationBarViewModifier: ViewModifier {
    @State private var isHeaderHidden = false
    @State private var previousTranslation: CGFloat = 0

    private let directionThreshold: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .toolbarVisibility(
                isHeaderHidden ? .hidden : .visible,
                for: .navigationBar
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        let currentTranslation = value.translation.height
                        let delta = currentTranslation - previousTranslation

                        guard abs(delta) >= directionThreshold else {
                            return
                        }

                        if delta < 0 {
                            // Finger moving up:
                            // content is scrolling down.
                            isHeaderHidden = true
                        } else {
                            // Finger moving down:
                            // content is scrolling up.
                            isHeaderHidden = false
                        }

                        previousTranslation = currentTranslation
                    }
                    .onEnded { _ in
                        previousTranslation = 0
                    }
            )
    }
}

extension View {
    func scrollHideNavigationBar() -> some View {
        modifier(ScrollHideNavigationBarViewModifier())
    }
}
