import SwiftUI

/// Renders a page title that stays large, inline and leading aligned in every
/// orientation and at every scroll position.
///
/// `ToolbarTitleDisplayMode.inlineLarge` cannot express this. It collapses to a
/// small centred title in the compact height class — iPhone landscape — and it
/// pushes leading and centred toolbar items into an overflow menu. Placing the
/// title in a leading toolbar item instead fixes its size, weight and alignment
/// independently of orientation, and lets it fade with the rest of the bar as a
/// single unit rather than resizing against it.
private struct PageTitleViewModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                        // Without this the bar hands the title its minimum
                        // width and truncates it to a single character, even
                        // with the rest of the bar empty.
                        .fixedSize()
                        .accessibilityAddTraits(.isHeader)
                }
                // A title is not a control, so it opts out of the glass
                // grouping its neighbouring toolbar buttons share.
                .sharedBackgroundVisibility(.hidden)
            }
    }
}

extension View {

    /// Pins `title` to the leading edge of the navigation bar, permanently
    /// inline and large.
    /// - Parameter title: The title to display in the navigation bar.
    /// - Returns: A view whose navigation bar shows a pinned large title.
    func pageTitle(_ title: String) -> some View {
        modifier(PageTitleViewModifier(title: title))
    }
}
