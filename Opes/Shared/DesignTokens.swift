import UIKit

/// Measurements that approximate system metrics UIKit doesn't expose.
///
/// Every value here was measured off a screenshot or reasoned about rather than
/// read from an API, so they're gathered in one place to be checked against
/// Apple's design resources in a single pass instead of hunted through the
/// feature code. Values that are genuine design choices rather than attempts to
/// match the system stay where they're used.
enum DesignTokens {
    /// Inset from a card's edge to its content.
    static let cardPadding: CGFloat = 16

    /// Gap between a card's stacked labels.
    static let labelSpacing: CGFloat = 4

    /// Tighter gap for a caption sitting directly under a value.
    static let captionSpacing: CGFloat = 2

    /// Vertical padding on a row inside a card.
    static let rowPadding: CGFloat = 10

    /// Drop from the top safe area to a tab root's drawn title.
    static let titleTopInset: CGFloat = 8

    /// Gap between a screen's title and the content beneath it.
    static let titleSpacing: CGFloat = 8

    /// Corner radius for a hand-drawn card.
    ///
    /// Nothing reports a system sheet's own radius, so this borrows the closest
    /// value that is readable — the background configuration the system applies to
    /// inset grouped cells. Semantically adjacent rather than identical, but it is
    /// a real system value that follows OS changes, where a measured number can't.
    static var cardCornerRadius: CGFloat {
        UIBackgroundConfiguration.listGroupedCell().cornerRadius
    }

    /// Gap between the top safe area and a sheet at its large detent.
    static let sheetTopInset: CGFloat = 4

    /// Smallest comfortable tap target.
    static let minimumTapTarget: CGFloat = 44

    /// Clearance a pressed glass control needs from a clipping edge, since it
    /// draws outside its own bounds while held and nothing reports by how much.
    static let glassPressClearance: CGFloat = 12

    /// `UISearchBar` insets its field from its own edges; cancelling that out
    /// lines the visible pill up with the content beside it.
    static let searchFieldInset: CGFloat = 8

    /// A tab root's drawn title, matching the navigation bar's large title.
    static var largeTitleFont: UIFont {
        UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: .systemFont(ofSize: 34, weight: .bold))
    }

    /// The headline figure on a card.
    static var tileValueFont: UIFont {
        UIFontMetrics(forTextStyle: .title1)
            .scaledFont(for: .systemFont(ofSize: 28, weight: .bold))
    }
}
