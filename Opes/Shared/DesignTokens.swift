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

    /// Gap between a card's header and the content beneath it.
    static let titleSpacing: CGFloat = 8

    /// Corner radius for a hand-drawn card. Confirmed against Apple's `Sheet - Full
    /// Screen - iPhone` component, which rounds its top two corners by 38 and leaves
    /// the bottom two square.
    ///
    /// No API reports this. `UIBackgroundConfiguration.listGroupedCell()` returns a
    /// radius of zero, because a grouped list is rounded by the layout per section
    /// position rather than by the cell's background configuration.
    static let cardCornerRadius: CGFloat = 38

    /// A native large sheet begins at the top safe-area boundary.
    static let sheetTopInset: CGFloat = 0

    /// Figma's full-screen iPhone sheet uses a 36 × 5 point grabber.
    static let grabberSize = CGSize(width: 36, height: 5)

    /// Drop from a card's top edge to its grabber.
    static let grabberTopInset: CGFloat = 5

    /// Height of Figma's sheet toolbar: a 16 point grabber region followed by a
    /// 44 point title-and-controls row, with 10 points of bottom clearance.
    static let sheetToolbarHeight: CGFloat = 70

    /// The title-and-controls row starts directly below the 16 point grabber region.
    static let sheetToolbarControlsTopInset: CGFloat = 16

    /// Horizontal inset for the toolbar's leading and trailing controls.
    static let sheetToolbarHorizontalInset: CGFloat = 16

    /// Height of the region at a card's top edge that responds to a dismissing
    /// drag, matching the whole Figma toolbar.
    static let cardDragRegionHeight: CGFloat = sheetToolbarHeight

    /// Smallest comfortable tap target.
    static let minimumTapTarget: CGFloat = 44

    /// `UISearchBar` insets its field from its own edges; cancelling that out
    /// lines the visible pill up with the content beside it.
    static let searchFieldInset: CGFloat = 8

    /// The headline figure on a card.
    static var tileValueFont: UIFont {
        UIFontMetrics(forTextStyle: .title1)
            .scaledFont(for: .systemFont(ofSize: 28, weight: .bold))
    }
}
