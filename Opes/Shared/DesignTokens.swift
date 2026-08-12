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

    /// Corner radius for a hand-drawn card, measured against a system sheet.
    ///
    /// Deriving this doesn't work. `UIBackgroundConfiguration.listGroupedCell()`
    /// reports a radius of zero, because a grouped list is rounded by the layout
    /// per section position rather than by the cell's background configuration, and
    /// no API reports a sheet's own radius. So it stays a measured number, and it's
    /// one of the values worth checking against Apple's design resources.
    static let cardCornerRadius: CGFloat = 40

    /// A native large sheet begins at the top safe-area boundary.
    static let sheetTopInset: CGFloat = 0

    /// The grabber a system sheet draws. There's no public class or view for it, so
    /// a hand-drawn card has to reproduce the shape — another measured pair.
    ///
    /// The width is measured against a native sheet rather than the 36 points older
    /// iOS versions used; iOS 26 draws a noticeably wider grabber.
    static let grabberSize = CGSize(width: 64, height: 5)

    /// Drop from a card's top edge to its grabber.
    static let grabberTopInset: CGFloat = 5

    /// Height of the region at a card's top edge that responds to a dismissing
    /// drag, covering the grabber and the navigation bar behind it.
    static let cardDragRegionHeight: CGFloat = 64

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
