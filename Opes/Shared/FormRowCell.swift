import UIKit

/// A grouped-list row: the title on the left and its control against the trailing
/// edge, the way Settings lays out a field or a toggle.
final class FormRowCell: UITableViewCell {
    private let titleLabel = UILabel()

    var title: String? {
        get { self.titleLabel.text }
        set { self.titleLabel.text = newValue }
    }

    /// - Parameter stretchesControl: `true` for a control that should take the width
    ///   the title leaves — a text field, or a button whose value truncates. `false`
    ///   for one that keeps its own size, like a switch or a compact date picker.
    init(title: String, control: UIView, stretchesControl: Bool) {
        super.init(style: .default, reuseIdentifier: nil)

        // The row is a container for its control, so it neither highlights nor
        // reads as a separate element to VoiceOver.
        self.selectionStyle = .none

        self.titleLabel.text = title
        self.titleLabel.font = .preferredFont(forTextStyle: .body)
        self.titleLabel.adjustsFontForContentSizeCategory = true

        // Whichever of the two isn't hugging its content takes the slack, which is
        // what puts a switch hard against the trailing edge but lets a field run
        // back towards its title.
        self.titleLabel.setContentHuggingPriority(
            stretchesControl ? .required : .defaultLow,
            for: .horizontal
        )
        self.titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        control.setContentHuggingPriority(
            stretchesControl ? .defaultLow : .required,
            for: .horizontal
        )

        let stack = UIStackView(arrangedSubviews: [self.titleLabel, control])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.alignment = .center
        stack.spacing = DesignTokens.cardPadding
        self.contentView.addSubview(stack)

        // Breakable, so the estimated row height the table starts from never
        // conflicts with the height this resolves to.
        let bottom = stack.bottomAnchor.constraint(
            equalTo: self.contentView.layoutMarginsGuide.bottomAnchor
        )
        bottom.priority = .required - 1

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.trailingAnchor),
            bottom,
            self.contentView.heightAnchor.constraint(
                greaterThanOrEqualToConstant: DesignTokens.minimumTapTarget
            ),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
