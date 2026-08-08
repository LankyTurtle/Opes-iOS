import SwiftUI

/// A page title carried at the top of a list's content rather than in the
/// navigation bar.
///
/// Scrolling then moves the title with the view and dissolves it under the
/// scroll edge effect, instead of leaving it pinned while the content passes
/// beneath. A title in the content is also never subject to the navigation
/// bar collapsing in the compact height class, so it stays large and leading
/// aligned in every orientation without any bar of its own.
struct PageTitleRow: View {
    let title: String

    /// Aligns the title with the rows beneath it, which sit further in under
    /// an inset grouped style than under a plain one.
    var leadingInset: CGFloat = 16

    var body: some View {
        Text(title)
            .font(.largeTitle.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .listRowInsets(
                EdgeInsets(
                    top: 8,
                    leading: leadingInset,
                    bottom: 8,
                    trailing: leadingInset
                )
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
