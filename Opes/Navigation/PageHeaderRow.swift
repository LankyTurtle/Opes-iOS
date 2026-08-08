import SwiftUI

/// A page header carried at the top of a list's content: the title and the
/// screen's actions on a single row.
///
/// Keeping the header in the content is what makes it scroll away with the
/// view and dissolve under the scroll edge effect, title and actions together.
/// It also settles the title's size for good: content is never subject to the
/// navigation bar collapsing in the compact height class, so the title stays
/// large and leading aligned in every orientation.
struct PageHeaderRow<Actions: View>: View {
    let title: String

    /// Aligns the header with the rows beneath it, which sit further in under
    /// an inset grouped style than under a plain one.
    var horizontalInset: CGFloat = 16

    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 12)

            actions()
        }
        .listRowInsets(
            EdgeInsets(
                top: 8,
                leading: horizontalInset,
                bottom: 8,
                trailing: horizontalInset
            )
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

extension PageHeaderRow where Actions == EmptyView {

    init(title: String, horizontalInset: CGFloat = 16) {
        self.init(title: title, horizontalInset: horizontalInset) { EmptyView() }
    }
}
